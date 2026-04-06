import 'package:equatable/equatable.dart';

class UserSearchModel extends Equatable {
  final int id;
  final String username;
  final String email;
  final bool isActive;
  final bool isFriend;
  final bool requestSent;
  final bool isIncomingRequest;  // Добавляем новое поле
  
  const UserSearchModel({
    required this.id,
    required this.username,
    required this.email,
    required this.isActive,
    this.isFriend = false,
    this.requestSent = false,
    this.isIncomingRequest = false,  // Инициализируем
  });
  
  factory UserSearchModel.fromJson(Map<String, dynamic> json) {
    return UserSearchModel(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      isActive: json['is_active'],
      isFriend: false,
      requestSent: false,
      isIncomingRequest: false,
    );
  }
  
  UserSearchModel copyWith({
    int? id,
    String? username,
    String? email,
    bool? isActive,
    bool? isFriend,
    bool? requestSent,
    bool? isIncomingRequest,
  }) {
    return UserSearchModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      isFriend: isFriend ?? this.isFriend,
      requestSent: requestSent ?? this.requestSent,
      isIncomingRequest: isIncomingRequest ?? this.isIncomingRequest,
    );
  }
  
  @override
  List<Object?> get props => [id, username, email, isActive, isFriend, requestSent, isIncomingRequest];
}