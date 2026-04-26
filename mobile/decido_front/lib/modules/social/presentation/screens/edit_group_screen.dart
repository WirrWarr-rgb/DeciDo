import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repository/groups_repository.dart';
import '../../repository/friends_repository.dart';
import '../../models/group_model.dart';
import '../../models/group_member_model.dart';
import '../../models/friend_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class EditGroupScreen extends ConsumerStatefulWidget {
  final int groupId;
  
  const EditGroupScreen({
    super.key,
    required this.groupId,
  });

  @override
  ConsumerState<EditGroupScreen> createState() => _EditGroupScreenState();
}

class _EditGroupScreenState extends ConsumerState<EditGroupScreen> {
  final GroupsRepository _groupsRepository = GroupsRepository();
  final FriendsRepository _friendsRepository = FriendsRepository();
  
  GroupModel? _group;
  List<GroupMemberModel> _members = [];
  List<FriendModel> _friends = [];
  List<FriendModel> _filteredFriends = [];
  
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  Set<int> _memberIds = {};

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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Загружаем детали группы
      final detail = await _groupsRepository.getGroupDetail(widget.groupId);
      _group = detail.group;
      _members = detail.members;
      _memberIds = _members.map((m) => m.userId).toSet();
      
      // Загружаем друзей
      final friends = await _groupsRepository.getFriends();
      _friends = friends;
      _filteredFriends = friends;
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _searchFriends(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((friend) =>
            friend.username.toLowerCase().contains(query.toLowerCase())
        ).toList();
      }
    });
  }

  Future<void> _addMember(FriendModel friend) async {
    setState(() => _isLoading = true);
    try {
      await _groupsRepository.addMember(widget.groupId, friend.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${friend.username} добавлен в группу'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _removeMember(GroupMemberModel member) async {
    setState(() => _isLoading = true);
    try {
      await _groupsRepository.removeMember(widget.groupId, member.userId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.username} удален из группы'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_group?.name ?? 'Редактирование группы'),
      ),
      body: _buildBody(),
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
              onPressed: _loadData,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Участники группы
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Участники (${_members.length})',
                style: AppTextStyles.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (_members.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Нет участников',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primary,
                        child: Text(
                          member.username[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        member.username,
                        style: AppTextStyles.bodyLarge,
                      ),
                      subtitle: Text(
                        member.email,
                        style: AppTextStyles.bodySmall,
                      ),
                      trailing: member.isAdmin
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Админ',
                                style: AppTextStyles.bodySmall.copyWith(color: Colors.amber.shade800),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.person_remove, color: Colors.red),
                              onPressed: () => _removeMember(member),
                              tooltip: 'Удалить из группы',
                            ),
                    );
                  },
                ),
            ],
          ),
        ),
        
        const Divider(),
        
        // Поиск и добавление друзей
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Поиск друзей...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: _searchFriends,
                ),
              ),
              
              Expanded(
                child: _filteredFriends.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Нет друзей для добавления'
                              : 'Друзья не найдены',
                          style: AppTextStyles.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredFriends.length,
                        itemBuilder: (context, index) {
                          final friend = _filteredFriends[index];
                          final isMember = _memberIds.contains(friend.id);
                          
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
                                style: AppTextStyles.bodyLarge,
                              ),
                              subtitle: Text(
                                friend.email,
                                style: AppTextStyles.bodySmall,
                              ),
                              trailing: isMember
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        'В группе',
                                        style: AppTextStyles.bodySmall.copyWith(color: Colors.green.shade700),
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: () => _addMember(friend),
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
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}