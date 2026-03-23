

import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final int id;
  final String username;
  final String email;
  final bool isActive;
  
  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.isActive,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isActive: json['is_active'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'is_active': isActive,
    };
  }
  
  @override
  List<Object?> get props => [id, username, email, isActive];
}