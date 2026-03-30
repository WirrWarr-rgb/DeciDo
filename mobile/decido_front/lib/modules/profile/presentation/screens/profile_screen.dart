

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/providers/auth_state_provider.dart';
import '../../../auth/providers/auth_controller_provider.dart';
import '../../../shared/widgets/custom_button.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _darkThemeEnabled = false;
  String _selectedLanguage = 'Русский';

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход из аккаунта'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(authControllerProvider).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция в разработке'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider);

    return Scaffold(
      body: Container(
        width: 412,
        height: 895,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Stack(
          children: [
            // Фоновый SVG элемент (верхний декоративный элемент)

            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: SvgPicture.asset(
                  'assets/icons/profile_header_bg.svg',
                  width: 426.23,
                  height: 295.11,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            // Аватар пользователя
            Positioned(
              left: 126,
              top: 163,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.tertiary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 5,
                    color: AppColors.secondary,
                  ),
                ),
                child: Center(
                  child: Text(
                    user?.username.substring(0, 1).toUpperCase() ?? '?',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            
            // Имя пользователя и @username
            Positioned(
              left: 119,
              top: 89,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 174,
                    height: 32,
                    child: Text(
                      user?.username ?? 'User',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 36,
                        height: 1.11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 174,
                    child: Text(
                      '@${user?.username ?? 'username'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 24,
                        fontFamily: 'Instrument Sans',
                        fontWeight: FontWeight.w700,
                        height: 1.67,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Группа "Аккаунт"
              Positioned(
                left: 41,
                top: 348,
                child: Container(
                  width: 330,
                  height: 177, // Фиксированная высота
                  padding: const EdgeInsets.only(top: 6, left: 24, right: 28, bottom: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      width: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок "Аккаунт"
                      SizedBox(
                        width: 282,
                        height: 40, // Фиксированная высота заголовка
                        child: Text(
                          'Аккаунт',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            height: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      
                      // Пункты меню без дополнительных отступов
                      _buildMenuItem(
                        iconPath: 'assets/icons/profile_name_change.svg',
                        label: 'Изменить имя пользователя',
                        onTap: _showComingSoon,
                      ),
                      
                      _buildMenuItem(
                        iconPath: 'assets/icons/profile_name_change.svg',
                        label: 'Изменить аватар',
                        onTap: _showComingSoon,
                      ),
                      
                      _buildMenuItem(
                        iconPath: 'assets/icons/profile_name_change.svg',
                        label: 'Изменить пароль',
                        onTap: _showComingSoon,
                      ),
                    ],
                  ),
                ),
              ),

              // Группа "Предпочтения"
              Positioned(
                left: 41,
                top: 555,
                child: Container(
                  width: 330,
                  height: 177, // Фиксированная высота
                  padding: const EdgeInsets.only(top: 6, left: 24, right: 24, bottom: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      width: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Заголовок "Предпочтения"
                      SizedBox(
                        width: 282,
                        height: 40, // Фиксированная высота заголовка
                        child: Text(
                          'Предпочтения',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            height: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      
                      // Пункты меню без дополнительных отступов
                      _buildSwitchMenuItem(
                        iconPath: 'assets/icons/profile_name_change.svg',
                        label: 'Уведомления',
                        value: _notificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                          _showComingSoon();
                        },
                      ),
                      
                      _buildDropdownMenuItem(
                        iconPath: 'assets/icons/profile_name_change.svg',
                        label: 'Язык',
                        value: _selectedLanguage,
                        onTap: _showComingSoon,
                      ),
                      
                      _buildSwitchMenuItem(
                        iconPath: 'assets/icons/profile_name_change.svg',
                        label: 'Тема',
                        value: _darkThemeEnabled,
                        onChanged: (value) {
                          setState(() {
                            _darkThemeEnabled = value;
                          });
                          _showComingSoon();
                        },
                      ),
                    ],
                  ),
                ),
            ),
            
            // Кнопка выхода
            Positioned(
              left: 41,
              top: 780,
              child: CustomButton(
                text: 'Выйти из аккаунта',
                onPressed: _handleLogout,
                width: 330,
                fontSize: 16,
                backgroundColor: Colors.red.shade400,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildMenuItem({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 40, // Фиксированная высота пункта
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                AppColors.primary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontFamily: 'Instrument Sans',
                fontWeight: FontWeight.w400,
                height: 1.2, // Уменьшил межстрочный интервал
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchMenuItem({
    required String iconPath,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      height: 40, // Фиксированная высота пункта
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppColors.primary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontFamily: 'Instrument Sans',
                  fontWeight: FontWeight.w400,
                  height: 1.2, // Уменьшил межстрочный интервал
                ),
              ),
            ],
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              inactiveThumbColor: AppColors.inputBackground,
              inactiveTrackColor: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownMenuItem({
    required String iconPath,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 40, // Фиксированная высота пункта
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  iconPath,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontFamily: 'Instrument Sans',
                    fontWeight: FontWeight.w400,
                    height: 1.2, // Уменьшил межстрочный интервал
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontFamily: 'Instrument Sans',
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}