import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFriends();
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
    return Scaffold(
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
            // Заголовок "Друзья"
            Positioned(
              left: 82,
              top: 52,
              child: Text(
                'Друзья',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  height: 1.67,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            
            // Кнопка "Заявки" справа от заголовка
            Positioned(
              left: 267,
              top: 57,
              child: GestureDetector(
                onTap: () {
                  context.push('/friend-requests').then((_) => _loadFriends());
                },
                child: Container(
                  width: 112,
                  height: 32,
                  padding: const EdgeInsets.all(10),
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Заявки',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontFamily: 'Instrument Sans',
                          fontWeight: FontWeight.w700,
                          height: 1.38,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        width: 10,
                        height: 10,
                        //decoration: ShapeDecoration(
                        //  color: AppColors.primary,
                        //  shape: ShapeBorder.lerp(a, b, t),
                        //),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Кнопка меню (три полоски) - временно пустая заглушка
            Positioned(
              left: 10,
              top: 52,
              child: Container(
                width: 37,
                height: 37,
                child: IconButton(
                  icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                  onPressed: () {
                    // TODO: Открыть pop-up меню
                  },
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            
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
            
            // Кнопка добавления друга (круглая оранжевая)
            Positioned(
              left: 176,
              top: 775,
              child: GestureDetector(
                onTap: () {
                  context.push('/search-friends').then((_) => _loadFriends());
                },
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: ShapeDecoration(
                    color: AppColors.secondary,
                    shape: const OvalBorder(),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 30,
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
            Text(
              'У вас пока нет друзей',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.push('/search-friends').then((_) => _loadFriends());
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
              // Аватар друга
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
              // Информация о друге
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
                          height: 1.10,
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
                          height: 1.38,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Кнопка удаления
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