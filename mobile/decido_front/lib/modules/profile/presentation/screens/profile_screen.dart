

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/providers/auth_state_provider.dart';
import '../../../shared/widgets/custom_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                user?.username.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              user?.username ?? 'Гость',
              style: AppTextStyles.headline2,
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? 'Нет email',
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: 48),
            CustomButton(
              text: 'Редактировать профиль',
              onPressed: () {
                // TODO: Переход на редактирование
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Редактирование профиля в разработке'),
                  ),
                );
              },
              isOutlined: true,
            ),
          ],
        ),
      ),
    );
  }
}