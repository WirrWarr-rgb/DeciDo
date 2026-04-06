import 'package:hive/hive.dart';

part 'list_item_model.g.dart';

@HiveType(typeId: 1)
class ListItemModel extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String listId;
  
  @HiveField(2)
  late String name;
  
  @HiveField(3)
  String? description;
  
  @HiveField(4)
  String? imageUrl;
  
  @HiveField(5)
  late int orderIndex;
  
  @HiveField(6)
  late DateTime createdAt;
  
  @HiveField(7)
  late DateTime updatedAt;
  
  ListItemModel({
    required this.id,
    required this.listId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.orderIndex,
    required this.createdAt,
    required this.updatedAt,
  });
}