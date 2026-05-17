import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
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
  Map<int, Color> _itemColors = {};
  
  bool _isLoading = true;
  bool _hasVoted = false;
  String? _errorMessage;
  bool _isNavigating = false;
  bool _showDetails = false;
  
  Timer? _timer;
  int _timerSeconds = 0;
  bool _showTimer = false;
  
  Timer? _statusCheckTimer;
  
  int? _draggingFromRankedIndex;
  int? _draggingFromAvailableIndex;
  bool _isDraggingOverAvailableArea = false;

  final List<Color> _colorPalette = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.tertiary,
    AppColors.inputBackground,
    AppColors.primary,
    AppColors.secondary,
    AppColors.tertiary,
    AppColors.inputBackground,
  ];

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
      
      if (session.status != SessionStatus.voting && !AppConfig.useMocks) {
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
          
          for (int i = 0; i < items.length; i++) {
            _itemColors[items[i].id] = _colorPalette[i % _colorPalette.length];
          }
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
          if (AppConfig.useMocks && !_hasVoted && !_isNavigating) {
            _submitEmptyVote();
          } else if (!AppConfig.useMocks) {
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

  void _moveFromAvailableToRanked(int availableIndex, int targetRankedIndex) {
    if (availableIndex < 0 || availableIndex >= _availableItems.length) return;
    if (targetRankedIndex < 0 || targetRankedIndex >= _rankedItems.length) return;
    
    final item = _availableItems[availableIndex];
    if (item == null) return;
    
    setState(() {
      // Если позиция свободна - просто ставим
      if (_rankedItems[targetRankedIndex] == null) {
        _rankedItems[targetRankedIndex] = item;
        _availableItems.removeAt(availableIndex);
        return;
      }
      
      // Если позиция занята - ищем ближайшую свободную
      int? freeIndex;
      
      // Ищем свободную позицию выше
      for (int i = targetRankedIndex - 1; i >= 0; i--) {
        if (_rankedItems[i] == null) {
          freeIndex = i;
          break;
        }
      }
      
      // Ищем свободную позицию ниже
      if (freeIndex == null) {
        for (int i = targetRankedIndex + 1; i < _rankedItems.length; i++) {
          if (_rankedItems[i] == null) {
            freeIndex = i;
            break;
          }
        }
      }
      
      if (freeIndex != null) {
        _rankedItems[freeIndex] = item;
        _availableItems.removeAt(availableIndex);
      } else {
        // Нет свободных мест - меняем местами
        final displacedItem = _rankedItems[targetRankedIndex]!;
        _rankedItems[targetRankedIndex] = item;
        _availableItems.add(displacedItem);
        _availableItems.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        _availableItems.removeAt(availableIndex);
      }
    });
  }

  void _moveFromRankedToAvailable(int rankedIndex) {
    if (rankedIndex < 0 || rankedIndex >= _rankedItems.length) return;
    
    final item = _rankedItems[rankedIndex];
    if (item == null) return;
    
    setState(() {
      _rankedItems[rankedIndex] = null;
      _availableItems.add(item);
      _availableItems.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    });
  }

  void _moveFromRankedToRanked(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _rankedItems.length) return;
    if (newIndex < 0 || newIndex >= _rankedItems.length) return;
    
    final item = _rankedItems[oldIndex];
    if (item == null) return;
    
    setState(() {
      _rankedItems[oldIndex] = null;
      
      // Если целевая позиция свободна - просто вставляем
      if (_rankedItems[newIndex] == null) {
        _rankedItems[newIndex] = item;
      } else {
        // Если занята - сдвигаем элементы
        if (newIndex > oldIndex) {
          // Сдвиг вниз
          for (int i = oldIndex; i < newIndex; i++) {
            _rankedItems[i] = _rankedItems[i + 1];
          }
          _rankedItems[newIndex] = item;
        } else {
          // Сдвиг вверх
          for (int i = oldIndex; i > newIndex; i--) {
            _rankedItems[i] = _rankedItems[i - 1];
          }
          _rankedItems[newIndex] = item;
        }
      }
    });
  }

  void _showItemDetails(SessionListItemModel item) {
    setState(() {
      _showDetails = true;
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GestureDetector(
        onTap: () {
          setState(() {
            _showDetails = false;
          });
          Navigator.pop(context);
        },
        child: Container(
          height: 322,
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: GestureDetector(
            onTap: () {},
            child: Stack(
              children: [
                // Белая карточка
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    width: 412,
                    height: 322,
                    decoration: const ShapeDecoration(
                      color: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Место для картинки
                Positioned(
                  left: 20,
                  top: 24,
                  child: Container(
                    width: 150,
                    height: 211,
                    clipBehavior: Clip.antiAlias,
                    decoration: ShapeDecoration(
                      color: AppColors.tertiary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image,
                        color: AppColors.textLight.withOpacity(0.5),
                        size: 40,
                      ),
                    ),
                  ),
                ),
                
                // Название
                Positioned(
                  left: 178,
                  top: 24,
                  child: SizedBox(
                    width: 217,
                    child: Text(
                      item.name,
                      style: AppTextStyles.itemName.copyWith(color: AppColors.textSecondary)
                    ),
                  ),
                ),
                
                // Описание
                Positioned(
                  left: 178,
                  top: 60,
                  child: Container(
                    width: 217,
                    height: 180,
                    child: SingleChildScrollView(
                      child: Text(
                        item.description != null && item.description!.isNotEmpty
                            ? item.description!
                            : 'Нет описания',
                        style: AppTextStyles.itemDescription.copyWith(color: AppColors.textSecondary)
                      ),
                    ),
                  ),
                ),
                
                // Кнопка закрытия
                Positioned(
                  left: 284,
                  top: 244,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showDetails = false;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 110,
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: ShapeDecoration(
                        color: AppColors.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Закрыть',
                          style: AppTextStyles.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        _showDetails = false;
      });
    });
  }

  Future<void> _submitVote() async {
    if (_rankedItems.any((pos) => pos == null)) {
      _showError('Пожалуйста, распределите все элементы по местам');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    final rankedIds = _rankedItems.map((item) => item!.id).toList();
    
    try {
      await _repository.submitVote(
        widget.sessionId,
        rankedItemIds: rankedIds,
        spin: false,
      );
      
      if (mounted) {
        if (AppConfig.useMocks) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted && !_isNavigating) {
            _isNavigating = true;
            context.pushReplacement('/session/${widget.sessionId}/results');
          }
          return;
        }
        
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
                Text(_errorMessage ?? 'Сессия не найдена'),
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
    final participants = session.participants
        .where((p) => p.status == ParticipantStatus.accepted)
        .toList();
    final votedCount = participants.where((p) => p.hasVoted).length;
    final totalCount = participants.length;

    return CustomScaffold(
      title: "Составь рейтинг",
      body: Container(
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
            
            if (_showTimer)
              Positioned(
                right: 20,
                top: 56,
                child: Container(
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
              ),
            
            if (!AppConfig.useMocks)
              Positioned(
                right: 20,
                top: _showTimer ? 90 : 56,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Проголосовали: $votedCount / $totalCount',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ),
              ),
            
            if (!_hasVoted || AppConfig.useMocks)
              _buildRankingContent()
            else
              _buildWaitingContent(),
            
            Positioned(
              right: 0,
              left: 0,
              bottom: 30,
              child: Center(
                child: CustomButton(
                  text: 'ОТПРАВИТЬ РЕЗУЛЬТАТ',
                  onPressed: _submitVote,
                  width: 130,
                  backgroundColor: AppColors.secondary,
                  textStyle: AppTextStyles.buttonBig,
                ),
              ),
            ),
          
            if (_showDetails)
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
      ),
    );
  }

  Widget _buildRankedItem(SessionListItemModel? item, int index) {
    final isEmpty = item == null;
    final positionNumber = index + 1;
    
    // Определяем цвета в зависимости от позиции
    Color getBackgroundColor() {
      if (isEmpty) {
        if (positionNumber == 1) return const Color(0xFF8DA249);
        if (positionNumber == 2) return const Color(0xFF759DA9);
        if (positionNumber == 3) return const Color(0xFFF89254);
        return AppColors.background;
      } else {
        if (positionNumber == 1) return AppColors.primary;
        if (positionNumber == 2) return AppColors.inputBackground;
        if (positionNumber == 3) return AppColors.secondary;
        return AppColors.background;
      }
    }
    
    Color getTextColor() {
      if (isEmpty) {
        if (positionNumber == 1) return const Color(0xFF2E434F);
        if (positionNumber == 2) return const Color(0xFF2E434F);
        if (positionNumber == 3) return const Color(0xFFFBE1B5);
        return AppColors.textSecondary;
      } else {
        if (positionNumber == 1) return AppColors.textLight;
        if (positionNumber == 2) return AppColors.textLight;
        if (positionNumber == 3) return AppColors.textLight;
        return AppColors.textPrimary;
      }
    }
    
    Color getNumberBgColor() {
      if (positionNumber == 1) return const Color(0xFFF89254);
      if (positionNumber == 2) return const Color(0xFF2E434F);
      if (positionNumber == 3) return const Color(0xFFFFEF65);
      return const Color(0xFF759DA9);
    }
    
    Color getNumberTextColor() {
      if (positionNumber == 1) return const Color(0xFFFFEF65);
      if (positionNumber == 2) return const Color(0xFF759DA9);
      if (positionNumber == 3) return const Color(0xFFF89254);
      return const Color(0xFFFBE1B5);
    }
    
    Color getBorderColor() {
      if (isEmpty) {
        if (positionNumber <= 3) return Colors.transparent;
        return AppColors.textSecondary;
      } else {
        if (positionNumber <= 3) return Colors.transparent;
        return AppColors.textSecondary;
      }
    }
    
    final showImage = !isEmpty && positionNumber <= 3;
    final bgColor = getBackgroundColor();
    final textColor = getTextColor();
    final numberBgColor = getNumberBgColor();
    final numberTextColor = getNumberTextColor();
    final borderColor = getBorderColor();
    
    return Container(
      width: 339,
      height: 41,
      margin: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Основной контейнер с текстом
          Expanded(
            child: Container(
              width: 283,
              height: 41,
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: bgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                  side: borderColor != Colors.transparent 
                      ? BorderSide(color: borderColor, width: 2)
                      : BorderSide.none,
                ),
              ),
              child: Stack(
                children: [
                  // Изображение для первых трех позиций (только если не пусто)
                  if (showImage)
                    Positioned(
                      left: 0,
                      top: -156,
                      child: Container(
                        width: 290,
                        height: 354,
                        decoration: const BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage("https://placehold.co/283x354"),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  // Градиент для первых трех позиций (только если не пусто)
                  if (showImage)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 290,
                        height: 41,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: positionNumber == 1
                                ? [const Color(0xFF2E434F), const Color(0x002E434F), AppColors.primary]
                                : positionNumber == 2
                                ? [const Color(0xFF2E434F), const Color(0x002E434F), AppColors.inputBackground]
                                : [const Color(0xFF2E434F), const Color(0x002E434F), AppColors.secondary],
                          ),
                        ),
                      ),
                    ),
                  // Текст
                  Positioned(
                    left: 29,
                    top: 8,
                    child: SizedBox(
                      width: 230,
                      child: Text(
                        isEmpty ? 'Перетащите элемент сюда!' : item!.name,
                        style: AppTextStyles.rankingText.copyWith(color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 17),
          // Цифра с номером позиции
          Container(
            width: 32,
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: ShapeDecoration(
              color: numberBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Stack(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: ShapeDecoration(
                    color: numberTextColor,
                    shape: const OvalBorder(),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 2,
                  child: Center(
                    child: Text(
                      '$positionNumber',
                      style: AppTextStyles.rankingNumber.copyWith(color: numberBgColor)
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

  Widget _buildRankingContent() {
    return Column(
      children: [
        // Вертикальный список (ранжированные элементы)
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.fromLTRB(36, 100, 36, 8),
            child: ListView.builder(
              itemCount: _rankedItems.length,
              itemBuilder: (context, index) {
                final item = _rankedItems[index];
                
                return Container(
                  key: ValueKey(item?.id ?? index),
                  child: DragTarget<int>(
                    onWillAccept: (data) {
                      if (data != null && _draggingFromAvailableIndex != null) {
                        return true;
                      }
                      if (data != null && _draggingFromRankedIndex != null) {
                        return true;
                      }
                      return false;
                    },
                    onAccept: (data) {
                      if (_draggingFromAvailableIndex != null) {
                        _moveFromAvailableToRanked(_draggingFromAvailableIndex!, index);
                      } else if (_draggingFromRankedIndex != null) {
                        _moveFromRankedToRanked(_draggingFromRankedIndex!, index);
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      return LongPressDraggable<int>(
                        data: index,
                        delay: const Duration(milliseconds: 150),
                        dragAnchorStrategy: childDragAnchorStrategy,
                        feedback: item != null
                            ? Material(
                                elevation: 0,
                                color: Colors.transparent,
                                child: _buildRankedItem(item, index),
                              )
                            : Container(
                                width: 339,
                                height: 41,
                                child: _buildRankedItem(item, index),
                              ),
                        childWhenDragging: Opacity(
                          opacity: 0.5,
                          child: _buildRankedItem(item, index),
                        ),
                        onDragStarted: () {
                          setState(() {
                            _draggingFromRankedIndex = index;
                          });
                        },
                        onDragEnd: (_) {
                          setState(() {
                            _draggingFromRankedIndex = null;
                            _isDraggingOverAvailableArea = false;
                          });
                        },
                        child: _buildRankedItem(item, index),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
        
        // Горизонтальный список доступных элементов
        Container(
          height: 340,
          width: 412,
          margin: const EdgeInsets.only(left: 10, right: 10, bottom: 80),
          child: Stack(
            children: [
              // Основной контент (горизонтальный список)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final bgColor = _itemColors[item.id] ?? AppColors.primary;
                    
                    return Draggable<int>(
                      data: index,
                      feedback: Material(
                        elevation: 0,
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(24),
                        child: _buildCompactCard(item, bgColor),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.5,
                        child: _buildAvailableCard(item, bgColor),
                      ),
                      onDragStarted: () {
                        setState(() {
                          _draggingFromAvailableIndex = index;
                        });
                      },
                      onDragEnd: (_) {
                        setState(() {
                          _draggingFromAvailableIndex = null;
                        });
                      },
                      child: _buildAvailableCard(item, bgColor),
                    );
                  }).toList(),
                ),
              ),
              
              // DragTarget область поверх всего (всегда поверх и фиксированного размера)
              if (_draggingFromRankedIndex != null)
                Positioned.fill(
                  child: DragTarget<int>(
                    onWillAccept: (data) {
                      return data != null && _draggingFromRankedIndex != null;
                    },
                    onAccept: (data) {
                      if (_draggingFromRankedIndex != null) {
                        _moveFromRankedToAvailable(_draggingFromRankedIndex!);
                      }
                      setState(() {
                        _isDraggingOverAvailableArea = false;
                      });
                    },
                    onLeave: (data) {
                      setState(() {
                        _isDraggingOverAvailableArea = false;
                      });
                    },
                    onMove: (details) {
                      if (!_isDraggingOverAvailableArea) {
                        setState(() {
                          _isDraggingOverAvailableArea = true;
                        });
                      }
                    },
                    builder: (context, candidateData, rejectedData) {
                      final isActive = _isDraggingOverAvailableArea;
                      
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: isActive 
                              ? AppColors.secondary.withOpacity(0.15)
                              : AppColors.secondary.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isActive 
                                ? AppColors.secondary
                                : AppColors.secondary.withOpacity(0.5),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.move_to_inbox,
                              size: 48,
                              color: isActive 
                                  ? AppColors.secondary
                                  : AppColors.secondary.withOpacity(0.7),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _availableItems.isEmpty
                                  ? 'Перетащи сюда чтобы вернуть\nв нейтральный список'
                                  : 'Вернуть в нейтральный список',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isActive 
                                    ? AppColors.secondary
                                    : AppColors.secondary.withOpacity(0.7),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactCard(SessionListItemModel item, Color bgColor) {
    return Container(
      width: MediaQuery.of(context).size.width - 72,
      height: 41,
      padding: const EdgeInsets.only(top: 8, left: 29, right: 28, bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: Text(
          item.name,
          style: AppTextStyles.rankingText.copyWith(color: AppColors.textLight),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Color _getPositionColor(int index, bool isEmpty) {
    if (isEmpty) {
      if (index == 0) return AppColors.primary;
      if (index == 1) return AppColors.inputBackground;
      if (index == 2) return AppColors.secondary;
      return AppColors.background;
    } else {
      if (index == 0) return AppColors.primary;
      if (index == 1) return AppColors.inputBackground;
      if (index == 2) return AppColors.secondary;
      return AppColors.background;
    }
  }

  Color _getNumberBgColor(int index) {
    if (index == 0) return const Color(0xFFFFEF65);
    if (index == 1) return AppColors.tertiary;
    if (index == 2) return AppColors.secondary;
    return AppColors.textSecondary;
  }

  Color _getNumberTextColor(int index) {
    if (index == 0) return AppColors.secondary;
    if (index == 1) return AppColors.inputBackground;
    if (index == 2) return const Color(0xFFFFEF65);
    return AppColors.background;
  }

  Color _getTextColor(int index, bool isEmpty) {
    if (isEmpty) {
      if (index == 0) return AppColors.textPrimary;
      if (index == 1) return AppColors.textPrimary;
      if (index == 2) return AppColors.textLight;
      return AppColors.textSecondary;
    } else {
      if (index == 0) return AppColors.textLight;
      if (index == 1) return AppColors.textLight;
      if (index == 2) return AppColors.textLight;
      return AppColors.textPrimary;
    }
  }

  Border? _getBorder(int index, bool isEmpty) {
    if (isEmpty) return null;
    if (index < 3) return null;
    return Border.all(color: AppColors.textSecondary, width: 2);
  }


  Widget _buildAvailableCard(SessionListItemModel item, Color bgColor) {
    return Container(
      width: 193,
      height: 318,
      margin: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 193,
              height: 264,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Center(
                child: Icon(
                  Icons.image,
                  size: 60,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: 193,
              height: 265,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    bgColor.withOpacity(0),
                    bgColor,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 214,
            child: SizedBox(
              width: 146,
              child: Text(
                item.name,
                textAlign: TextAlign.center,
                style: AppTextStyles.rankingText.copyWith(color: AppColors.textLight),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned(
            left: 35,
            bottom: 12,
            child: GestureDetector(
              onTap: () => _showItemDetails(item),
              child: Container(
                width: 124,
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.textLight,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Подробнее',
                      style: AppTextStyles.itemAboutButton,
                    ),
                    const SizedBox(width: 4),
                    SvgPicture.asset(
                      'assets/icons/navigation_arrow_down.svg',
                      width: 12,
                      height: 12,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingContent() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 64, color: Colors.green),
          SizedBox(height: 16),
          Text(
            'Ваш голос принят!',
            style: AppTextStyles.headlineMedium,
          ),
          SizedBox(height: 8),
          Text(
            'Ожидаем остальных участников...',
            style: AppTextStyles.bodyMedium,
          ),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    );
  }
}