import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../modules/social/repository/friends_repository.dart';
import '../../../modules/social/models/friend_request_model.dart';

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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 56,
      backgroundColor: AppColors.primary.withOpacity(0.95),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 52),
            
            // 1 - Закрыть
            _DrawerItem(
              icon: Icons.menu,
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 24),
            
            // 2 - Домашняя страничка
            _DrawerItem(
              icon: Icons.home,
              onTap: () {
                Navigator.pop(context);
                context.go('/home');
              },
            ),
            const SizedBox(height: 24),
            
            // 3 - Экран списков
            _DrawerItem(
              icon: Icons.list_alt,
              onTap: () {
                Navigator.pop(context);
                context.go('/my-lists');
              },
            ),
            const SizedBox(height: 24),
            
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
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 5 - Экран профиля
            _DrawerItem(
              icon: Icons.person,
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
          ],
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
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}