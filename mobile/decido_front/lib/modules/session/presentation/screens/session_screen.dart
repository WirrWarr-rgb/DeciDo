import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_scaffold.dart';
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
  bool _hasInitialLoad = false;

  @override
  void initState() {
    super.initState();
    print('🟢 SessionScreen initState, sessionId=${widget.sessionId}');
    _repository = ref.read(sessionRepositoryProvider);
    _webSocket = WebSocketService.instance;
    _initWebSocket();
  
    if (_webSocket.currentSessionId != widget.sessionId || !_webSocket.isConnected) {
      print('🟢 Connecting to session WebSocket...');
      _webSocket.connect(widget.sessionId);
    } else {
      print('🟢 Already connected to session ${widget.sessionId}');
    }

    // Загружаем начальное состояние через HTTP с таймаутом
    _loadSessionWithTimeout();
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

  Future<void> _loadSessionWithTimeout() async {
    // Ждем ответа от WebSocket 3 секунды
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_hasInitialLoad && _session == null) {
        print('⚠️ WebSocket timeout, loading via HTTP');
        _loadSession();
      }
    });
    
    // Загружаем через HTTP сразу для быстрого отображения
    await _loadSession();
  }

  void _handleWebSocketMessage(WSMessage message) {
    if (!mounted) return;
    
    print('🔔 WebSocket message received: ${message.type}');
    
    switch (message.type) {
      case WSMessageType.stateChanged:
        _hasInitialLoad = true;
        _updateSessionFromMessage(message.payload);
        break;
        
      case WSMessageType.participantJoined:
      case WSMessageType.participantLeft:
      case WSMessageType.participantReady:
      case WSMessageType.listLocked:
      case WSMessageType.listUnlocked:
      case WSMessageType.listItemAdded:
      case WSMessageType.listItemUpdated:
      case WSMessageType.listItemDeleted:
      case WSMessageType.timerUpdated:
        // Обновляем только при необходимости
        if (_session != null) {
          _loadSession(); // Пока оставляем полную перезагрузку
        }
        break;
        
      case WSMessageType.votingStarted:
        print('Voting started, navigating to ranking screen');
        if (!_isNavigating && mounted) {
          _isNavigating = true;
          context.go('/session/${widget.sessionId}/ranking');
        }
        break;
        
      case WSMessageType.userVoted:
        // Показываем уведомление, но не перезагружаем
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${message.payload['username']} проголосовал')),
          );
        }
        break;
        
      case WSMessageType.resultsReady:
        if (!_isNavigating && mounted) {
          _isNavigating = true;
          context.go('/session/${widget.sessionId}/results');
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

  void _updateSessionFromMessage(Map<String, dynamic> payload) {
    setState(() {
      // Обновляем состояние из WebSocket сообщения
      _session = SessionModel.fromJson(payload);
      _isLoading = false;
      _errorMessage = null;
      _hasInitialLoad = true;
    });
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

      // Обработка приглашения - НЕ переподключаем WebSocket
      if (myPart.status == ParticipantStatus.invited) {
        await _repository.acceptInvite(widget.sessionId);
        // WebSocket уже подключен, просто ждем обновления
        await Future.delayed(const Duration(milliseconds: 300));
        _loadSession();
        return;
      }

      setState(() {
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
        _hasInitialLoad = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startVoting() {
    if (_isLoading) return;
    if (_session == null) return;
    print('Starting voting');
    _webSocket.startVoting();

    // Для мок-режима сразу переходим
    if (AppConfig.useMocks) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_isNavigating) {
          _isNavigating = true;
          context.go('/session/${widget.sessionId}/ranking');
        }
      });
      return;
    }
  }
  
  void _toggleReady() async {
    if (_isLoading) return;
    if (_session == null) return;
    
    final currentUserId = ref.read(authStateProvider)?.id;
    if (currentUserId == null) return;
    
    final currentParticipant = _session!.participants.firstWhere(
      (p) => p.userId == currentUserId,
      orElse: () => _session!.participants.first,
    );
    
    try {
      if (currentParticipant.isReady) {
        _webSocket.unready();
      } else {
        _webSocket.markReady();
      }
      // Не загружаем сразу, ждем WebSocket обновления
    } catch (e) {
      print('Error toggling ready: $e');
    }
  }
  
  String? _getCountdownText() {
    if (_session?.countdownEndsAt == null) return null;
    final remaining = _session!.countdownEndsAt!.difference(DateTime.now());
    if (remaining.isNegative) return null;
    final seconds = remaining.inSeconds;
    if (seconds <= 0) return null;
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  void _inviteFriends() async {
    if (_isLoading) return;
    final result = await context.push<List<int>>('/select-friends?mode=invite');
    if (result != null && result.isNotEmpty && mounted) {
      await _repository.inviteFriends(widget.sessionId, result);
      // Ждем WebSocket обновления
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
              // Ждем WebSocket обновления
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
    // Ждем WebSocket обновления
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
        },
        onDelete: () {
          _webSocket.deleteItem(item.id);
          Navigator.pop(context);
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
    
    final allParticipants = session.participants
        .where((p) => p.status == ParticipantStatus.accepted || p.status == ParticipantStatus.invited)
        .toList();
    final regularParticipants = allParticipants.where((p) => !p.isOwner).toList();
    final readyCount = regularParticipants.where((p) => p.isReady).length;
    final totalRegular = regularParticipants.length;

    return CustomScaffold(
      title: activeList?.name ?? 'Лобби #${session.id}',
      showBackButton: true,
      menuIconColor: AppColors.textPrimary,
      actions: [
        if (session.isOwner)
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _inviteFriends,
          ),
        if (session.isOwner)
          IconButton(
            icon: Icon(session.listLocked ? Icons.lock : Icons.lock_open),
            onPressed: _toggleListLock,
          ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: _leaveLobby,
        ),
      ],
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
                      if (_session?.countdownEndsAt != null && _session?.status == SessionStatus.ready)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer, size: 14, color: Colors.blue.shade700),
                              const SizedBox(width: 4),
                              Text(
                                _getCountdownText() ?? '',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
                onPressed: _startVoting,
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
            
            // Список элементов
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
                                                onPressed: () => _deleteItem(item),
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