

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_names.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../auth/providers/auth_controller_provider.dart';
import '../../../auth/providers/auth_state_provider.dart';  // ← Добавляем этот импорт

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);  // ← Теперь работает
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Главная'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context, ref),
            tooltip: 'Выйти',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Приветствие пользователя
            Text(
              'Добро пожаловать, ${user?.username ?? 'Гость'}!',
              style: AppTextStyles.headline1,
            ),
            const SizedBox(height: 20),
            Text(
              'Здесь будет главный экран приложения',
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: 20),
            
            // Демо-кнопки для навигации
            _buildNavigationButtons(context),
            
            const SizedBox(height: 40),
            
            // Кнопка выхода
            CustomButton(
              text: 'Выйти из аккаунта',
              onPressed: () => _showLogoutDialog(context, ref),
              icon: Icons.logout,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNavigationButtons(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Демо навигации:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CustomButton(
              text: 'Профиль',
              onPressed: () => context.push(RouteNames.profile),
              isOutlined: true,
            ),
            CustomButton(
              text: 'Группы',
              onPressed: () => context.push(RouteNames.groups),
              isOutlined: true,
            ),
            CustomButton(
              text: 'Мои списки',
              onPressed: () => context.push(RouteNames.myLists),
              isOutlined: true,
            ),
            CustomButton(
              text: 'Поиск людей',
              onPressed: () => context.push(RouteNames.searchPeople),
              isOutlined: true,
            ),
          ],
        ),
      ],
    );
  }
  
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Закрываем диалог
              
              // Вызываем logout
              await ref.read(authControllerProvider).logout();
              
              // Перенаправляем на экран входа
              if (context.mounted) {
                context.go(RouteNames.login);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Вы вышли из аккаунта'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text(
              'Выйти',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}