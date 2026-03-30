

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../providers/auth_controller_provider.dart';
import '../../providers/auth_state_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }
  
  Future<void> _checkAuth() async {
    await ref.read(authControllerProvider).checkAuth();
    final isAuth = ref.read(authStateProvider) != null;
    if (isAuth && mounted) {
      context.go(RouteNames.home);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.primary,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Текст с отступом перед кнопками
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Привет, друг!',
                      style: AppTextStyles.headlineLarge.copyWith(
                        height: 0.61,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Не можешь решить, что делать? Давай помогу!',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        height: 0.92,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Отступ между текстом и кнопками
              const SizedBox(height: 60),
              
              // Блок с кнопками
              Column(
                children: [
                  CustomButton(
                    text: 'Давай начнём!',
                    onPressed: () {
                      context.go(RouteNames.register);
                    },
                    width: 201,
                    fontSize: 24,
                    backgroundColor: AppColors.secondary,
                    textColor: AppColors.textLight,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Уже знакомы',
                    onPressed: () {
                      context.go(RouteNames.login);
                    },
                    width: 201,
                    fontSize: 20,
                    backgroundColor: AppColors.tertiary,
                    textColor: AppColors.textSecondary,
                    isOutlined: false,
                  ),
                ],
              ),
              
              // Отступ от кнопок до низа
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}