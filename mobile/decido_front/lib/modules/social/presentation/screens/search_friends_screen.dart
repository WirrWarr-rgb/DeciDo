import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../repository/friends_repository.dart';
import '../../models/user_search_model.dart';

class SearchFriendsScreen extends ConsumerStatefulWidget {
  const SearchFriendsScreen({super.key});

  @override
  ConsumerState<SearchFriendsScreen> createState() => _SearchFriendsScreenState();
}

class _SearchFriendsScreenState extends ConsumerState<SearchFriendsScreen> {
  final FriendsRepository _repository = FriendsRepository();
  final TextEditingController _searchController = TextEditingController();
  List<UserSearchModel> _results = [];
  Set<int> _sentRequests = {};
  Set<int> _incomingSenderIds = {};
  Set<int> _friendIds = {};
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();  // Вместо _loadSentRequests()
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadSentRequests(),
      _loadFriendIds(),
      _loadIncomingSenderIds(),  
    ]);
  }

  Future<void> _loadFriendIds() async {
    try {
      final friendIds = await _repository.getFriendIds();
      setState(() {
        _friendIds = friendIds;
      });
    } catch (e) {
      // Игнорируем ошибку
    }
  }

  Future<void> _loadSentRequests() async {
    try {
      final outgoing = await _repository.getOutgoingRequests();
      setState(() {
        _sentRequests = outgoing.map((r) => r.friendId).toSet();
      });
    } catch (e) {
      // Игнорируем ошибку
    }
  }

  Future<void> _loadIncomingSenderIds() async {
    try {
      final senderIds = await _repository.getIncomingRequestSenderIds();
      setState(() {
        _incomingSenderIds = senderIds;
      });
    } catch (e) {
      // Игнорируем ошибку
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final results = await _repository.searchUsers(query);
      final enrichedResults = results.map((user) {
        if (_friendIds.contains(user.id)) {
          return user.copyWith(isFriend: true);
        }
        if (_incomingSenderIds.contains(user.id)) {
          return user.copyWith(requestSent: true, isIncomingRequest: true);  // Добавляем флаг
        }
        return user;
      }).toList();
      setState(() {
        _results = enrichedResults;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendRequest(UserSearchModel user) async {
    setState(() {
      _results = _results.map((u) {
        if (u.id == user.id) {
          return u.copyWith(requestSent: true);
        }
        return u;
      }).toList();
      _sentRequests.add(user.id);
    });

    try {
      await _repository.sendFriendRequest(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Заявка отправлена ${user.username}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _results = _results.map((u) {
          if (u.id == user.id) {
            return u.copyWith(requestSent: false);
          }
          return u;
        }).toList();
        _sentRequests.remove(user.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск друзей'),
      ),
      body: Column(
        children: [
          // Поле поиска
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Введите имя пользователя...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (value) {
                _search(value);
              },
            ),
          ),
          
          // Результаты поиска
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    // Показываем индикатор загрузки
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Показываем ошибку
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
              onPressed: () => _search(_searchController.text),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    // Показываем сообщение "ничего не найдено"
    if (_isSearching && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Пользователи не найдены',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    // Показываем приглашение к поиску
    if (!_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Введите имя для поиска',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    // === ОСНОВНАЯ ЧАСТЬ: отображаем результаты поиска ===
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        
        // Проверяем статусы:
        // 1. isAlreadyFriend - пользователь уже в друзьях
        // 2. isRequestSent - заявка уже отправлена (проверяем оба источника)
        final isAlreadyFriend = user.isFriend;
        final isRequestSent = user.requestSent || _sentRequests.contains(user.id);
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                user.username[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(
              user.username,
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500, color: Colors.white),
            ),
            subtitle: Text(
              user.email,
              style: AppTextStyles.bodySmall,
            ),
            
            // === ЗДЕСЬ КЛЮЧЕВАЯ ЧАСТЬ: меняем вид кнопки в зависимости от статуса ===
            trailing: isAlreadyFriend
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Друг',
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.green.shade700),
                    ),
                  )
                : user.isIncomingRequest  // Проверяем, что пользователь отправил запрос нам
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Уже отправил запрос вам',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.orange.shade700),
                        ),
                      )
                    : isRequestSent
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Заявка отправлена',
                              style: AppTextStyles.bodySmall.copyWith(color: Colors.grey.shade700),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: () => _sendRequest(user),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Добавить'),
                          ),
          ),
        );
      },
    );
  }
}