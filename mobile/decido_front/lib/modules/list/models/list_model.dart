import 'package:hive/hive.dart';

part 'list_model.g.dart';

@HiveType(typeId: 0)
class ListModel extends HiveObject {
  @HiveField(0)
  late String id;
  
  @HiveField(1)
  late String name;
  
  @HiveField(2)
  late DateTime createdAt;
  
  @HiveField(3)
  late DateTime updatedAt;
  
  ListModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });
}