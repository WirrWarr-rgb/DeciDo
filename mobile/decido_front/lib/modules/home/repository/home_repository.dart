

import '../../../core/network/dio_client.dart';
import '../models/dashboard_model.dart';

class HomeRepository {
  Future<DashboardModel> getDashboard() async {
    final response = await DioClient.get('/users/me/dashboard');
    
    final data = response.data;
    
    // Парсим данные из ответа API
    return DashboardModel(
      userName: data['username'],
      groups: (data['groups'] as List).map((g) => GroupModel(
        id: g['id'],
        name: g['name'],
        avatarUrl: g['avatar_url'],
        memberCount: g['member_count'],
        hasPendingVote: g['has_pending_vote'] ?? false,
      )).toList(),
      upcomingSessions: (data['upcoming_sessions'] as List).map((s) => SessionModel(
        id: s['id'],
        groupName: s['group_name'],
        listName: s['list_name'],
        startTime: DateTime.parse(s['start_time']),
      )).toList(),
      recentActivity: (data['recent_activity'] as List).map((a) => ActivityModel(
        type: a['type'],
        title: a['title'],
        description: a['description'],
        timestamp: DateTime.parse(a['timestamp']),
      )).toList(),
    );
  }
}