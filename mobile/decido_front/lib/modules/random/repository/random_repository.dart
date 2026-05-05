import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../modules/list/repository/list_repository.dart';
import '../../../modules/list/models/list_model.dart';
import '../../../modules/list/models/list_item_model.dart';
import '../models/random_item_model.dart';

class RandomRepository {
  final ListRepository _listRepository = ListRepository();
  final Uuid _uuid = const Uuid();

  // Получить список по ID и создать копию для случайного выбора
  RandomListModel getRandomListFromOriginal(String originalListId) {
    final originalList = _listRepository.getList(originalListId);
    if (originalList == null) {
      throw Exception('Список не найден');
    }
    
    final items = _listRepository.getItemsByListId(originalListId);
    
    return RandomListModel(
      id: _uuid.v4(),
      name: originalList.name,
      items: items.map((item) => RandomItemModel(
        id: item.id,
        name: item.name,
        description: item.description,
        imageUrl: item.imageUrl,
        orderIndex: item.orderIndex,
      )).toList(),
      createdAt: DateTime.now(),
    );
  }

  // Создать пустой список (для тестирования)
  RandomListModel createMockList() {
    final items = [
      RandomItemModel(
        id: _uuid.v4(),
        name: 'Пицца',
        description: 'Итальянская пицца',
        orderIndex: 0,
      ),
      RandomItemModel(
        id: _uuid.v4(),
        name: 'Суши',
        description: 'Японские роллы',
        orderIndex: 1,
      ),
      RandomItemModel(
        id: _uuid.v4(),
        name: 'Бургер',
        description: 'Сочный бургер',
        orderIndex: 2,
      ),
      RandomItemModel(
        id: _uuid.v4(),
        name: 'Паста',
        description: 'Итальянская паста',
        orderIndex: 3,
      ),
    ];
    
    return RandomListModel(
      id: _uuid.v4(),
      name: 'Что поесть?',
      items: items,
      createdAt: DateTime.now(),
    );
  }
}