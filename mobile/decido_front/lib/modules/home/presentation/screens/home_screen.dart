import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../auth/providers/auth_controller_provider.dart';
import '../../../auth/providers/auth_state_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('DeciDo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Добро пожаловать, ${user?.username ?? 'Гость'}!',
              style: AppTextStyles.headlineLarge,
            ),
            const SizedBox(height: 24),
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