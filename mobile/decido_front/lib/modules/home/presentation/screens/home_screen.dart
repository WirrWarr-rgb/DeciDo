import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../auth/providers/auth_controller_provider.dart';
import '../../../auth/providers/auth_state_provider.dart';
import '../../../shared/widgets/custom_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    final username = user?.username ?? 'Гость';
    
    return CustomScaffold(
      title: "",
      menuIconColor: AppColors.background,
      body: Container(
        width: 412,
        height: 892,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Stack(
          children: [
            // Градиентный фон
            //Positioned(
            //  left: 0,
            //  top: 0,
            //  child: Container(
            //    width: 412,
            //    height: 174,
            //    decoration: BoxDecoration(
            //      gradient: const LinearGradient(
            //        begin: Alignment(0.50, -0.00),
            //        end: Alignment(0.50, 1.00),
            //        colors: [AppColors.tertiary, AppColors.primary],
            //      ),
            //    ),
            //  ),
            //),
            
            // Левая половина градиента
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: 206,
                height: 892,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment(0.50, 1.00),
                    end: Alignment(0.50, -1.00),
                    colors: [AppColors.tertiary, AppColors.primary],
                  ),
                ),
              ),
            ),
            
            // Правая половина градиента
            Positioned(
              left: 206,
              top: 0,
              child: Container(
                width: 206,
                height: 892,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment(0.50, 1.00),
                    end: Alignment(0.50, -1.00),
                    colors: [AppColors.secondary, AppColors.primary],
                  ),
                ),
              ),
            ),
        
            // Приветственный текст
            Positioned(
              left: 35,
              top: 140,
              child: SizedBox(
                width: 358,
                height: 100,
                child: Center(
                  child: Text(
                    'Что будем делать сегодня, $username?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 36,
                      fontFamily: 'Instrument Sans',
                      fontWeight: FontWeight.w700,
                      height: 0.97,
                    ),
                  ),
                ),
              ),
            ),
            
            // Левая кнопка - "Помоги выбрать" (Колесо фортуны)
            Positioned(
              left: 29,
              top: 330,
              child: GestureDetector(
                onTap: () {
                  context.push('/select-random-list');
                },
                child: SizedBox(
                  width: 148,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Иконка для колеса фортуны
                      Container(
                        width: 89,
                        height: 89,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.casino,
                            color: AppColors.textLight,
                            size: 50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 148,
                        child: Text(
                          'Помоги выбрать',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 24,
                            fontFamily: 'Instrument Sans',
                            fontWeight: FontWeight.w700,
                            height: 0.83,
                            letterSpacing: 0.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Правая кнопка - "Выберу с друзьями" (Создать лобби)
            Positioned(
              left: 235,
              top: 330,
              child: GestureDetector(
                onTap: () {
                  context.push(RouteNames.createSession);
                },
                child: SizedBox(
                  width: 148,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Иконка для лобби
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.groups,
                            color: AppColors.textLight,
                            size: 50,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(
                        width: 148,
                        child: Text(
                          'Выберу с друзьями',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textLight,
                            fontSize: 24,
                            fontFamily: 'Instrument Sans',
                            fontWeight: FontWeight.w700,
                            height: 0.83,
                            letterSpacing: 0.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}