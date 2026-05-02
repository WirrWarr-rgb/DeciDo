import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../providers/session_providers.dart';
import '../../repository/i_session_repository.dart';
import '../../services/websocket_service.dart';
import '../../models/session_models.dart';
import 'select_friends_screen.dart';
import 'item_edit_bottom_sheet.dart';
import '../../../auth/providers/auth_state_provider.dart';

class SessionScreen extends ConsumerStatefulWidget {
  final int sessionId;

  const SessionScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  late ISessionRepository _repository;
  late WebSocketService _webSocket;
  
  SessionModel? _session;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isNavigating = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(sessionRepositoryProvider);
    _webSocket = WebSocketService.instance;
    _initWebSocket();
    _loadSession();

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _loadSession();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _webSocket.removeListener(_handleWebSocketMessage);
    super.dispose();
  }

  void _initWebSocket() {
    _webSocket.addListener(_handleWebSocketMessage);
  }

  void _handleWebSocketMessage(WSMessage message) {
    if (!mounted) return;
    
    print('WebSocket message: ${message.type}');
    switch (message.type) {
      case WSMessageType.participantJoined:
      case WSMessageType.participantLeft:
      case WSMessageType.participantReady:
      case WSMessageType.listLocked:
      case WSMessageType.listUnlocked:
      case WSMessageType.listItemAdded:
      case WSMessageType.listItemUpdated:
      case WSMessageType.listItemDeleted:
        _loadSession();
        break;
        
      case WSMessageType.votingStarted:
        print('Voting started, navigating to ranking screen');
        if (!_isNavigating && mounted) {
          _isNavigating = true;
          // Используем go вместо pushReplacement для полной замены
          context.go('/session/${widget.sessionId}/ranking');
        }
        break;
        
      case WSMessageType.stateChanged:
        // Не перезагружаем сессию, если мы на экране ранжирования
        if (!_isNavigating && mounted) {
          _loadSession();
        }
        break;
        
      case WSMessageType.lobbyClosed:
        if (!_isNavigating && mounted) {
          _isNavigating = true;
          context.go('/home');
        }
        break;
        
      case WSMessageType.error:
        _showError(message.payload['message'] ?? 'Ошибка');
        break;
        
      default:
        break;
    }
  }


  Future<void> _loadSession() async {
    if (!mounted) return;
    try {
      final session = await _repository.getLobby(widget.sessionId);
      if (!mounted) return;
      
      // Проверяем, нужно ли принять приглашение
      final currentUserId = ref.read(authStateProvider)?.id;
      final myPart = session.participants.firstWhere(
        (p) => p.userId == currentUserId,
        orElse: () => session.participants.first,
      );

      if (myPart.status == ParticipantStatus.invited) {
        await _repository.acceptInvite(widget.sessionId);
        await WebSocketService.instance.connect(widget.sessionId);
        await Future.delayed(const Duration(milliseconds: 300));
        _loadSession();
        return;
      }

      setState(() {
        _session = session;
        if (session.isOwner && (session.status == SessionStatus.waiting || session.status == SessionStatus.editing)) {
          _session = SessionModel(
            id: session.id,
            ownerId: session.ownerId,
            ownerName: session.ownerName,
            status: session.status,
            mode: session.mode,
            listLocked: session.listLocked,
            currentList: session.currentList,
            participants: session.participants,
            votingDuration: session.votingDuration,
            createdAt: session.createdAt,
            votingEndsAt: session.votingEndsAt,
            countdownEndsAt: session.countdownEndsAt,
            results: session.results,
            isOwner: session.isOwner,
            canEditList: true,
            canStart: session.canStart,
            canInvite: session.canInvite,
            canLockList: session.canLockList,
          );
        } else {
          _session = session;
        }
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }


  void _startLobby() {
    if (_isLoading) return;
    if (_session == null) return;
    print('Starting lobby');
    _webSocket.startLobby();
  
    // Переходим на экран голосования
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_isNavigating) {
        _isNavigating = true;
        context.go('/session/${widget.sessionId}/ranking');
      }
    });
  }
  
  void _toggleReady() {
    if (_isLoading) return;
    if (_session == null) return;
    
    final currentUserId = ref.read(authStateProvider)?.id;
    if (currentUserId == null) return;
    
    final currentParticipant = _session!.participants.firstWhere(
      (p) => p.userId == currentUserId,
      orElse: () => _session!.participants.first,
    );
    
    if (currentParticipant.isReady) {
      _webSocket.sendMessage(WSMessageType.unready);
    } else {
      _webSocket.markReady();
    }
    _loadSession();
  }

  void _inviteFriends() async {
    if (_isLoading) return;
    final result = await context.push<List<int>>('/select-friends?mode=invite');
    if (result != null && result.isNotEmpty && mounted) {
      await _repository.inviteFriends(widget.sessionId, result);
      _loadSession();
    }
  }

  void _kickParticipant(int userId, String username) {
    if (_isLoading) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выгнать участника'),
        content: Text('Вы уверены, что хотите выгнать $username из лобби?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _repository.kickParticipant(widget.sessionId, userId);
              _loadSession();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Выгнать'),
          ),
        ],
      ),
    );
  }

  void _toggleListLock() async {
    if (_isLoading) return;
    if (_session!.listLocked) {
      await _repository.unlockList(widget.sessionId);
    } else {
      await _repository.lockList(widget.sessionId);
    }
    _loadSession();
  }

  void _addItem() {
    if (_isLoading) return;
    if (_session!.listLocked && !_session!.isOwner) {
      _showError('Список заблокирован владельцем');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemEditBottomSheet(
        isNew: true,
        onSave: (name, description, imageUrl) {
          _webSocket.addItem(name, description: description, imageUrl: imageUrl);
          Navigator.pop(context);
          _loadSession();
        },
      ),
    );
  }

  void _editItem(SessionListItemModel item) {
    if (_isLoading) return;
    if (_session!.listLocked && !_session!.isOwner) {
      _showError('Список заблокирован владельцем');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemEditBottomSheet(
        item: item,
        isNew: false,
        onSave: (name, description, imageUrl) {
          _webSocket.updateItem(item.id, name: name, description: description, imageUrl: imageUrl);
          Navigator.pop(context);
          _loadSession(); // ← добавить обновление
        },
        onDelete: () {
          _webSocket.deleteItem(item.id);
          Navigator.pop(context);
          _loadSession(); // ← добавить обновление
        },
      ),
    );
  }


  void _deleteItem(SessionListItemModel item) {
    if (_isLoading) return;
    if (_session!.listLocked && !_session!.isOwner) {
      _showError('Список заблокирован владельцем');
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить элемент'),
        content: Text('Вы уверены, что хотите удалить "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              _webSocket.deleteItem(item.id);
              Navigator.pop(context);
              _loadSession(); // ← важно: обновить список
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _leaveLobby() {
    if (_isLoading) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_session!.isOwner ? 'Закрыть лобби' : 'Покинуть лобби'),
        content: Text(_session!.isOwner
            ? 'Вы уверены, что хотите закрыть лобби? Все участники будут удалены.'
            : 'Вы уверены, что хотите покинуть лобби?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              if (_session!.isOwner) {
                _webSocket.closeLobby();
              } else {
                _webSocket.leaveLobby();
              }
              if (mounted) {
                context.go('/home');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_session!.isOwner ? 'Закрыть' : 'Покинуть'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: LoadingWidget());
    }

    if (_errorMessage != null || _session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Лобби')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Лобби не найдено'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                child: const Text('На главную'),
              ),
            ],
          ),
        ),
      );
    }

    final session = _session!;
    final activeList = session.currentList;
    final items = activeList?.items ?? [];
    
    // Участники (исключая хоста для готовности)
    final allParticipants = session.participants
        .where((p) => p.status == ParticipantStatus.accepted || p.status == ParticipantStatus.invited)
        .toList();
    final regularParticipants = allParticipants.where((p) => !p.isOwner).toList();
    final readyCount = regularParticipants.where((p) => p.isReady).length;
    final totalRegular = regularParticipants.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(activeList?.name ?? 'Лобби #${session.id}'),
        actions: [
          // Кнопка пригласить друзей (только хост)
          if (session.isOwner)
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: _inviteFriends,
              tooltip: 'Пригласить друзей',
            ),
          // Кнопка блокировки списка (только хост)
          if (session.isOwner)
            IconButton(
              icon: Icon(session.listLocked ? Icons.lock : Icons.lock_open),
              onPressed: _toggleListLock,
              tooltip: session.listLocked ? 'Разблокировать список' : 'Заблокировать список',
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _leaveLobby,
            tooltip: session.isOwner ? 'Закрыть лобби' : 'Покинуть лобби',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Участники
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Участники (${allParticipants.length})',
                        style: AppTextStyles.headlineSmall,
                      ),
                      // Счётчик готовности
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: readyCount == totalRegular && totalRegular > 0
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Готовы: $readyCount / $totalRegular',
                          style: TextStyle(
                            color: readyCount == totalRegular && totalRegular > 0
                                ? Colors.green
                                : Colors.orange,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allParticipants.map((p) {
                      return Chip(
                        label: Text(p.username),
                        avatar: CircleAvatar(
                          radius: 14,
                          backgroundColor: p.isOwner ? AppColors.secondary : AppColors.primary,
                          child: Text(
                            p.username[0].toUpperCase(),
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                        backgroundColor: p.isReady && !p.isOwner ? Colors.green.withOpacity(0.2) : null,
                        deleteIcon: session.isOwner && !p.isOwner
                            ? const Icon(Icons.close, size: 16, color: Colors.red)
                            : null,
                        onDeleted: session.isOwner && !p.isOwner
                            ? () => _kickParticipant(p.userId, p.username)
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Кнопки
            if (session.isOwner) ...[
              CustomButton(
                text: session.participants.firstWhere((p) => p.isOwner).isReady ? 'Не готов' : 'Готов',
                onPressed: _toggleReady,
                backgroundColor: session.participants.firstWhere((p) => p.isOwner).isReady ? Colors.orange : AppColors.primary,
              ),
              const SizedBox(height: 8),
              CustomButton(
                text: 'Начать голосование',
                onPressed: _startLobby,
                backgroundColor: AppColors.secondary,
              ),
            ] else ...[
              Builder(
                builder: (context) {
                  final myPart = session.participants.firstWhere(
                    (p) => p.userId == ref.read(authStateProvider)?.id,
                    orElse: () => session.participants.first,
                  );
                  return CustomButton(
                    text: myPart.isReady ? 'Не готов' : 'Готов',
                    onPressed: _toggleReady,
                    backgroundColor: myPart.isReady ? Colors.orange : AppColors.primary,
                  );
                },
              ),
            ],
            
            // Список элементов (с возможностью редактирования)
            if (items.isNotEmpty || (session.canEditList || session.isOwner))
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Список для голосования:',
                            style: AppTextStyles.headlineSmall,
                          ),
                          if ((session.canEditList  && !session.listLocked) || session.isOwner)
                            IconButton(
                              icon: const Icon(Icons.add, size: 20),
                              onPressed: _addItem,
                              tooltip: 'Добавить элемент',
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (session.listLocked)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.lock, size: 16, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Список заблокирован. Редактирование недоступно.',
                                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: items.isEmpty
                            ? Center(
                                child: Text(
                                  'Список пуст',
                                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary.withOpacity(0.2),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(color: AppColors.primary, fontSize: 12),
                                      ),
                                    ),
                                    title: Text(
                                      item.name,
                                      style: AppTextStyles.bodyLarge,
                                    ),
                                    subtitle: item.description != null
                                        ? Text(
                                            item.description!,
                                            style: AppTextStyles.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    trailing: ((session.canEditList  && !session.listLocked) || session.isOwner)
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit, size: 18),
                                                onPressed: () => _editItem(item),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                                onPressed: () {
                                                  _deleteItem(item);
                                                  _loadSession();
                                                },
                                              ),
                                            ],
                                          )
                                        : null,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            
            if (items.isEmpty)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Center(
                    child: Text(
                      'Список пуст',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}