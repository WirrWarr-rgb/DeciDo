import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_scaffold.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../models/random_item_model.dart';
import 'select_random_list_screen.dart';

class RandomResultScreen extends StatelessWidget {
  final RandomListModel list;
  final RandomItemModel winner;

  const RandomResultScreen({
    super.key,
    required this.list,
    required this.winner,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'Результат',
      showBackButton: true,
      menuIconColor: AppColors.textPrimary,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.secondary,
                    AppColors.secondary.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    winner.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (winner.description != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        winner.description!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
            
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Покрутить ещё',
                    onPressed: () {
                      // Возвращаемся с выбранным списком
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SelectRandomListScreen(
                            preselectedList: list,
                          ),
                        ),
                      );
                    },
                    backgroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CustomButton(
                    text: 'На главную',
                    onPressed: () {
                      context.go('/home');
                    },
                    backgroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}