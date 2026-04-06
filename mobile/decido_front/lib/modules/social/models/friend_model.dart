import 'package:equatable/equatable.dart';

class FriendModel extends Equatable {
  final int id;
  final String username;
  final String email;
  
  const FriendModel({
    required this.id,
    required this.username,
    required this.email,
  });
  
  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
    );
  }
  
  @override
  List<Object?> get props => [id, username, email];
}