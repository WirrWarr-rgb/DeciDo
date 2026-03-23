

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_names.dart';
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Icon(
              Icons.how_to_vote,
              size: 120,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 32),
            Text(
              'Добро пожаловать в DeciDo!',
              style: AppTextStyles.headline1,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Приложение для совместного принятия решений. Создавайте списки, приглашайте друзей и выбирайте вместе!',
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            CustomButton(
              text: 'Войти',
              onPressed: () {
                context.go(RouteNames.login);
              },
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'Зарегистрироваться',
              onPressed: () {
                context.go(RouteNames.register);
              },
              isOutlined: true,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}