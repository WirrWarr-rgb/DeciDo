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
    return CustomScaffold(
      title: widget.list.name,
      showBackButton: true,
      menuIconColor: AppColors.textPrimary,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: WheelOfFortune(
              items: widget.list.items,
              onSpinEnd: _onSpinEnd,

              // Медленное, напряженное вращение
              spinDuration: Duration(seconds: 12),
              spinCurve: Curves.easeOutExpo,
              minRotations: 2,
              maxRotations: 6,


              // Быстрое, энергичное вращение
              //spinDuration: Duration(seconds: 3),
              //spinCurve: Curves.easeOutCubic,
              //minRotations: 4,
              //maxRotations: 8,

              // С эффектом "отскока" в конце
              //spinDuration: Duration(seconds: 5),
              //spinCurve: Curves.easeOutBack,
              //minRotations: 6,
              //maxRotations: 12,
            ),
          ),
        ),
      ),
    );
  }
}