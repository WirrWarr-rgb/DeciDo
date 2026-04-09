import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    _loadData();
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
          return user.copyWith(requestSent: true, isIncomingRequest: true);
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
            // Кнопка меню (три полоски) - заглушка
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
            
            // Заголовок "Поиск"
            Positioned(
              left: 82,
              top: 52,
              child: Text(
                'Поиск',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  height: 1.67,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            
            // Поле поиска
            Positioned(
              left: 41,
              top: 98,
              child: Container(
                width: 330,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0), // Убрал вертикальный padding
                decoration: ShapeDecoration(
                  color: AppColors.inputBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center, // Выравнивание по центру
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.darkBackground, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          _search('');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textAlignVertical: TextAlignVertical.center, // Вертикальное выравнивание текста
                        style: const TextStyle(
                          color: AppColors.inputText,
                          fontSize: 20,
                          fontFamily: 'Instrument Sans',
                          fontWeight: FontWeight.w400,
                          height: 1.0, // Фиксированная высота строки
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '@username',
                          hintStyle: TextStyle(
                            color: AppColors.inputText,
                            fontSize: 20,
                            fontFamily: 'Instrument Sans',
                            fontWeight: FontWeight.w400,
                            height: 1.0,
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 0), // Убираем вертикальные отступы
                          isDense: true, // Уменьшает общую высоту
                        ),
                        onChanged: _search,
                      ),
                    ),
                    // Иконка поиска (место для SVG)
                    Container(
                      width: 24,
                      height: 24,
                      child: const Icon(Icons.search, color: AppColors.darkBackground, size: 20),
                    ),
                  ],
                ),
              ),
            ),

            // Результаты поиска
            Positioned(
              left: 41,
              top: 157,
              child: Container(
                width: 355,
                height: 680,
                child: _buildResults(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
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
              onPressed: () => _search(_searchController.text),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

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

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        
        final isAlreadyFriend = user.isFriend;
        final isRequestSent = user.requestSent || _sentRequests.contains(user.id);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 15),
          child: Stack(
            children: [
              // Аватар пользователя
              Container(
                width: 65,
                height: 65,
                decoration: ShapeDecoration(
                  color: AppColors.tertiary,
                  shape: const OvalBorder(),
                ),
                child: Center(
                  child: Text(
                    user.username.isNotEmpty ? user.username[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              // Информация о пользователе
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
                        user.username,
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
                        user.email,
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
              
              // Кнопка действия
              Positioned(
                right: 0,
                top: 15,
                child: isAlreadyFriend
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
                    : user.isIncomingRequest
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Входящая заявка',
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
                              : Positioned(
                                  right: 46,
                                  top: 15,
                                  child: GestureDetector(
                                      onTap: () => _sendRequest(user),
                                      child: Container(
                                          child: SvgPicture.asset(
                                              'assets/icons/add_plus_green_icon.svg',
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.contain,
                                          ),
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