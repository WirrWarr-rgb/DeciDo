import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../social/repository/friends_repository.dart';
import '../../../social/models/friend_model.dart';
import '../../providers/session_providers.dart';
import '../../repository/i_session_repository.dart';
import '../../models/session_models.dart';
import '../../services/websocket_service.dart';
import 'select_friends_screen.dart';
import 'select_list_bottom_sheet.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  late ISessionRepository _repository;
  final FriendsRepository _friendsRepository = FriendsRepository();
  Map<int, String> _friendNames = {};

  @override
  void initState() {
    super.initState();
    _repository = ref.read(sessionRepositoryProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedFriendsProvider.notifier).state = [];
      ref.read(selectedListIdProvider.notifier).state = null;
      ref.read(selectedListNameProvider.notifier).state = null;
      _loadFriendNames();
    });
  }

  Future<void> _loadFriendNames() async {
    try {
      final friends = await _friendsRepository.getFriends();
      final names = <int, String>{};
      for (var friend in friends) {
        names[friend.id] = friend.username;
      }
      setState(() {
        _friendNames = names;
      });
    } catch (e) {
      print('Error loading friend names: $e');
    }
  }

  String _getFriendName(int id) {
    return _friendNames[id] ?? 'Друг #$id';
  }

  void _showSelectListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const SelectListBottomSheet(),
    );
  }

  Future<void> _createLobby() async {
    final friendIds = ref.read(selectedFriendsProvider);
    final listId = ref.read(selectedListIdProvider);
    
    if (friendIds.isEmpty) {
      _showError('Выберите хотя бы одного друга');
      return;
    }
    
    if (listId == null) {
      _showError('Выберите список для голосования');
      return;
    }
    
    ref.read(sessionLoadingProvider.notifier).state = true;
    
    try {
      final request = CreateLobbyRequest(
        friendIds: friendIds,
        listId: listId,
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
    final friendIds = ref.watch(selectedFriendsProvider);
    final listName = ref.watch(selectedListNameProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание лобби'),
      ),
      body: isLoading
          ? const LoadingWidget()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Выбранные друзья
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Участники (${friendIds.length})',
                              style: AppTextStyles.headlineSmall,
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final result = await context.push<List<int>>('/select-friends');
                                if (result != null && mounted) {
                                  ref.read(selectedFriendsProvider.notifier).state = result;
                                  _loadFriendNames(); // Перезагружаем имена
                                }
                              },
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Изменить'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (friendIds.isEmpty)
                          Text(
                            'Не выбрано ни одного друга',
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: friendIds.map((id) => Chip(
                              label: Text(_getFriendName(id)),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                final newList = List<int>.from(friendIds)..remove(id);
                                ref.read(selectedFriendsProvider.notifier).state = newList;
                              },
                            )).toList(),
                          ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Выбранный список
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Список для голосования',
                              style: AppTextStyles.headlineSmall,
                            ),
                            TextButton.icon(
                              onPressed: _showSelectListSheet,
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Выбрать'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (listName == null)
                          Text(
                            'Список не выбран',
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                          )
                        else
                          Text(
                            listName,
                            style: AppTextStyles.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  
                  const Spacer(),
                  
                  CustomButton(
                    text: 'Создать лобби',
                    onPressed: _createLobby,
                    backgroundColor: AppColors.primary,
                  ),
                ],
              ),
            ),
    );
  }
}