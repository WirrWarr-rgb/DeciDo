import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
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
  
  bool _isLoading = true;
  bool _isOwner = false;
  String? _errorMessage;
  bool _isNavigating = false;
  
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
      if (mounted) {
        context.pushReplacement('/session/${widget.sessionId}');
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

  void _showItemDetails(Map<String, dynamic> item) {
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
                item['item_name'] ?? 'Элемент',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Очков: ${item['total_score']}',
                style: AppTextStyles.bodyMedium,
              ),
              Text(
                'Место: ${item['place']}',
                style: AppTextStyles.bodyMedium,
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
        appBar: AppBar(title: const Text('Результаты')),
        body: Center(
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
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Результаты голосования'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Заголовок "Победитель"
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '🏆 ПОБЕДИТЕЛЬ 🏆',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Карточка победителя
                  if (_winner != null)
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.secondary,
                            AppColors.secondary.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showItemDetails(_winner!),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  size: 48,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _winner!['item_name'] ?? 'Элемент',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Очков: ${_winner!['total_score']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Разделитель
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade300,
                      thickness: 1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Остальные участники',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: Colors.grey.shade300,
                      thickness: 1,
                    ),
                  ),
                ],
              ),
            ),
            
            // Список остальных участников
            if (_rankedResults.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Нет данных',
                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rankedResults.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _rankedResults[index];
                  final place = item['place'];
                  
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      onTap: () => _showItemDetails(item),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Место
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getPlaceColor(place).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  _getPlaceText(place),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getPlaceColor(place),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            
                            // Название элемента
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['item_name'] ?? 'Элемент',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Очков: ${item['total_score']}',
                                    style: AppTextStyles.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            
                            // Иконка
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            
            const SizedBox(height: 24),
            
            // Кнопки
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'В лобби',
                    onPressed: _goToLobby,
                    backgroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'На главную',
                    onPressed: _goToHome,
                    backgroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Color _getPlaceColor(int place) {
    switch (place) {
      case 2:
        return Colors.blue;
      case 3:
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _getPlaceText(int place) {
    switch (place) {
      case 1:
        return '1st';
      case 2:
        return '2nd';
      case 3:
        return '3rd';
      default:
        return '${place}th';
    }
  }
}