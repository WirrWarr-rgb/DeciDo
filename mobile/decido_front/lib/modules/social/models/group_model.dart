import 'package:equatable/equatable.dart';

class GroupModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final int ownerId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  const GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.ownerId,
    required this.createdAt,
    this.updatedAt,
  });
  
  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      ownerId: json['owner_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
  
  @override
  List<Object?> get props => [id, name, description, ownerId, createdAt, updatedAt];
}