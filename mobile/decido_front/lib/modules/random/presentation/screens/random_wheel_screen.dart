import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_scaffold.dart';
import '../../models/random_item_model.dart';
import '../widgets/wheel_of_fortune.dart';
import 'random_result_screen.dart';

class RandomWheelScreen extends ConsumerStatefulWidget {
  final RandomListModel list;

  const RandomWheelScreen({
    super.key,
    required this.list,
  });

  @override
  ConsumerState<RandomWheelScreen> createState() => _RandomWheelScreenState();
}

class _RandomWheelScreenState extends ConsumerState<RandomWheelScreen> {
  bool _hasSpun = false;

  void _onSpinEnd(RandomItemModel winner) {
    if (!_hasSpun) {
      setState(() => _hasSpun = true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RandomResultScreen(
            list: widget.list,
            winner: winner,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: 412,
        height: 892,
        decoration: ShapeDecoration(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Stack(
          children: [

            // Заголовок
            Positioned(
              left: 100,
              top: 112,
              child: Text(
                'Крути колесо!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 32,
                  fontFamily: 'Instrument Sans',
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
            
            // Колесо
            Positioned(
              left: 0,
              top: 220,
              right: 0,
              bottom: 0,
              child: SingleChildScrollView(
                child: WheelOfFortune(
                  items: widget.list.items,
                  onSpinEnd: _onSpinEnd,
                  
                  // Медленное, напряженное вращение
                  spinDuration: Duration(seconds: 12),
                  spinCurve: Curves.easeOutExpo,
                  minRotations: 2,
                  maxRotations: 6,
                  
                  // Быстрое, энергичное вращение
                  // spinDuration: Duration(seconds: 3),
                  // spinCurve: Curves.easeOutCubic,
                  // minRotations: 4,
                  // maxRotations: 8,
                  
                  // С эффектом "отскока" в конце
                  // spinDuration: Duration(seconds: 5),
                  // spinCurve: Curves.easeOutBack,
                  // minRotations: 6,
                  // maxRotations: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}