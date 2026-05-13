import 'package:equatable/equatable.dart';

class FriendModel extends Equatable {
  final int id;
  final String username;
  final String email;
  final bool? isActive;
  
  const FriendModel({
    required this.id,
    required this.username,
    required this.email,
    required this.isActive,
  });
  
  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isActive: json['is_active'],
    );
  }
  
  @override
  List<Object?> get props => [id, username, email];
}