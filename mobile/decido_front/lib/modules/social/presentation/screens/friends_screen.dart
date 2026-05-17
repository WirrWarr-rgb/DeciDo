import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_drawer.dart';
import '../../../shared/widgets/custom_scaffold.dart';
import '../../repository/friends_repository.dart';
import '../../models/friend_model.dart';
import 'friend_requests_screen.dart';
import 'search_friends_screen.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final FriendsRepository _repository = FriendsRepository();
  List<FriendModel> _friends = [];
  bool _isLoading = true;
  bool _hasPendingRequests = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _checkPendingRequests();
  }

  Future<void> _checkPendingRequests() async {
    try {
      final requests = await _repository.getIncomingRequests();
      setState(() {
        _hasPendingRequests = requests.isNotEmpty;
      });
    } catch (e) {
      print('Error checking pending requests: $e');
    }
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final friends = await _repository.getFriends();
      friends.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
      setState(() {
        _friends = friends;
        _isLoading = false;
      });
      await _checkPendingRequests();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFriend(FriendModel friend) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить друга'),
        content: Text('Вы уверены, что хотите удалить ${friend.username} из друзей?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _repository.removeFriend(friend.id);
        await _loadFriends();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Друг удален'), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'Друзья',
      menuIconColor: AppColors.textPrimary,
      actions: [
        // Кнопка "Заявки" - исправлено: без Positioned
        GestureDetector(
          onTap: () {
            context.push('/friend-requests').then((_) {
              _loadFriends();
              _checkPendingRequests();
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Заявки',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontFamily: 'Instrument Sans',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 5),
              if (_hasPendingRequests) ...[
                SvgPicture.asset(
                  'assets/icons/notif_dot_icon.svg',
                  width: 10,
                  height: 10,
                ),
                const SizedBox(width: 5),
              ],
              SvgPicture.asset(
                'assets/icons/navigation_arrow_right.svg',
                width: 20,
                height: 20,
              ),
            ],
          ),
        ),
      ],
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
            
            // Список друзей
            Positioned(
              left: 41,
              top: 107,
              child: Container(
                width: 355,
                height: 680,
                child: _buildBody(),
              ),
            ),
            
            // Кнопка добавления друга
            Positioned(
              left: 176,
              top: 775,
              child: GestureDetector(
                onTap: () {
                  context.push('/search-friends').then((_) {
                    _loadFriends();
                    _checkPendingRequests();
                  });
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: ShapeDecoration(
                    color: AppColors.secondary,
                    shape: const OvalBorder(),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: SvgPicture.asset(
                        'assets/icons/add_plus_white_icon.svg',
                        width: 46,
                        height: 46,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFriends,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('У вас пока нет друзей', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.push('/search-friends').then((_) {
                  _loadFriends();
                  _checkPendingRequests();
                });
              },
              child: const Text('Найти друзей'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: ShapeDecoration(
                  color: AppColors.tertiary,
                  shape: const OvalBorder(),
                ),
                child: Center(
                  child: Text(
                    friend.username[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 80,
                top: 5,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 200,
                      child: Text(
                        friend.username,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontFamily: 'Instrument Sans',
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: Text(
                        friend.email,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontFamily: 'Instrument Sans',
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 0,
                top: 15,
                child: GestureDetector(
                  onTap: () => _removeFriend(friend),
                  child: Container(
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.person_remove,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}