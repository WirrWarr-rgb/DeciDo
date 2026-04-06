import 'package:equatable/equatable.dart';

enum FriendStatus { pending, accepted, rejected }

class FriendRequestModel extends Equatable {
  final int id;
  final int userId;
  final int friendId;
  final FriendStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  const FriendRequestModel({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    return FriendRequestModel(
      id: json['id'],
      userId: json['user_id'],
      friendId: json['friend_id'],
      status: _parseStatus(json['status']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
  
  static FriendStatus _parseStatus(String status) {
    switch (status) {
      case 'pending':
        return FriendStatus.pending;
      case 'accepted':
        return FriendStatus.accepted;
      case 'rejected':
        return FriendStatus.rejected;
      default:
        return FriendStatus.pending;
    }
  }
  
  String get statusString {
    switch (status) {
      case FriendStatus.pending:
        return 'pending';
      case FriendStatus.accepted:
        return 'accepted';
      case FriendStatus.rejected:
        return 'rejected';
    }
  }
  
  @override
  List<Object?> get props => [id, userId, friendId, status, createdAt, updatedAt];
}