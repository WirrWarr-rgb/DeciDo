import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_scaffold.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../providers/session_providers.dart';
import '../../repository/i_session_repository.dart';
import '../../services/websocket_service.dart';
import '../../models/session_models.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final int sessionId;

  const ResultsScreen({super.key, required this.sessionId});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  late ISessionRepository _repository;
  late WebSocketService _webSocket;
  
  SessionModel? _session;
  Map<String, dynamic>? _results;
  List<Map<String, dynamic>> _rankedResults = [];
  Map<String, dynamic>? _winner;
  Map<int, SessionListItemModel> _itemsMap = {};
  
  bool _isLoading = true;
  bool _isOwner = false;
  String? _errorMessage;
  bool _isNavigating = false;
  bool _showDetails = false;
  SessionListItemModel? _selectedItem;
  
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(sessionRepositoryProvider);
    _webSocket = WebSocketService.instance;
    _initWebSocket();
    _loadResults();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _webSocket.removeListener(_handleWebSocketMessage);
    super.dispose();
  }

  void _initWebSocket() {
    _webSocket.addListener(_handleWebSocketMessage);
  }

  void _handleWebSocketMessage(WSMessage message) {
    if (!mounted) return;
    
    switch (message.type) {
      case WSMessageType.resultsReady:
        _loadResults();
        break;
      case WSMessageType.lobbyClosed:
        if (!_isNavigating && mounted) {
          _isNavigating = true;
          context.go('/home');
        }
        break;
      case WSMessageType.stateChanged:
        _loadResults();
        break;
      case WSMessageType.error:
        _showError(message.payload['message'] ?? 'Ошибка');
        break;
      default:
        break;
    }
  }

  Future<void> _loadResults() async {
    if (!mounted) return;
    try {
      final session = await _repository.getLobby(widget.sessionId);
      if (!mounted) return;
      
      // Загружаем карту элементов для получения описаний
      if (session.currentList != null) {
        for (var item in session.currentList!.items) {
          _itemsMap[item.id] = item;
        }
      }
      
      if (session.status != SessionStatus.results) {
        try {
          final resultsData = await _repository.getResults(widget.sessionId);
          if (!mounted) return;
          setState(() {
            _results = resultsData;
            _winner = resultsData['winner'];
            _rankedResults = List<Map<String, dynamic>>.from(resultsData['results']);
            _rankedResults.removeWhere((r) => _winner != null && r['item_id'] == _winner!['item_id']);
            _isOwner = session.isOwner;
            _isLoading = false;
          });
        } catch (e) {
          _startPolling();
        }
        return;
      }
      
      setState(() {
        _session = session;
        _results = session.results;
        _winner = session.results?['winner'];
        _rankedResults = List<Map<String, dynamic>>.from(session.results?['results'] ?? []);
        _rankedResults.removeWhere((r) => _winner != null && r['item_id'] == _winner!['item_id']);
        _isOwner = session.isOwner;
        _isLoading = false;
      });
      
      _pollingTimer?.cancel();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadResults();
    });
  }

  Future<void> _goToLobby() async {
    if (_isNavigating) return;
    _isNavigating = true;
    
    if (_isOwner) {
      try {
        await _repository.backToLobby(widget.sessionId);
        if (mounted) {
          context.pushReplacement('/session/${widget.sessionId}');
        }
      } catch (e) {
        _showError(e.toString());
        _isNavigating = false;
      }
    } else {
      try {
        final session = await _repository.getLobby(widget.sessionId);
        if (session.status == SessionStatus.results) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ожидаем хоста...')),
            );
          }
          _isNavigating = false;
          return;
        }
        if (mounted) {
          context.pushReplacement('/session/${widget.sessionId}');
        }
      } catch (e) {
        _showError(e.toString());
        _isNavigating = false;
      }
    }
  }

  Future<void> _goToHome() async {
    if (_isNavigating) return;
    _isNavigating = true;
    
    if (_isOwner) {
      try {
        await _repository.closeLobby(widget.sessionId);
        if (mounted) {
          context.go('/home');
        }
      } catch (e) {
        _showError(e.toString());
        _isNavigating = false;
      }
    } else {
      try {
        await _repository.leaveLobby(widget.sessionId);
        if (mounted) {
          context.go('/home');
        }
      } catch (e) {
        _showError(e.toString());
        _isNavigating = false;
      }
    }
  }

  SessionListItemModel? _getItemFromMap(Map<String, dynamic> itemData) {
    final itemId = itemData['item_id'];
    if (itemId != null && _itemsMap.containsKey(itemId)) {
      return _itemsMap[itemId];
    }
    return null;
  }

  void _showItemDetails(Map<String, dynamic> itemData) {
    final sessionItem = _getItemFromMap(itemData);
    
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
                      itemData['item_name'] ?? 'Элемент',
                      style: AppTextStyles.itemName.copyWith(color: AppColors.textSecondary)
                    ),
                  ),
                ),
                
                // Информация о месте и очках
                Positioned(
                  left: 178,
                  top: 60,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Место:   ${itemData['place']}',
                        style: AppTextStyles.itemDescription.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w900)
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Очков:   ${itemData['total_score']}',
                        style: AppTextStyles.itemDescription.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w900)
                      ),
                    ],
                  ),
                ),
                
                // Описание (из SessionListItemModel)
                Positioned(
                  left: 178,
                  top: 120,
                  child: Container(
                    width: 217,
                    height: 120,
                    child: SingleChildScrollView(
                      child: Text(
                        sessionItem?.description != null && sessionItem!.description!.isNotEmpty
                            ? sessionItem.description!
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

    if (_errorMessage != null || _results == null) {
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
                Text(_errorMessage ?? 'Результаты не найдены'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadResults,
                  child: const Text('Обновить'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('На главную'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CustomScaffold(
      title: "Победитель",
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
                // Фоновое SVG изображение
                Positioned(
                  top: 46,
                  left: 0,
                  child: SvgPicture.asset(
                    'assets/icons/result_celebration_icon.svg',
                  ),
                ),
                // Карточка победителя
                if (_winner != null)
                  Positioned(
                    left: 109,
                    top: 113,
                    child: GestureDetector(
                      onTap: () => _showItemDetails(_winner!),
                      child: Container(
                        width: 193,
                        height: 318,
                        clipBehavior: Clip.antiAlias,
                        decoration: ShapeDecoration(
                          color: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Изображение
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
                            // Градиент
                            Positioned(
                              left: 0,
                              top: 0,
                              child: Container(
                                width: 193,
                                height: 264,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppColors.primary.withOpacity(0),
                                      AppColors.primary,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Название
                            Positioned(
                              left: 24,
                              top: 214,
                              child: SizedBox(
                                width: 146,
                                child: Text(
                                  _winner!['item_name'] ?? 'Элемент',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.rankingText.copyWith(color: AppColors.textLight),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            // Кнопка "Подробнее"
                            Positioned(
                              left: 35,
                              bottom: 12,
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
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Список остальных результатов
                if (_rankedResults.isNotEmpty)
                  Positioned(
                    left: 36,
                    top: 467,
                    child: Container(
                      width: 339,
                      height: 325,
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _rankedResults.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 15),
                        itemBuilder: (context, index) {
                          final item = _rankedResults[index];
                          final place = item['place'];
                          final positionNumber = place;
                          
                          Color getBackgroundColor() {
                            if (positionNumber == 2) return const Color(0xFF759DA9);
                            if (positionNumber == 3) return const Color(0xFFF89254);
                            return AppColors.background;
                          }
                          
                          Color getTextColor() {
                            if (positionNumber == 2) return AppColors.textPrimary;
                            if (positionNumber == 3) return AppColors.textLight;
                            return AppColors.textPrimary;
                          }
                          
                          Color getNumberBgColor() {
                            if (positionNumber == 2) return const Color(0xFF2E434F);
                            if (positionNumber == 3) return const Color(0xFFFFEF65);
                            return const Color(0xFF759DA9);
                          }
                          
                          Color getNumberTextColor() {
                            if (positionNumber == 2) return const Color(0xFF759DA9);
                            if (positionNumber == 3) return const Color(0xFFF89254);
                            return const Color(0xFFFBE1B5);
                          }
                          
                          bool hasBorder = positionNumber > 3;
                          
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showItemDetails(item),
                                  child: Container(
                                    width: 283,
                                    height: 41,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: ShapeDecoration(
                                      color: getBackgroundColor(),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(25),
                                        side: hasBorder
                                            ? const BorderSide(color: AppColors.textSecondary, width: 2)
                                            : BorderSide.none,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: 29,
                                          top: 8,
                                          child: SizedBox(
                                            width: 230,
                                            child: Text(
                                              item['item_name'] ?? 'Элемент',
                                              style: AppTextStyles.rankingText.copyWith(color: getTextColor()),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 17),
                              Container(
                                width: 32,
                                height: 32,
                                padding: const EdgeInsets.all(2),
                                decoration: ShapeDecoration(
                                  color: getNumberBgColor(),
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
                                        color: getNumberTextColor(),
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
                                          style: AppTextStyles.rankingNumber.copyWith(color: getNumberBgColor())
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                
                // Кнопки
                Positioned(
                  left: 34,
                  bottom: 30,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _goToLobby,
                        child: Container(
                          width: 170,
                          height: 40,
                          padding: const EdgeInsets.all(1),
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                width: 2,
                                color: AppColors.textSecondary,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'В лобби',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.buttonBig.copyWith(color: AppColors.textSecondary)
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: _goToHome,
                        child: Container(
                          width: 155,
                          height: 40,
                          padding: const EdgeInsets.all(1),
                          decoration: ShapeDecoration(
                            color: AppColors.secondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'На главную',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.buttonBig,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Затемнение при открытом bottom sheet
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
    );
  }
}