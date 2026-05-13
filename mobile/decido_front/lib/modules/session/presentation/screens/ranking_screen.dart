import 'dart:async';
import 'dart:math';
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

class RankingScreen extends ConsumerStatefulWidget {
  final int sessionId;

  const RankingScreen({super.key, required this.sessionId});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen> {
  late ISessionRepository _repository;
  late WebSocketService _webSocket;
  
  SessionModel? _session;
  List<SessionListItemModel> _availableItems = [];
  List<SessionListItemModel?> _rankedItems = [];
  Map<int, SessionListItemModel> _itemsMap = {};
  
  bool _isLoading = true;
  bool _hasVoted = false;
  String? _errorMessage;
  bool _isNavigating = false;
  
  Timer? _timer;
  int _timerSeconds = 0;
  bool _showTimer = false;
  
  Timer? _statusCheckTimer;
  
  int? _draggingIndex;
  bool _isDraggingEnabled = true;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(sessionRepositoryProvider);
    _webSocket = WebSocketService.instance;
    _initWebSocket();
    _loadSession();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusCheckTimer?.cancel();
    _webSocket.removeListener(_handleWebSocketMessage);
    super.dispose();
  }

  void _initWebSocket() {
    _webSocket.addListener(_handleWebSocketMessage);
  }

  void _handleWebSocketMessage(WSMessage message) {
    if (!mounted) return;
    
    switch (message.type) {
      case WSMessageType.userVoted:
        // Только обновляем счётчик проголосовавших, не трогаем элементы
        if (_session != null) {
          final userId = message.payload['user_id'];
          final updatedParticipants = _session!.participants.map((p) {
            if (p.userId == userId) {
              return ParticipantModel(
                userId: p.userId,
                username: p.username,
                status: p.status,
                isReady: p.isReady,
                hasVoted: true,
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
        
      case WSMessageType.resultsReady:
        if (!_isNavigating && mounted) {
          _isNavigating = true;
          context.pushReplacement('/session/${widget.sessionId}/results');
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
      
      if (session.status == SessionStatus.results) {
        if (!_isNavigating && mounted) {
          _isNavigating = true;
          context.pushReplacement('/session/${widget.sessionId}/results');
        }
        return;
      }
      
      if (session.status != SessionStatus.voting) {
        if (!_isNavigating && mounted) {
          _isNavigating = true;
          context.pushReplacement('/session/${widget.sessionId}');
        }
        return;
      }
      
      setState(() {
        _session = session;
        _isLoading = false;
        
        if (_session!.currentList != null && (_availableItems.isEmpty || _rankedItems.isEmpty)) {
          final items = _session!.currentList!.items;
          _itemsMap = {for (var item in items) item.id: item};
          _availableItems = List.from(items);
          _rankedItems = List.filled(items.length, null);
        }
        
        _updateTimerFromSession(session);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _updateTimerFromSession(SessionModel session) {
    if (session.votingEndsAt != null) {
      final remaining = session.votingEndsAt!.difference(DateTime.now());
      final seconds = remaining.inSeconds;
      if (seconds > 0) {
        _startTimer(seconds);
      }
    }
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() {
      _timerSeconds = seconds;
      _showTimer = true;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _showTimer = false);
          // Только в мок-режиме отправляем случайный голос
          if (AppConfig.useMocks && !_hasVoted && !_isNavigating) {
            _submitEmptyVote();
          } else if (!AppConfig.useMocks) {
            // В реальном режиме просто обновляем статус
            _checkVotingStatus();
          }
        }
      } else {
        if (mounted) {
          setState(() => _timerSeconds--);
        }
      }
    });
  }

  Future<void> _submitEmptyVote() async {
    if (_hasVoted || _isNavigating) return;
    
    final allItemIds = _availableItems.map((item) => item.id).toList();
    final shuffledIds = List<int>.from(allItemIds)..shuffle();
    
    try {
      await _repository.submitVote(
        widget.sessionId,
        rankedItemIds: shuffledIds,
        spin: false,
      );
      
      if (mounted && AppConfig.useMocks) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted && !_isNavigating) {
          _isNavigating = true;
          context.pushReplacement('/session/${widget.sessionId}/results');
        }
      }
    } catch (e) {
      print('Error submitting empty vote: $e');
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _onDragStarted(int index) {
    setState(() {
      _draggingIndex = index;
    });
  }

  void _onDragEnded() {
    setState(() {
      _draggingIndex = null;
    });
  }

  bool _acceptDrag(int targetIndex) {
    if (_draggingIndex == null || _rankedItems[_draggingIndex!] == null) {
      return false;
    }
    
    final draggedItem = _rankedItems[_draggingIndex!];
    if (draggedItem != null) {
      setState(() {
        _rankedItems.removeAt(_draggingIndex!);
        _rankedItems.insert(targetIndex, draggedItem);
        _draggingIndex = null;
      });
      return true;
    }
    return false;
  }

  void _moveToRanked(int availableIndex) {
    if (!_isDraggingEnabled) return;
    
    final item = _availableItems[availableIndex];
    if (item == null) return;
    
    final firstEmptyIndex = _rankedItems.indexWhere((pos) => pos == null);
    if (firstEmptyIndex != -1) {
      setState(() {
        _rankedItems[firstEmptyIndex] = item;
        _availableItems.removeAt(availableIndex);
      });
    }
  }

  void _moveToAvailable(int rankedIndex) {
    if (!_isDraggingEnabled) return;
    
    final item = _rankedItems[rankedIndex];
    if (item == null) return;
    
    setState(() {
      _rankedItems[rankedIndex] = null;
      _availableItems.add(item);
      _availableItems.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    });
  }

  void _showItemDetails(SessionListItemModel item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                item.name,
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (item.description != null)
                Text(
                  item.description!,
                  style: AppTextStyles.bodyMedium,
                ),
              if (item.description == null)
                Text(
                  'Нет описания',
                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _submitVote() async {
    if (_rankedItems.any((pos) => pos == null)) {
      _showError('Пожалуйста, распределите все элементы по местам');
      return;
    }
    
    setState(() {
      _isDraggingEnabled = false;
      _isLoading = true;
    });
    
    final rankedIds = _rankedItems.map((item) => item!.id).toList();
    
    try {
      final result = await _repository.submitVote(
        widget.sessionId,
        rankedItemIds: rankedIds,
        spin: false,
      );
      
      if (mounted) {
        // В мок-режиме сразу переходим к результатам
        if (AppConfig.useMocks) {
          // Небольшая задержка для обработки на сервере
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && !_isNavigating) {
            _isNavigating = true;
            context.pushReplacement('/session/${widget.sessionId}/results');
          }
          return;
        }
        
        // Реальный режим
        setState(() {
          _hasVoted = true;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ваш голос принят!'),
            backgroundColor: Colors.green,
          ),
        );
        
        _startVotingStatusCheck();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDraggingEnabled = true;
          _isLoading = false;
        });
        _showError(e.toString());
      }
    }
  }


  void _startVotingStatusCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkVotingStatus();
    });
  }

  Future<void> _checkVotingStatus() async {
    if (_isNavigating) return;
    
    try {
      final session = await _repository.getLobby(widget.sessionId);
      if (mounted && session.status == SessionStatus.results) {
        _statusCheckTimer?.cancel();
        _isNavigating = true;
        context.pushReplacement('/session/${widget.sessionId}/results');
      }
    } catch (e) {
      print('Error checking voting status: $e');
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
        appBar: AppBar(title: const Text('Голосование')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_errorMessage ?? 'Сессия не найдена'),
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
    final participants = session.participants
        .where((p) => p.status == ParticipantStatus.accepted)
        .toList();
    final votedCount = participants.where((p) => p.hasVoted).length;
    final totalCount = participants.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ранжирование элементов'),
        actions: [
          // Счётчик проголосовавших (только для реального режима)
          if (!AppConfig.useMocks)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Проголосовали: $votedCount / $totalCount',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (_showTimer)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_timerSeconds),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _hasVoted && !AppConfig.useMocks
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    'Ваш голос принят!',
                    style: AppTextStyles.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ожидаем остальных участников...',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            )
          : Column(
              children: [
                // Верхняя часть - ранжированный список (DragTarget)
                Expanded(
                  flex: 1,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Ваш порядок предпочтения (1 - самый желаемый)',
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          child: DragTarget<int>(
                            onWillAccept: (data) => true,
                            onAccept: (index) {
                              if (_draggingIndex != null && _rankedItems[_draggingIndex!] != null) {
                                _acceptDrag(index);
                              } else {
                                _moveToRanked(index);
                              }
                            },
                            builder: (context, candidateData, rejectedData) {
                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _rankedItems.length,
                                itemBuilder: (context, index) {
                                  final item = _rankedItems[index];
                                  
                                  return LongPressDraggable<int>(
                                    data: index,
                                    dragAnchorStrategy: childDragAnchorStrategy,
                                    feedback: item != null
                                        ? Material(
                                            elevation: 4,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              width: MediaQuery.of(context).size.width - 32,
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: AppColors.primary),
                                              ),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        '${index + 1}',
                                                        style: TextStyle(
                                                          color: AppColors.primary,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      item.name,
                                                      style: AppTextStyles.bodyLarge,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          )
                                        : Container(),
                                    childWhenDragging: Opacity(
                                      opacity: 0.5,
                                      child: _buildRankedItem(item, index),
                                    ),
                                    onDragStarted: () => _onDragStarted(index),
                                    onDragEnd: (_) => _onDragEnded(),
                                    child: _buildRankedItem(item, index),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Нижняя часть - горизонтальный список доступных элементов
                Container(
                  height: 180,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Доступные элементы (перетащите вверх)',
                          style: AppTextStyles.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        child: DragTarget<int>(
                          onWillAccept: (data) => true,
                          onAccept: (index) => _moveToAvailable(index),
                          builder: (context, candidateData, rejectedData) {
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              itemCount: _availableItems.length,
                              itemBuilder: (context, index) {
                                final item = _availableItems[index];
                                return Draggable<int>(
                                  data: index,
                                  feedback: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: 200,
                                      margin: const EdgeInsets.all(4),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.primary),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: AppTextStyles.bodyLarge,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (item.description != null)
                                            Text(
                                              item.description!,
                                              style: AppTextStyles.bodySmall,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  childWhenDragging: Opacity(
                                    opacity: 0.5,
                                    child: _buildAvailableItem(item),
                                  ),
                                  child: _buildAvailableItem(item),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Кнопка отправки
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CustomButton(
                    text: 'Отправить результат',
                    onPressed: _submitVote,
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRankedItem(SessionListItemModel? item, int index) {
    final isEmpty = item == null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isEmpty ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isEmpty ? Colors.grey.shade300 : AppColors.primary,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isEmpty 
                      ? Colors.grey.shade200 
                      : AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isEmpty ? Colors.grey : AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEmpty ? 'ПЕРЕТАЩИТЕ СЮДА ЭЛЕМЕНТ ДЛЯ ВЫБОРА' : item!.name,
                  style: isEmpty
                      ? AppTextStyles.bodyMedium.copyWith(color: Colors.grey)
                      : AppTextStyles.bodyLarge,
                ),
              ),
              if (!isEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: () => _moveToAvailable(index),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableItem(SessionListItemModel item) {
    return Container(
      width: 200,
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: AppTextStyles.bodyLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          if (item.description != null && item.description!.isNotEmpty)
            Text(
              item.description!,
              style: AppTextStyles.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: TextButton(
              onPressed: () => _showItemDetails(item),
              child: const Text('Подробнее'),
            ),
          ),
        ],
      ),
    );
  }
}