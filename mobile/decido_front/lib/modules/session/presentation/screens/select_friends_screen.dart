import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_scaffold.dart';
import '../../../social/repository/friends_repository.dart';
import '../../../social/models/friend_model.dart';
import '../../providers/session_providers.dart';

class SelectFriendsScreen extends ConsumerStatefulWidget {
  const SelectFriendsScreen({super.key});

  @override
  ConsumerState<SelectFriendsScreen> createState() => _SelectFriendsScreenState();
}

class _SelectFriendsScreenState extends ConsumerState<SelectFriendsScreen> {
  final FriendsRepository _friendsRepository = FriendsRepository();
  List<FriendModel> _friends = [];
  List<FriendModel> _filteredFriends = [];
  bool _isLoading = true;
  String _searchQuery = '';
  Set<int> _selectedFriendIds = {};
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _selectedFriendIds = Set<int>.from(ref.read(selectedFriendsProvider));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final friends = await _friendsRepository.getFriends();
      friends.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
      setState(() {
        _friends = friends;
        _filteredFriends = friends;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки друзей: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _filterFriends(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((friend) =>
          friend.username.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  void _toggleSelection(FriendModel friend) {
    setState(() {
      if (_selectedFriendIds.contains(friend.id)) {
        _selectedFriendIds.remove(friend.id);
      } else {
        _selectedFriendIds.add(friend.id);
      }
    });
  }

  void _confirmSelection() {
    ref.read(selectedFriendsProvider.notifier).state = _selectedFriendIds.toList();
    Navigator.pop(context, _selectedFriendIds.toList());
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
            // Кнопка назад
            Positioned(
              left: 10,
              top: 52,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
            ),
            
            // Кнопка меню (заглушка)
            Positioned(
              left: 50,
              top: 52,
              child: IconButton(
                icon: const Icon(Icons.menu, color: AppColors.textPrimary),
                onPressed: () {},
                padding: EdgeInsets.zero,
              ),
            ),
            
            // Заголовок
            Positioned(
              left: 82,
              top: 52,
              child: Text(
                'Выбрать друзей',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  height: 1.67,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            
            // Кнопка "Готово" справа
            Positioned(
              right: 20,
              top: 52,
              child: GestureDetector(
                onTap: _confirmSelection,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Готово (${_selectedFriendIds.length})',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontFamily: 'Instrument Sans',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            
            // Поле поиска
            Positioned(
              left: 41,
              top: 107,
              child: Container(
                width: 330,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                decoration: ShapeDecoration(
                  color: AppColors.inputBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.inputText, size: 20),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: AppColors.inputText,
                          fontSize: 16,
                          fontFamily: 'Instrument Sans',
                          fontWeight: FontWeight.w400,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Поиск друзей...',
                          hintStyle: TextStyle(
                            color: AppColors.inputText.withOpacity(0.7),
                            fontSize: 16,
                            fontFamily: 'Instrument Sans',
                            fontWeight: FontWeight.w400,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: _filterFriends,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.inputText, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _filterFriends('');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
            
            // Список друзей
            Positioned(
              left: 41,
              top: 165,
              child: Container(
                width: 355,
                height: 620,
                child: _buildBody(),
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

    if (_filteredFriends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'У вас пока нет друзей'
                  : 'Друзья не найдены',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredFriends.length,
      itemBuilder: (context, index) {
        final friend = _filteredFriends[index];
        final isSelected = _selectedFriendIds.contains(friend.id);
        
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
              
              // Кнопка выбора (галочка или плюс)
              Positioned(
                right: 0,
                top: 15,
                child: GestureDetector(
                  onTap: () => _toggleSelection(friend),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isSelected ? null : Border.all(color: AppColors.textSecondary, width: 2),
                    ),
                    child: Center(
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : const Icon(Icons.add, color: AppColors.textSecondary, size: 24),
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