import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_scaffold.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../providers/session_providers.dart';
import '../../repository/i_session_repository.dart';
import '../../services/websocket_service.dart';
import '../../models/session_models.dart';
import 'select_friends_screen.dart';
import 'session_item_edit_bottom_sheet.dart';
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
  
  final ScrollController _participantsScrollController = ScrollController();
  int? _editingItemIndex;
  final double shiftDistance = 60;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(sessionRepositoryProvider);
    _webSocket = WebSocketService.instance;
    _initWebSocket();
  
    if (_webSocket.currentSessionId != widget.sessionId || !_webSocket.isConnected) {
      _webSocket.connect(widget.sessionId);
    }

    _loadSessionWithTimeout();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _participantsScrollController.dispose();
    _webSocket.removeListener(_handleWebSocketMessage);
    super.dispose();
  }

  void _initWebSocket() {
    _webSocket.addListener(_handleWebSocketMessage);
  }

  Future<void> _loadSessionWithTimeout() async {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_hasInitialLoad && _session == null) {
        _loadSession();
      }
    });
    await _loadSession();
  }

  void _handleWebSocketMessage(WSMessage message) {
    if (!mounted) return;
    
    switch (message.type) {
      case WSMessageType.stateChanged:
        _hasInitialLoad = true;
        _updateSessionFromMessage(message.payload);
        break;
        
      case WSMessageType.participantReady:
        final userId = message.payload['user_id'];
        if (userId != null && _session != null) {
          final updatedParticipants = _session!.participants.map((p) {
            if (p.userId == userId) {
              return ParticipantModel(
                userId: p.userId,
                username: p.username,
                status: p.status,
                isReady: true,
                hasVoted: p.hasVoted,
                isOwner: p.isOwner,
                invitedAt: p.invitedAt,
                joinedAt: p.joinedAt,
              );
            }
            return p;
          }).toList();
          
          setState(() {
            _session = SessionModel(
              id: _session!.id,
              ownerId: _session!.ownerId,
              ownerName: _session!.ownerName,
              status: _session!.status,
              mode: _session!.mode,
              listLocked: _session!.listLocked,
              currentList: _session!.currentList,
              participants: updatedParticipants,
              votingDuration: _session!.votingDuration,
              createdAt: _session!.createdAt,
              votingEndsAt: _session!.votingEndsAt,
              countdownEndsAt: _session!.countdownEndsAt,
              results: _session!.results,
              isOwner: _session!.isOwner,
              canEditList: _session!.canEditList,
              canStart: _session!.canStart,
              canInvite: _session!.canInvite,
              canLockList: _session!.canLockList,
            );
          });
        }
        _loadSession();
        break;
        
      case WSMessageType.timerUpdated:
        final participantsList = message.payload['participants'];
        if (participantsList != null && _session != null) {
          final updatedParticipants = _session!.participants.map((p) {
            final updated = (participantsList as List).firstWhere(
              (json) => json['user_id'] == p.userId,
              orElse: () => null,
            );
            if (updated != null) {
              return ParticipantModel(
                userId: p.userId,
                username: p.username,
                status: p.status,
                isReady: updated['is_ready'] ?? p.isReady,
                hasVoted: p.hasVoted,
                isOwner: p.isOwner,
                invitedAt: p.invitedAt,
                joinedAt: p.joinedAt,
              );
            }
            return p;
          }).toList();
          
          setState(() {
            _session = SessionModel(
              id: _session!.id,
              ownerId: _session!.ownerId,
              ownerName: _session!.ownerName,
              status: _session!.status,
              mode: _session!.mode,
              listLocked: _session!.listLocked,
              currentList: _session!.currentList,
              participants: updatedParticipants,
              votingDuration: _session!.votingDuration,
              createdAt: _session!.createdAt,
              votingEndsAt: _session!.votingEndsAt,
              countdownEndsAt: _session!.countdownEndsAt,
              results: _session!.results,
              isOwner: _session!.isOwner,
              canEditList: _session!.canEditList,
              canStart: _session!.canStart,
              canInvite: _session!.canInvite,
              canLockList: _session!.canLockList,
            );
          });
        }
        break;
        
      case WSMessageType.participantJoined:
      case WSMessageType.participantLeft:
      case WSMessageType.participantKicked:
      case WSMessageType.listLocked:
      case WSMessageType.listUnlocked:
      case WSMessageType.listItemAdded:
      case WSMessageType.listItemUpdated:
      case WSMessageType.listItemDeleted:
        _loadSession();
        break;
        
      case WSMessageType.votingStarted:
        if (!_isNavigating && mounted) {
          _isNavigating = true;
          context.go('/session/${widget.sessionId}/ranking');
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
      
      final currentUserId = ref.read(authStateProvider)?.id;
      final myPart = session.participants.firstWhere(
        (p) => p.userId == currentUserId,
        orElse: () => session.participants.first,
      );

      if (myPart.status == ParticipantStatus.invited) {
        await _repository.acceptInvite(widget.sessionId);
        await Future.delayed(const Duration(milliseconds: 300));
        _loadSession();
        return;
      }

      setState(() {
        _session = session;
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

  void _scrollParticipantsLeft() {
    if (_participantsScrollController.hasClients) {
      final newOffset = _participantsScrollController.offset - 320;
      _participantsScrollController.animateTo(
        newOffset.clamp(0.0, _participantsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollParticipantsRight() {
    if (_participantsScrollController.hasClients) {
      final newOffset = _participantsScrollController.offset + 320;
      _participantsScrollController.animateTo(
        newOffset.clamp(0.0, _participantsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _startVoting() {
    if (_isLoading) return;
    if (_session == null) return;
    
    final items = _session!.currentList?.items ?? [];
    if (items.isEmpty) {
      _showError('Добавьте хотя бы один элемент в список');
      return;
    }
    
    if (!_session!.canStart) {
      _showError('Не все участники готовы');
      return;
    }

    if (AppConfig.useMocks) {
      context.go('/session/${widget.sessionId}/ranking');
      return;
    }

    print('Starting voting via WebSocket');
    _webSocket.startVoting();
  }
  
  Future<void> _toggleReady() async {
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
        await _repository.unmarkReady(widget.sessionId);
      } else {
        await _repository.markReady(widget.sessionId);
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadSession();
    } catch (e) {
      _showError('Ошибка: $e');
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

  void _showKickDialog(int userId, String username) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(20),
          decoration: ShapeDecoration(
            color: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                username,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontFamily: 'Instrument Sans',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Вы уверены, что хотите выгнать $username?',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontFamily: 'Instrument Sans',
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 40,
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 2,
                              color: AppColors.textSecondary,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Нет, отменить',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await _repository.kickParticipant(widget.sessionId, userId);
                        _loadSession();
                      },
                      child: Container(
                        height: 40,
                        decoration: ShapeDecoration(
                          color: AppColors.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Да, выгнать',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleListLock() async {
    if (_isLoading) return;
    if (!_session!.canLockList) return;
    if (_session!.listLocked) {
      print('Unlocking list');
      await _repository.unlockList(widget.sessionId);
    } else {
      print('Locking list');
      await _repository.lockList(widget.sessionId);
    }
  }

  void _addNewItem() {
    if (_session!.currentList == null) return;
    if (_session!.listLocked && !_session!.canEditList) {
      _showError('Список заблокирован владельцем');
      return;
    }
    
    print('Adding new item');
    _webSocket.addItem('Новый элемент');
  }

  void _editItem(SessionListItemModel item, int index) {
    if (_session!.listLocked && !_session!.canEditList) {
      _showError('Список заблокирован владельцем');
      return;
    }
    
    setState(() {
      _editingItemIndex = index;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SessionItemEditBottomSheet(
        item: item,
        onSave: (name, description, imageUrl) {
          print('Updating item: ${item.id}, name: $name');
          _webSocket.updateItem(item.id, name: name, description: description);
          setState(() {
            _editingItemIndex = null;
          });
          Navigator.pop(context);
        },
        onClose: () {
          setState(() {
            _editingItemIndex = null;
          });
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _editingItemIndex = null;
        });
      }
    });
  }

  void _deleteItem(SessionListItemModel item) {
    if (_session!.listLocked && !_session!.canEditList) {
      _showError('Список заблокирован владельцем');
      return;
    }
    
    print('Deleting item: ${item.id}');
    _webSocket.deleteItem(item.id);
  }

  double _getItemOffset(int index, int? editingIndex) {
    if (editingIndex == null) return 0;
    final diff = (index - editingIndex).abs();
    if (diff == 0) return -shiftDistance;
    if (diff == 1) return -(shiftDistance * 0.5);
    if (diff == 2) return -(shiftDistance * 0.25);
    return 0;
  }

  void _inviteFriends() async {
    if (_isLoading) return;
    if (!_session!.canInvite) return;
    final result = await context.push<List<int>>('/select-friends?mode=invite');
    if (result != null && result.isNotEmpty && mounted) {
      await _repository.inviteFriends(widget.sessionId, result);
      _loadSession();
    }
  }

  void _leaveLobby() {
    if (_session!.isOwner) {
      _webSocket.closeLobby();
    } else {
      _webSocket.leaveLobby();
    }
    if (mounted) {
      context.go('/home');
    }
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
        body: Container(
          width: 412,
          height: 892,
          decoration: const ShapeDecoration(
            color: AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
          ),
          child: Center(
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
        ),
      );
    }

    final session = _session!;
    final activeList = session.currentList;
    final items = activeList?.items ?? [];
    
    final allParticipants = session.participants
        .where((p) => p.status == ParticipantStatus.accepted)
        .toList();
    final regularParticipants = allParticipants.where((p) => !p.isOwner).toList();
    final readyCount = regularParticipants.where((p) => p.isReady).length;
    final totalRegular = regularParticipants.length;
    
    final currentUserId = ref.read(authStateProvider)?.id;
    final myPart = session.participants.firstWhere(
      (p) => p.userId == currentUserId,
      orElse: () => session.participants.first,
    );

    return CustomScaffold(
      title: "Лобби",
      showBackButton: true,
      body: Stack(
        children: [
          Container(
            width: 412,
            height: 892,
            decoration: const ShapeDecoration(
              color: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
            child: Stack(
              children: [
                
                // Горизонтальный список участников с кнопкой добавления в конце
                Positioned(
                  left: 41,
                  top: 100,
                  child: SizedBox(
                    width: 330,
                    height: 129,
                    child: _buildParticipantsList(allParticipants, session.isOwner, session.canInvite),
                  ),
                ),
                
                // Стрелка влево для участников
                if (allParticipants.length + 1 > 4)
                  Positioned(
                    left: 10,
                    top: 145,
                    child: GestureDetector(
                      onTap: _scrollParticipantsLeft,
                      child: Container(
                        width: 31,
                        height: 31,
                        child: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 31),
                      ),
                    ),
                  ),
                
                // Стрелка вправо для участников
                if (allParticipants.length + 1 > 4)
                  Positioned(
                    left: 371,
                    top: 145,
                    child: GestureDetector(
                      onTap: _scrollParticipantsRight,
                      child: Container(
                        width: 31,
                        height: 31,
                        child: const Icon(Icons.chevron_right, color: AppColors.textPrimary, size: 31),
                      ),
                    ),
                  ),
                
                // Счетчик элементов списка
                Positioned(
                  left: 102,
                  top: 248,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Список лобби ',
                          style: AppTextStyles.sessionListDetail,
                        ),
                        TextSpan(
                          text: '${items.length}/20',
                          style: AppTextStyles.sessionListDetail.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Таймер обратного отсчета
                if (_getCountdownText() != null && session.status == SessionStatus.ready)
                  Positioned(
                    right: 30,
                    top: 248,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            _getCountdownText()!,
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                // Название списка с замком
                Positioned(
                  left: 78,
                  top: 281,
                  child: Container(
                    width: 257,
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                    decoration: ShapeDecoration(
                      color: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            activeList?.name ?? 'Список',
                            style: AppTextStyles.dropbox,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (session.canLockList)
                          IconButton(
                            icon: Icon(
                              session.listLocked ? Icons.lock : Icons.lock_open,
                              color: AppColors.textLight,
                              size: 20,
                            ),
                            onPressed: _toggleListLock,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Кнопка добавления элемента
                if (session.canEditList && !session.listLocked)
                  Positioned(
                    left: 78,
                    top: 355,
                    child: GestureDetector(
                      onTap: _addNewItem,
                      child: Container(
                        width: 368,
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                        decoration: ShapeDecoration(
                          color: AppColors.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add, color: AppColors.textLight, size: 25),
                            const SizedBox(width: 10),
                            Text(
                              'Добавить новый элемент',
                              style: AppTextStyles.bodyGeneral.copyWith(
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Список элементов
                Positioned(
                  left: 22,
                  top: session.canEditList && !session.listLocked ? 403 : 365,
                  child: Container(
                    width: 512,
                    height: session.canEditList && !session.listLocked ? 340 : 280,
                    child: items.isEmpty
                        ? Align(
                            alignment: Alignment(-0.6, 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.format_list_bulleted, size: 64, color: AppColors.tertiary),
                                const SizedBox(height: 16),
                                const Text(
                                  'Список пуст',
                                  style: AppTextStyles.bodyGeneral,
                                ),
                                const SizedBox(height: 16),
                                if (session.canEditList && !session.listLocked)
                                  ElevatedButton(
                                    onPressed: _addNewItem,
                                    child: const Text(
                                      'Добавить первый элемент',
                                      style: AppTextStyles.button,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final offset = _getItemOffset(index, _editingItemIndex);
                              final isEven = index % 2 == 0;
                              
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                transform: Matrix4.translationValues(offset, 0, 0),
                                child: Container(
                                  height: 48,
                                  margin: EdgeInsets.zero,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Иконка удаления
                                      if (session.canEditList && !session.listLocked)
                                        SizedBox(
                                          width: 35,
                                          child: GestureDetector(
                                            onTap: () => _deleteItem(item),
                                            child: SvgPicture.asset(
                                              'assets/icons/delete_bin_icon.svg',
                                              colorFilter: isEven 
                                                  ? const ColorFilter.mode(
                                                      AppColors.inputBackground,
                                                      BlendMode.srcIn,
                                                    )
                                                  : const ColorFilter.mode(
                                                      AppColors.primary,
                                                      BlendMode.srcIn,
                                                    ),
                                              width: 35,
                                              height: 35,
                                            ),
                                          ),
                                        ),
                                      
                                      if (session.canEditList && !session.listLocked) 
                                        const SizedBox(width: 21),
                                      
                                      // Задний план
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: (session.canEditList && !session.listLocked) 
                                              ? () => _editItem(item, index) 
                                              : null,
                                          child: Container(
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                            decoration: ShapeDecoration(
                                              color: isEven ? AppColors.inputBackground : AppColors.primary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              item.name,
                                              style: AppTextStyles.bodyGeneral.copyWith(
                                                color: isEven ? AppColors.textPrimary : AppColors.textLight
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                
                // Кнопка "НАЧАТЬ" (только для хоста)
                if (session.isOwner && session.status != SessionStatus.voting)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 90,
                    child: Center(
                      child: CustomButton(
                        text: 'НАЧАТЬ',
                        onPressed: _startVoting,
                        width: 130,
                        backgroundColor: session.canStart ? AppColors.secondary : AppColors.textSecondary,
                        textStyle: AppTextStyles.buttonBig,
                      ),
                    ),
                  ),
                
                // Кнопка "Я ГОТОВ"/"НЕ ГОТОВ" (только для не-хоста)
                if (!session.isOwner && session.status != SessionStatus.voting)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 90,
                    child: Center(
                      child: CustomButton(
                        text: myPart.isReady ? 'НЕ ГОТОВ' : 'Я ГОТОВ',
                        onPressed: _toggleReady,
                        width: 130,
                        backgroundColor: AppColors.secondary,
                        textStyle: AppTextStyles.buttonBig,
                      ),
                    ),
                  ),
                
                // Кнопка выхода
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 30,
                  child: Center(
                    child: CustomButton(
                      text: session.isOwner ? 'ЗАКРЫТЬ ЛОББИ' : 'ПОКИНУТЬ ЛОББИ',
                      onPressed: _leaveLobby,
                      width: 130,
                      backgroundColor: AppColors.secondary,
                      textStyle: AppTextStyles.buttonBig,
                    ),
                  ),
                ),
                
                // Индикатор голосования
                if (session.status == SessionStatus.voting)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 100,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          myPart.hasVoted ? 'ВЫ ПРОГОЛОСОВАЛИ' : 'ИДЕТ ГОЛОСОВАНИЕ...',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Затемнение при открытом bottom sheet редактирования
          if (_editingItemIndex != null)
            Container(
              width: 412,
              height: 892,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.tertiary.withOpacity(0.7),
                    AppColors.secondary.withOpacity(0.7),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildParticipantsList(List<ParticipantModel> participants, bool isOwner, bool canInvite) {
    return SingleChildScrollView(
      controller: _participantsScrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...participants.map((p) {
            Color avatarColor;
            Widget statusWidget;
            
            if (p.isOwner) {
              avatarColor = AppColors.secondary;
              statusWidget = Text(
                'Хост',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                ),
              );
            } else if (p.hasVoted) {
              avatarColor = Colors.purple;
              statusWidget = Text(
                'Проголосовал',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                ),
              );
            } else if (p.isReady) {
              avatarColor = Colors.green;
              statusWidget = Text(
                'ГОТОВ',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                ),
              );
            } else {
              avatarColor = AppColors.tertiary;
              statusWidget = SvgPicture.asset(
                'assets/icons/three_dots_icon.svg',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              );
            }
            
            return Container(
              width: 65,
              margin: const EdgeInsets.only(right: 19),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 65,
                    child: Text(
                      p.username.length > 7 ? '${p.username.substring(0, 6)}.' : p.username,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyGeneral.copyWith(color: AppColors.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: (isOwner && !p.isOwner && !p.hasVoted && _session?.status != SessionStatus.voting) 
                        ? () => _showKickDialog(p.userId, p.username) 
                        : null,
                    child: Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: avatarColor,
                        shape: BoxShape.circle,
                        border: p.isReady ? Border.all(color: AppColors.primary, width: 3) : null,
                      ),
                      child: Center(
                        child: Text(
                          p.username[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    width: 30,
                    child: Center(
                      child: statusWidget,
                    ),
                  ),
                ],
              ),
            );
          }),
          
          // Кнопка добавления друзей (последний элемент)
          if (canInvite)
            Container(
              width: 65,
              margin: const EdgeInsets.only(right: 19, bottom: 25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _inviteFriends,
                    child: Container(
                      width: 65,
                      height: 65,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/add_plus_white_icon.svg',
                          width: 30,
                          height: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

}