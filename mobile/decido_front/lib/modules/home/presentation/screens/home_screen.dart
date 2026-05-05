import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../auth/providers/auth_controller_provider.dart';
import '../../../auth/providers/auth_state_provider.dart';
import '../../../shared/widgets/custom_drawer.dart';
import '../../../shared/widgets/custom_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    
    return CustomScaffold(
      title: 'DeciDo',
      menuIconColor: AppColors.textLight, 
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Добро пожаловать, ${user?.username ?? 'Гость'}!',
              style: AppTextStyles.headlineLarge,
            ),
            const SizedBox(height: 48),
            
            Text(
              'Что хочешь сделать?',
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: 48),
            
            // Кнопка перехода к спискам
            CustomButton(
              text: 'Мои списки',
              onPressed: () {
                context.push(RouteNames.myLists);
              },
              icon: Icons.list,
              width: 200,
            ),
            const SizedBox(height: 48),

            // Кнопка перехода к друзьям
            CustomButton(
              text: 'Мои друзья',
              onPressed: () {
                context.push(RouteNames.friends);
              },
              icon: Icons.people,
              width: 200,
            ),
            const SizedBox(height: 48),

            // Кнопка перехода к созданию лобби
            CustomButton(
              text: 'Создать лобби',
              onPressed: () {
                context.push(RouteNames.createSession);
              },
              icon: Icons.groups,
              width: 200,
            ),
            const SizedBox(height: 48),

            CustomButton(
              text: 'Случайный выбор',
              onPressed: () {
                context.push('/select-random-list');
              },
              icon: Icons.casino,
              width: 200,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(authControllerProvider).logout();
              if (context.mounted) {
                context.go(RouteNames.login);
              }
            },
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}