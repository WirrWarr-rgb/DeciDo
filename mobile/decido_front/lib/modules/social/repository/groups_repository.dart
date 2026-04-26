import '../../../core/network/dio_client.dart';
import '../models/group_model.dart';
import '../models/group_member_model.dart';
import '../models/friend_model.dart';

class GroupsRepository {
  // Получить все группы пользователя
  Future<List<GroupModel>> getMyGroups() async {
    try {
      final response = await DioClient.get('/groups/');
      final List<dynamic> data = response.data;
      return data.map((json) => GroupModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки групп: $e');
    }
  }
  
  // Получить детальную информацию о группе (с участниками)
  Future<({GroupModel group, List<GroupMemberModel> members})> getGroupDetail(int groupId) async {
    try {
      final response = await DioClient.get('/groups/$groupId');
      final data = response.data;
      
      final group = GroupModel(
        id: data['id'],
        name: data['name'],
        description: data['description'],
        ownerId: data['owner_id'],
        createdAt: DateTime.parse(data['created_at']),
        updatedAt: data['updated_at'] != null 
            ? DateTime.parse(data['updated_at']) 
            : null,
      );
      
      final members = (data['members'] as List)
          .map((m) => GroupMemberModel.fromJson(m))
          .toList();
      
      return (group: group, members: members);
    } catch (e) {
      throw Exception('Ошибка загрузки деталей группы: $e');
    }
  }
  
  // Создать группу
  Future<GroupModel> createGroup(String name, {String? description}) async {
    try {
      final response = await DioClient.post('/groups/', data: {
        'name': name,
        'description': description,
      });
      return GroupModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Ошибка создания группы: $e');
    }
  }
  
  // Обновить группу
  Future<GroupModel> updateGroup(int groupId, {String? name, String? description}) async {
    try {
      final Map<String, dynamic> data = {};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;
      
      final response = await DioClient.put('/groups/$groupId', data: data);
      return GroupModel.fromJson(response.data);
    } catch (e) {
      throw Exception('Ошибка обновления группы: $e');
    }
  }
  
  // Удалить группу
  Future<void> deleteGroup(int groupId) async {
    try {
      await DioClient.delete('/groups/$groupId');
    } catch (e) {
      throw Exception('Ошибка удаления группы: $e');
    }
  }
  
  // Добавить участника в группу
  Future<void> addMember(int groupId, int userId) async {
    try {
      await DioClient.post('/groups/$groupId/invite', data: {
        'user_id': userId,
      });
    } catch (e) {
      throw Exception('Ошибка добавления участника: $e');
    }
  }
  
  // Удалить участника из группы
  Future<void> removeMember(int groupId, int userId) async {
    try {
      await DioClient.delete('/groups/$groupId/members/$userId');
    } catch (e) {
      throw Exception('Ошибка удаления участника: $e');
    }
  }
  
  // Выйти из группы
  Future<void> leaveGroup(int groupId) async {
    try {
      await DioClient.post('/groups/$groupId/leave');
    } catch (e) {
      throw Exception('Ошибка выхода из группы: $e');
    }
  }
  
  // Получить список друзей (для добавления в группу)
  Future<List<FriendModel>> getFriends() async {
    try {
      final response = await DioClient.get('/friends/');
      final List<dynamic> data = response.data;
      return data.map((json) => FriendModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Ошибка загрузки друзей: $e');
    }
  }
}