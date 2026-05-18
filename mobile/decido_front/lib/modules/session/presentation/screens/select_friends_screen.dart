import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
    return CustomScaffold(
      title: "Выбрать друзей",
      showBackButton: true,
      body: Container(
        width: 412,
        height: 892,
        decoration: ShapeDecoration(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Stack(
          children: [
            
            // Поле поиска
            Positioned(
              left: 41,
              top: 107,
              child: Container(
                width: 330,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
                decoration: ShapeDecoration(
                  color: AppColors.inputBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.search, color: AppColors.darkBackground, size: 20),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: AppTextStyles.bodyGeneral,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Поиск друзей...',
                          hintStyle: TextStyle(
                            color: AppColors.inputText,
                            fontSize: 16,
                            fontFamily: 'Instrument Sans',
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 0),
                          isDense: true,
                        ),
                        onChanged: _filterFriends,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.darkBackground, size: 20),
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
                width: 330,
                height: 620,
                child: _buildBody(),
              ),
            ),
            
            // Кнопка "Готово" по центру внизу
            Positioned(
              left: 0,
              right: 0,
              bottom: 50,
              child: Center(
                child: GestureDetector(
                  onTap: _confirmSelection,
                  child: Container(
                    width: 130,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Готово (${_selectedFriendIds.length})',
                        style: AppTextStyles.buttonBig,
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
                        style: AppTextStyles.bodyGeneral.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: Text(
                        friend.email,
                        style: AppTextStyles.bodyGeneral.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Кнопка выбора (крестик удаления или галочка для выбранных)
              Positioned(
                right: 0,
                top: 15,
                child: GestureDetector(
                  onTap: () => _toggleSelection(friend),
                  child: Container(
                    width: 40,
                    height: 40,
                    child: isSelected
                        ? SvgPicture.asset(
                            'assets/icons/delete_cross_icon.svg',
                            width: 40,
                            height: 40,
                            colorFilter: const ColorFilter.mode(
                              AppColors.secondary,
                              BlendMode.srcIn,
                            ),
                          )
                        : SvgPicture.asset(
                            'assets/icons/add_plus_green_icon.svg',
                            width: 40,
                            height: 40,
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