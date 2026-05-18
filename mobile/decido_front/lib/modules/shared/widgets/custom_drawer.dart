import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../modules/social/repository/friends_repository.dart';
import '../../../modules/social/models/friend_request_model.dart';
import '../../../modules/auth/providers/auth_controller_provider.dart';

class CustomDrawer extends ConsumerStatefulWidget {
  const CustomDrawer({super.key});

  @override
  ConsumerState<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends ConsumerState<CustomDrawer> {
  int _pendingRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingRequestsCount();
  }

  Future<void> _loadPendingRequestsCount() async {
    try {
      final repository = FriendsRepository();
      final requests = await repository.getIncomingRequests();
      final pending = requests.where((r) => r.status == FriendStatus.pending).length;
      setState(() {
        _pendingRequestsCount = pending;
      });
    } catch (e) {
      print('Error loading pending requests: $e');
    }
  }

  void _showLogoutDialog(BuildContext context) {
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
                Navigator.pop(context); // Закрываем диалог
                context.go('/login');
              }
            },
            child: const Text('Выйти', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 56,
      backgroundColor: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: 56,
            margin: const EdgeInsets.only(top: 32),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
            decoration: ShapeDecoration(
              color: AppColors.secondary,
              shape: RoundedRectangleBorder(
                side: const BorderSide(
                  width: 1,
                  color: AppColors.secondary,
                ),
                borderRadius: BorderRadius.circular(45),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1 - Кнопка закрытия (крестик вместо меню)
                _DrawerItem(
                  icon: Icons.close,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 13),
                
                // 2 - Домашняя страничка
                _DrawerItem(
                  icon: Icons.home,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/home');
                  },
                ),
                const SizedBox(height: 13),
                
                // 3 - Экран списков
                _DrawerItem(
                  icon: Icons.list_alt,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/my-lists');
                  },
                ),
                const SizedBox(height: 13),
                
                // 4 - Экран друзей с индикатором
                Stack(
                  children: [
                    _DrawerItem(
                      icon: Icons.people,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/friends');
                      },
                    ),
                    if (_pendingRequestsCount > 0)
                      Positioned(
                        top: 25,
                        right: 3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const ShapeDecoration(
                            color: AppColors.primary,
                            shape: OvalBorder(),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                
                // 5 - Экран профиля
                _DrawerItem(
                  icon: Icons.person,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/profile');
                  },
                ),
                const SizedBox(height: 13),
                
                // 6 - Кнопка выхода
                _DrawerItem(
                  icon: Icons.logout,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          color: AppColors.textLight,
          size: 24,
        ),
      ),
    );
  }
}