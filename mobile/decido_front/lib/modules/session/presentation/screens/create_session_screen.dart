import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../list/repository/list_repository.dart';
import '../../../list/models/list_model.dart';
import '../../../list/models/list_item_model.dart';
import '../../../social/repository/friends_repository.dart';
import '../../../social/models/friend_model.dart';
import '../../providers/session_providers.dart';
import '../../repository/i_session_repository.dart';
import '../../models/session_models.dart';
import '../../services/websocket_service.dart';
import 'select_friends_screen.dart';
import 'select_list_bottom_sheet.dart';
import 'session_item_edit_bottom_sheet.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  late ISessionRepository _repository;
  final ListRepository _listRepository = ListRepository();
  final FriendsRepository _friendsRepository = FriendsRepository();
  
  List<FriendModel> _selectedFriendsList = [];
  Map<int, String> _friendNames = {};
  SessionListModel? _selectedList;
  String? _selectedListOriginalId;
  List<SessionListItemModel> _selectedListItems = []; // Используем SessionListItemModel
  bool _isLoadingLists = true;
  bool _isLoadingFriends = true;
  bool _showListDropdown = false;
  int? _editingItemIndex;
  final double shiftDistance = 60;
  final ScrollController _friendsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _repository = ref.read(sessionRepositoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedFriendsProvider.notifier).state = [];
      ref.read(selectedListIdProvider.notifier).state = null;
      ref.read(selectedListNameProvider.notifier).state = null;
    });
    _loadData();
  }

  @override
  void dispose() {
    _friendsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final friends = await _friendsRepository.getFriends();
      final names = <int, String>{};
      for (var friend in friends) {
        names[friend.id] = friend.username;
      }
      setState(() {
        _friendNames = names;
        _isLoadingFriends = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingFriends = false;
      });
    }
  }

  String _getFriendName(int id) {
    return _friendNames[id] ?? 'Друг #$id';
  }

  void _selectList(SessionListModel list, String originalId) {
    final originalItems = _listRepository.getItemsByListId(originalId);
    
    final copiedItems = originalItems.map((item) => SessionListItemModel(
      id: list.id.hashCode,
      name: item.name,
      description: item.description,
      imageUrl: item.imageUrl,
      orderIndex: item.orderIndex,
    )).toList();
    
    final copiedList = SessionListModel(
      id: originalId,
      name: list.name,
      isActive: list.isActive,
      items: copiedItems,
      createdAt: list.createdAt,
    );
    
    setState(() {
      _selectedList = copiedList;
      _selectedListOriginalId = originalId;
      _selectedListItems = copiedItems;
      _showListDropdown = false;
    });
    ref.read(selectedListNameProvider.notifier).state = copiedList.name;
  }

  void _toggleListDropdown() {
    setState(() {
      _showListDropdown = !_showListDropdown;
    });
  }

  void _removeFriend(int friendId) {
    final friendIds = ref.read(selectedFriendsProvider);
    final newList = List<int>.from(friendIds)..remove(friendId);
    ref.read(selectedFriendsProvider.notifier).state = newList;
    
    setState(() {
      _selectedFriendsList = _selectedFriendsList.where((f) => f.id != friendId).toList();
    });
  }

  void _scrollFriendsLeft() {
    if (_friendsScrollController.hasClients) {
      final newOffset = _friendsScrollController.offset - 320;
      _friendsScrollController.animateTo(
        newOffset.clamp(0.0, _friendsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollFriendsRight() {
    if (_friendsScrollController.hasClients) {
      final newOffset = _friendsScrollController.offset + 320;
      _friendsScrollController.animateTo(
        newOffset.clamp(0.0, _friendsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _addNewItem() {
    if (_selectedListItems.length >= 20) {
      _showError('Достигнут лимит элементов (20)');
      return;
    }

    // Создаем новый элемент с String id
    final newItem = SessionListItemModel(
      id: DateTime.now().millisecondsSinceEpoch,  // String
      name: 'Новый элемент',
      description: null,
      imageUrl: null,
      orderIndex: _selectedListItems.length,
    );
    
    setState(() {
      _selectedListItems.add(newItem);
      _editingItemIndex = _selectedListItems.length - 1;
    });
    
    _showItemEditSheet(newItem);
  }

  void _deleteItem(int index) {
    setState(() {
      _selectedListItems.removeAt(index);
      _editingItemIndex = null;
    });
  }

  void _showItemEditSheet(SessionListItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SessionItemEditBottomSheet(
        item: item,
        onSave: (name, description, imageUrl) {
          setState(() {
            final index = _selectedListItems.indexWhere((i) => i.id == item.id);
            if (index != -1) {
              // Обновляем локальную копию элемента
              _selectedListItems[index] = item.copyWith(
                name: name,
                description: description,
                imageUrl: imageUrl,
              );
            }
            _editingItemIndex = null;
          });
          Navigator.pop(context);
        },
        onClose: () {
          setState(() {
            _editingItemIndex = null;
          });
          Navigator.pop(context);
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _editingItemIndex = null;
        });
      }
    });
  }

  double _getItemOffset(int index, int? editingIndex) {
    if (editingIndex == null) return 0;
    final diff = (index - editingIndex).abs();
    if (diff == 0) return -shiftDistance;
    if (diff == 1) return -(shiftDistance * 0.5);
    if (diff == 2) return -(shiftDistance * 0.25);
    return 0;
  }

  Future<void> _createLobby() async {
    final friendIds = ref.read(selectedFriendsProvider);
    
    if (friendIds.isEmpty) {
      _showError('Выберите хотя бы одного друга');
      return;
    }
    
    if (_selectedList == null) {
      _showError('Выберите список для голосования');
      return;
    }
    
    if (_selectedListItems.isEmpty) {
      _showError('В выбранном списке нет элементов');
      return;
    }
    
    ref.read(sessionLoadingProvider.notifier).state = true;
    
    try {
      // Отправляем на бэкенд данные из локальной копии
      final request = CreateLobbyRequest(
        friendIds: friendIds,
        listData: ListData(
          name: _selectedList!.name,
          items: _selectedListItems.asMap().entries.map((entry) => ListDataItem(
            name: entry.value.name,
            description: entry.value.description,
            imageUrl: entry.value.imageUrl,
            orderIndex: entry.key,
          )).toList(),
        ),
        mode: SessionMode.ranking,
        votingDuration: 120,
      );
      
      final session = await _repository.createLobby(request);
      
      await WebSocketService.instance.connect(session.id);
      
      if (mounted) {
        context.pushReplacement('/session/${session.id}');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      ref.read(sessionLoadingProvider.notifier).state = false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(sessionLoadingProvider);
    final friendIds = ref.read(selectedFriendsProvider);
    final hasFriends = friendIds.isNotEmpty;
    final hasList = _selectedList != null;
    
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: 412,
            height: 892,
            decoration: ShapeDecoration(
              color: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: isLoading
                ? const LoadingWidget()
                : Stack(
                    children: [
                      // Кнопка назад
                      Positioned(
                        left: 10,
                        top: 52,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                          onPressed: () => context.pop(),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      
                      // Заголовок
                      Positioned(
                        left: 60,
                        top: 52,
                        child: Text(
                          'Подготовка',
                          style: AppTextStyles.headlineMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            height: 1.67,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      
                      // Выбор друзей
                      if (!hasFriends)
                        Positioned(
                          left: 78,
                          top: 141,
                          child: GestureDetector(
                            onTap: () async {
                              final result = await context.push<List<int>>('/select-friends');
                              if (result != null && mounted) {
                                ref.read(selectedFriendsProvider.notifier).state = result;
                                final friends = await _friendsRepository.getFriends();
                                setState(() {
                                  _selectedFriendsList = friends.where((f) => result.contains(f.id)).toList();
                                });
                              }
                            },
                            child: Container(
                              width: 257,
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                              decoration: ShapeDecoration(
                                color: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Выберите друзей',
                                    style: TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 16,
                                      fontFamily: 'Instrument Sans',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: AppColors.textLight, size: 24),
                                ],
                              ),
                            ),
                          ),
                        ),
                      
                      // Горизонтальный список выбранных друзей
                      if (hasFriends)
                        Positioned(
                          left: 41,
                          top: 100,
                          child: SizedBox(
                            width: 330,
                            height: 120,
                            child: _buildSelectedFriendsList(),
                          ),
                        ),
                      
                      // Стрелка влево для друзей
                      if (hasFriends && friendIds.length > 4)
                        Positioned(
                          left: 10,
                          top: 145,
                          child: GestureDetector(
                            onTap: _scrollFriendsLeft,
                            child: Container(
                              width: 31,
                              height: 31,
                              decoration: BoxDecoration(
                                color: AppColors.inputBackground.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 20),
                            ),
                          ),
                        ),
                      
                      // Стрелка вправо для друзей
                      if (hasFriends && friendIds.length > 4)
                        Positioned(
                          left: 371,
                          top: 145,
                          child: GestureDetector(
                            onTap: _scrollFriendsRight,
                            child: Container(
                              width: 31,
                              height: 31,
                              decoration: BoxDecoration(
                                color: AppColors.inputBackground.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chevron_right, color: AppColors.textPrimary, size: 20),
                            ),
                          ),
                        ),
                      
                      // Счетчик элементов списка
                      Positioned(
                        left: 102,
                        top: hasFriends ? 248 : 200,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Элементов в списке ',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 20,
                                  fontFamily: 'Instrument Sans',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text: '${_selectedListItems.length}/20',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 20,
                                  fontFamily: 'Instrument Sans',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Кнопка выбора списка
                      Positioned(
                        left: 78,
                        top: hasFriends ? 281 : 233,
                        child: GestureDetector(
                          onTap: _toggleListDropdown,
                          child: Container(
                            width: 257,
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                            decoration: ShapeDecoration(
                              color: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedList?.name ?? 'Выберите список',
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 16,
                                    fontFamily: 'Instrument Sans',
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Icon(
                                  _showListDropdown ? Icons.chevron_left : Icons.chevron_right,
                                  color: AppColors.textLight,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Кнопка добавления элемента
                      if (hasList)
                        Positioned(
                          left: 25,
                          top: hasFriends ? 365 : 317,
                          child: GestureDetector(
                            onTap: _addNewItem,
                            child: Container(
                              width: 368,
                              height: 48,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                              decoration: ShapeDecoration(
                                color: AppColors.secondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add, color: AppColors.textLight, size: 25),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Добавить новый элемент',
                                    style: TextStyle(
                                      color: AppColors.textLight,
                                      fontSize: 18,
                                      fontFamily: 'Instrument Sans',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      
                      // Список элементов
                      if (hasList)
                        Positioned(
                          left: 25,
                          top: hasFriends ? 430 : 380,
                          child: Container(
                            width: 512,
                            height: 320,
                            child: _selectedListItems.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.format_list_bulleted, size: 64, color: Colors.grey),
                                        const SizedBox(height: 16),
                                        const Text('Список пуст'),
                                        const SizedBox(height: 16),
                                        ElevatedButton(
                                          onPressed: _addNewItem,
                                          child: const Text('Добавить первый элемент'),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _selectedListItems.length,
                                    itemBuilder: (context, index) {
                                      final item = _selectedListItems[index];
                                      final offset = _getItemOffset(index, _editingItemIndex);
                                      final isEven = index % 2 == 0;
                                      
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeInOut,
                                        transform: Matrix4.translationValues(offset, 0, 0),
                                        child: Container(
                                          height: 48,
                                          margin: EdgeInsets.zero,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Иконка удаления
                                              SizedBox(
                                                width: 35,
                                                child: GestureDetector(
                                                  onTap: () => _deleteItem(index),
                                                  child: SvgPicture.asset(
                                                    'assets/icons/delete_bin_icon.svg',
                                                    colorFilter: isEven 
                                                        ? const ColorFilter.mode(
                                                            AppColors.inputBackground,
                                                            BlendMode.srcIn,
                                                          )
                                                        : const ColorFilter.mode(
                                                            AppColors.primary,
                                                            BlendMode.srcIn,
                                                          ),
                                                    width: 35,
                                                    height: 35,
                                                  ),
                                                ),
                                              ),
                                              
                                              const SizedBox(width: 21),
                                              
                                              // Задний план
                                              Expanded(
                                                child: GestureDetector(
                                                  //onTap: () => _editItem(index),
                                                  child: Container(
                                                    height: 48,
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                                    decoration: ShapeDecoration(
                                                      color: isEven ? AppColors.inputBackground : AppColors.primary,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      item.name,
                                                      style: TextStyle(
                                                        color: isEven ? AppColors.textPrimary : AppColors.textLight,
                                                        fontSize: 20,
                                                        fontFamily: 'Instrument Sans',
                                                        fontWeight: FontWeight.w500,
                                                        height: 1.10,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      
                      // Кнопка "Открыть лобби"
                      Positioned(
                        left: 141,
                        bottom: 30,
                        child: CustomButton(
                          text: 'ОТКРЫТЬ ЛОББИ',
                          onPressed: _createLobby,
                          width: 130,
                          fontSize: 16,
                          backgroundColor: AppColors.secondary,
                          textColor: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
          ),
          
          // Выпадающий список поверх всего
          if (_showListDropdown)
            Positioned(
              left: 78,
              top: (hasFriends ? 281 : 233) + 45,
              child: SelectListBottomSheet(
                onSelectList: _selectList,
                onClose: () => setState(() => _showListDropdown = false),
              ),
            ),
          
          // Затемнение при открытом bottom sheet редактирования
          if (_editingItemIndex != null)
            Container(
              width: 412,
              height: 892,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.tertiary.withOpacity(0.7),
                    AppColors.secondary.withOpacity(0.7),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedFriendsList() {
    final friendIds = ref.read(selectedFriendsProvider);
    
    return SingleChildScrollView(
      controller: _friendsScrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...friendIds.map((id) {
            final friend = _selectedFriendsList.firstWhere(
              (f) => f.id == id,
              orElse: () => FriendModel(
                id: id,
                username: _getFriendName(id),
                email: '',
                isActive: true,
              ),
            );
            
            return Container(
              width: 65,
              margin: const EdgeInsets.only(right: 19),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 65,
                    child: Text(
                      friend.username.length > 7 ? '${friend.username.substring(0, 6)}.' : friend.username,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontFamily: 'Instrument Sans',
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: AppColors.tertiary,
                          shape: BoxShape.circle,
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
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _removeFriend(id),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '...',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
          // Кнопка добавления друзей
          Container(
            width: 65,
            margin: const EdgeInsets.only(right: 19),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () async {
                    final result = await context.push<List<int>>('/select-friends');
                    if (result != null && mounted) {
                      final newIds = [...friendIds, ...result.where((id) => !friendIds.contains(id))];
                      ref.read(selectedFriendsProvider.notifier).state = newIds;
                      final friends = await _friendsRepository.getFriends();
                      setState(() {
                        _selectedFriendsList = friends.where((f) => newIds.contains(f.id)).toList();
                      });
                    }
                  },
                  child: Container(
                    width: 65,
                    height: 65,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.add, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}