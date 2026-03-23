

import 'package:equatable/equatable.dart';

class DashboardModel extends Equatable {
  final String userName;
  final List<GroupModel> groups;
  final List<SessionModel> upcomingSessions;
  final List<ActivityModel> recentActivity;
  
  const DashboardModel({
    required this.userName,
    required this.groups,
    required this.upcomingSessions,
    required this.recentActivity,
  });
  
  @override
  List<Object?> get props => [
    userName,
    groups,
    upcomingSessions,
    recentActivity,
  ];
}

class GroupModel extends Equatable {
  final int id;
  final String name;
  final String? avatarUrl;
  final int memberCount;
  final bool hasPendingVote;
  
  const GroupModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.memberCount,
    this.hasPendingVote = false,
  });
  
  @override
  List<Object?> get props => [id, name, avatarUrl, memberCount, hasPendingVote];
}

class SessionModel extends Equatable {
  final int id;
  final String groupName;
  final String listName;
  final DateTime startTime;
  
  const SessionModel({
    required this.id,
    required this.groupName,
    required this.listName,
    required this.startTime,
  });
  
  @override
  List<Object?> get props => [id, groupName, listName, startTime];
}

class ActivityModel extends Equatable {
  final String type;
  final String title;
  final String description;
  final DateTime timestamp;
  
  const ActivityModel({
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [type, title, description, timestamp];
}