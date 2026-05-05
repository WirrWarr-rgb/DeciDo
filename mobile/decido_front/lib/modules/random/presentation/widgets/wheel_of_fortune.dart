import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../models/random_item_model.dart';

class WheelOfFortune extends StatefulWidget {
  final List<RandomItemModel> items;
  final Function(RandomItemModel) onSpinEnd;
  final Duration spinDuration;
  final Curve spinCurve; // Кривая замедления
  final int minRotations; // Минимальное количество оборотов
  final int maxRotations; // Максимальное количество оборотов
  final double maxLiftDistance; // Максимальное расстояние выдвижения (пиксели)

  const WheelOfFortune({
    super.key,
    required this.items,
    required this.onSpinEnd,
    this.spinDuration = const Duration(seconds: 4),
    this.spinCurve = Curves.easeOutBack, // Плавное замедление с легким отскоком
    this.minRotations = 6,
    this.maxRotations = 12,
    this.maxLiftDistance = 50,
  });

  @override
  State<WheelOfFortune> createState() => _WheelOfFortuneState();
}

class _WheelOfFortuneState extends State<WheelOfFortune>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentAngle = 0;
  double _targetAngle = 0;
  bool _isSpinning = false;
  bool _hasStopped = false;
  bool _showWinnerConfirmation = false;
  RandomItemModel? _winner;
  int? _currentWinnerIndex;
  
  final double _radius = 180;
  final double _cardWidth = 200;
  final double _cardHeight = 80;
  final double _baseRadius = 130;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.spinDuration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Определяем силу выдвижения для элемента
  double _getLiftStrength(int itemIndex, double wheelAngle) {
    const pointerAngle = -pi / 2;
    
    final sectorAngle = 2 * pi / widget.items.length;
    final localCardAngle = sectorAngle * (itemIndex + 0.5);
    final globalCardAngle = localCardAngle + wheelAngle;
    
    var angleDiff = (globalCardAngle - pointerAngle) % (2 * pi);
    if (angleDiff > pi) angleDiff = 2 * pi - angleDiff;
    
    final maxDistance = sectorAngle / 2;
    if (angleDiff <= maxDistance) {
      final strength = 1.0 - pow(angleDiff / maxDistance, 1.5); // Более резкий пик
      return strength.toDouble();
    }
    
    return 0.0;
  }

  // Определяем победителя
  RandomItemModel _getWinnerByAngle(double wheelAngle) {
    const pointerAngle = -pi / 2;
    final angleUnderPointer = (pointerAngle - wheelAngle) % (2 * pi);
    final sectorAngle = 2 * pi / widget.items.length;
    final sectorIndex = (angleUnderPointer / sectorAngle).floor();
    return widget.items[sectorIndex % widget.items.length];
  }

  void _updateCurrentWinner() {
    if (!_isSpinning) return;
    
    final currentWinner = _getWinnerByAngle(_currentAngle);
    final newWinnerIndex = widget.items.indexOf(currentWinner);
    
    if (_currentWinnerIndex != newWinnerIndex) {
      setState(() {
        _currentWinnerIndex = newWinnerIndex;
      });
    }
  }

  void _startSpin() {
    if (_isSpinning) return;
    
    setState(() {
      _isSpinning = true;
      _hasStopped = false;
      _showWinnerConfirmation = false;
      _winner = null;
      _currentWinnerIndex = null;
    });
    
    final random = Random();
    // Используем настраиваемые обороты
    final fullRotations = widget.minRotations + random.nextInt(widget.maxRotations - widget.minRotations + 1);
    
    final sectorAngle = 2 * pi / widget.items.length;
    
    final winnerIndex = random.nextInt(widget.items.length);
    final offsetInSector = random.nextDouble() * sectorAngle;
    
    const pointerAngle = -pi / 2;
    final targetWheelAngle = (pointerAngle - (winnerIndex * sectorAngle + offsetInSector)) % (2 * pi);
    
    _targetAngle = _currentAngle + (fullRotations * 2 * pi);
    
    final currentNormalized = _currentAngle % (2 * pi);
    var deltaToTarget = targetWheelAngle - currentNormalized;
    if (deltaToTarget < 0) deltaToTarget += 2 * pi;
    
    _targetAngle += deltaToTarget;
    
    // Используем настраиваемую кривую замедления
    _animation = Tween<double>(
      begin: _currentAngle,
      end: _targetAngle,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.spinCurve,
    ));
    
    _animation.removeListener(_onAnimationUpdate);
    _animation.addListener(_onAnimationUpdate);
    
    _controller.reset();
    _controller.forward().then((_) {
      setState(() {
        _hasStopped = true;
        _isSpinning = false;
        _showWinnerConfirmation = true;
      });
      _finalizeWinner();
    });
  }
  
  void _onAnimationUpdate() {
    setState(() {
      _currentAngle = _animation.value;
    });
    _updateCurrentWinner();
  }

  void _finalizeWinner() {
    final winner = _getWinnerByAngle(_currentAngle);
    
    print('═══════════════════════════════════════');
    print('Winner: ${winner.name}');
    print('Rotations: ${widget.minRotations}-${widget.maxRotations}');
    print('Duration: ${widget.spinDuration.inSeconds} seconds');
    print('Curve: ${widget.spinCurve.toString()}');
    print('═══════════════════════════════════════');
    
    setState(() {
      _winner = winner;
      _currentWinnerIndex = widget.items.indexOf(winner);
    });
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _winner != null) {
        widget.onSpinEnd(_winner!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final centerX = screenWidth / 2;
    final totalHeight = _radius * 2 + 200;
    
    final List<Color> segmentColors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      AppColors.inputBackground,
      AppColors.primary.withOpacity(0.8),
      AppColors.secondary.withOpacity(0.8),
      AppColors.tertiary.withOpacity(0.8),
      AppColors.inputBackground.withOpacity(0.8),
    ];
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Крути колесо!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        
        const SizedBox(height: 20),
        
        SizedBox(
          height: totalHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Указатель сверху
              Positioned(
                top: 0,
                left: centerX - 20,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_drop_down,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              
              // Область вращения
              Positioned(
                top: 40,
                left: centerX - _radius,
                child: SizedBox(
                  width: _radius * 2,
                  height: _radius * 2,
                  child: Transform.rotate(
                    angle: _currentAngle,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(widget.items.length, (index) {
                        final sectorAngle = 2 * pi / widget.items.length;
                        final cardAngle = sectorAngle * (index + 0.5);
                        
                        double liftStrength = 0;
                        if (_isSpinning) {
                          liftStrength = _getLiftStrength(index, _currentAngle);
                        } else if (_hasStopped && _winner?.id == widget.items[index].id) {
                          liftStrength = 1.0;
                          liftStrength += sin(DateTime.now().millisecondsSinceEpoch / 200) * 0.15;
                          liftStrength = min(liftStrength, 1.2);
                        }
                        
                        final currentLift = liftStrength * widget.maxLiftDistance;
                        
                        double x = _baseRadius * cos(cardAngle);
                        double y = _baseRadius * sin(cardAngle);
                        
                        if (currentLift > 0) {
                          final directionX = x / _baseRadius;
                          final directionY = y / _baseRadius;
                          x += directionX * currentLift;
                          y += directionY * currentLift;
                        }
                        
                        final isWinner = _hasStopped && _winner?.id == widget.items[index].id;
                        final isCurrentWinner = _isSpinning && _currentWinnerIndex == index;
                        final segmentColor = segmentColors[index % segmentColors.length];
                        
                        return Positioned(
                          key: ValueKey('${index}_${liftStrength.toStringAsFixed(2)}'),
                          left: _radius + x - _cardWidth / 2,
                          top: _radius + y - _cardHeight / 2,
                          child: Transform.rotate(
                            angle: cardAngle,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 50),
                              width: _cardWidth,
                              height: _cardHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: (isWinner || isCurrentWinner || liftStrength > 0.7)
                                      ? [AppColors.secondary, AppColors.secondary.withOpacity(0.7)]
                                      : [segmentColor, segmentColor.withOpacity(0.8)],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(liftStrength > 0 ? 0.4 : 0.2),
                                    blurRadius: liftStrength > 0 ? 12 : 6,
                                    offset: Offset(liftStrength > 0 ? 4 : 2, liftStrength > 0 ? 6 : 3),
                                  ),
                                ],
                                border: Border.all(
                                  color: (isWinner || isCurrentWinner || liftStrength > 0.7) ? Colors.white : Colors.transparent,
                                  width: liftStrength > 0.7 ? 3 : 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Stack(
                                  children: [
                                    Container(
                                      color: Colors.white.withOpacity(liftStrength > 0 ? 0.2 : 0.1),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withOpacity(liftStrength > 0 ? 0.3 : 0.2),
                                            Colors.transparent,
                                            Colors.black.withOpacity(liftStrength > 0 ? 0.4 : 0.3),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isCurrentWinner || (isWinner && liftStrength > 0.7))
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Icon(
                                          Icons.arrow_drop_down,
                                          color: Colors.white,
                                          size: liftStrength > 0.7 ? 24 : 20,
                                        ),
                                      ),
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Text(
                                          widget.items[index].name,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: AppColors.textLight,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            shadows: liftStrength > 0.7 ? [
                                              Shadow(
                                                color: Colors.black.withOpacity(0.3),
                                                blurRadius: 4,
                                                offset: const Offset(1, 1),
                                              ),
                                            ] : null,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              
              // Центральная ось
              Positioned(
                left: centerX - 25,
                top: 40 + _radius - 25,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.secondary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.casino,
                    color: AppColors.secondary,
                    size: 30,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Индикатор текущего лидера
        if ((_isSpinning || _hasStopped) && _currentWinnerIndex != null && !_showWinnerConfirmation)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary,
                  AppColors.secondary.withOpacity(0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Лидер: ${widget.items[_currentWinnerIndex!].name}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                  size: 28,
                ),
              ],
            ),
          ),
        
        // Победитель!
        if (_showWinnerConfirmation && _winner != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber,
                  Colors.orange,
                ],
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 8),
                const Text(
                  'ПОБЕДИТЕЛЬ!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _winner!.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 16),
        
        Text(
          'Элементов: ${widget.items.length}',
          style: AppTextStyles.bodySmall,
        ),
        
        const SizedBox(height: 24),
        
        if (!_isSpinning && !_showWinnerConfirmation)
          Column(
            children: [
              CustomButton(
                text: 'Крутить!',
                onPressed: _startSpin,
                backgroundColor: AppColors.secondary,
                width: 200,
              ),
              const SizedBox(height: 12),
              Text(
                'Длительность: ${widget.spinDuration.inSeconds} сек',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        
        if (_isSpinning || _showWinnerConfirmation)
          const SizedBox(height: 56),
      ],
    );
  }
}