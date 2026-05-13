import 'package:equatable/equatable.dart';

class RandomItemModel extends Equatable {
  final String id;
  String name;  // ← убрать final
  String? description;  // ← убрать final
  final String? imageUrl;
  int orderIndex;  // ← убрать final

  RandomItemModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.orderIndex,
  });

  RandomItemModel copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    int? orderIndex,
  }) {
    return RandomItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  List<Object?> get props => [id, name, description, imageUrl, orderIndex];
}

class RandomListModel extends Equatable {
  final String id;
  String name;  // ← сделать изменяемым
  final List<RandomItemModel> items;
  final DateTime createdAt;

  RandomListModel({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, items, createdAt];
}