import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _selectedFriendIds = Set<int>.from(ref.read(selectedFriendsProvider));
  }

  Future<void> _loadFriends() async {
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
      appBar: AppBar(
        title: const Text('Выбрать друзей'),
        actions: [
          TextButton(
            onPressed: _confirmSelection,
            child: Text(
              'Готово (${_selectedFriendIds.length})',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Поле поиска
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск друзей...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _filterFriends(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: _filterFriends,
            ),
          ),
          
          // Список друзей
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'У вас пока нет друзей'
                                  : 'Друзья не найдены',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredFriends.length,
                        itemBuilder: (context, index) {
                          final friend = _filteredFriends[index];
                          final isSelected = _selectedFriendIds.contains(friend.id);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  friend.username[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(
                                friend.username,
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                friend.email,
                                style: AppTextStyles.bodySmall,
                              ),
                              trailing: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                color: isSelected ? Colors.green : Colors.grey,
                                size: 28,
                              ),
                              onTap: () => _toggleSelection(friend),
                            ),
                          );
                        },
                      ),
          ),
          
          // Кнопка подтверждения (фиксированная внизу)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _confirmSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('Добавить (${_selectedFriendIds.length})'),
            ),
          ),
        ],
      ),
    );
  }
}