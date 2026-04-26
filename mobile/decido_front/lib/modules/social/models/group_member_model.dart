import 'package:equatable/equatable.dart';

enum GroupRole { admin, member }

class GroupMemberModel extends Equatable {
  final int id;
  final int userId;
  final String username;
  final String email;
  final GroupRole role;
  final DateTime joinedAt;
  
  const GroupMemberModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.joinedAt,
  });
  
  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'],
      userId: json['user_id'],
      username: json['username'],
      email: json['email'],
      role: json['role'] == 'admin' ? GroupRole.admin : GroupRole.member,
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
  
  bool get isAdmin => role == GroupRole.admin;
  
  @override
  List<Object?> get props => [id, userId, username, email, role, joinedAt];
}