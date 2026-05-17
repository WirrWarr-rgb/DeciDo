import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_scaffold.dart';
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
      title: "Иии...Вот итог!",
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
            // Фоновое SVG изображение
            Positioned(
              top: 46,
              left: 0,
              child: SvgPicture.asset(
                'assets/icons/result_celebration_icon.svg',
              ),
            ),
            // Карточка победителя
            Positioned(
              left: 51,
              top: 111,
              child: Container(
                width: 310,
                height: 640,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Stack(
                  children: [
                    // Место для изображения (заглушка)
                    Positioned(
                      left: 0,
                      top: -1,
                      child: Container(
                        width: 310,
                        height: 425,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: Colors.white),
                        child: Container(
                          width: 310,
                          height: 425,
                          color: AppColors.tertiary,
                          child: Center(
                            child: Icon(
                              Icons.image,
                              size: 80,
                              color: AppColors.textLight.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Градиент поверх изображения
                    Positioned(
                      left: 0,
                      top: 0,
                      child: Container(
                        width: 310,
                        height: 424,
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
                    
                    // Название победителя
                    Positioned(
                      left: 40,
                      top: 367,
                      child: SizedBox(
                        width: 229,
                        child: Text(
                          winner.name,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.resultName
                        ),
                      ),
                    ),
                    
                    // Белая карточка для описания
                    Positioned(
                      left: 20,
                      top: 430,
                      child: Container(
                        width: 270,
                        height: 190,
                        clipBehavior: Clip.antiAlias,
                        decoration: ShapeDecoration(
                          color: AppColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(21),
                          ),
                        ),
                      ),
                    ),
                    
                    // Описание
                    Positioned(
                      left: 27,
                      top: 433,
                      child: Container(
                        width: 256,
                        height: 181,
                        padding: const EdgeInsets.all(12),
                        child: SingleChildScrollView(
                          child: Text(
                            winner.description ?? 'Нет описания',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.resultDescription
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Кнопки внизу
            Positioned(
              left: 34,
              bottom: 30,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Кнопка "Покрутить ещё"
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SelectRandomListScreen(
                            preselectedList: list,
                          ),
                        ),
                      );
                    },
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
                          'Покрутить ещё',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.buttonBig.copyWith(color: AppColors.textSecondary)
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 20),
                  
                  // Кнопка "На главную"
                  GestureDetector(
                    onTap: () {
                      context.go('/home');
                    },
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
                          style: AppTextStyles.buttonBig
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
    );
  }
}