import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../config/app_config.dart';
import '../models/list_model.dart';
import '../models/list_item_model.dart';

class ListRepository {
  static const int maxLists = 10;
  static const int maxItems = 20;
  
  // Используем правильные типы для боксов
  late final Box<ListModel> _listsBox;
  late final Box<ListItemModel> _itemsBox;
  final Uuid _uuid = const Uuid();
  
  ListRepository() {
    _listsBox = Hive.box<ListModel>('lists');
    _itemsBox = Hive.box<ListItemModel>('items');
    
    // Добавляем начальные списки для мок-режима, если бокс пуст
    _initMockDataIfNeeded();
  }

  void _initMockDataIfNeeded() {
    if (_listsBox.isEmpty && AppConfig.useMocks) {
      // Создаем тестовый список
      final now = DateTime.now();
      final testList = ListModel(
        id: _uuid.v4(),
        name: 'Что заказать на ужин?',
        createdAt: now,
        updatedAt: now,
      );
      _listsBox.put(testList.id, testList);
      
      // Добавляем тестовые элементы
      final testItems = [
        ListItemModel(
          id: _uuid.v4(),
          listId: testList.id,
          name: 'Пицца Маргарита',
          description: 'Классическая итальянская пицца с томатами и моцареллой',
          orderIndex: 0,
          createdAt: now,
          updatedAt: now,
        ),
        ListItemModel(
          id: _uuid.v4(),
          listId: testList.id,
          name: 'Суши сет',
          description: 'Ассорти из роллов и гунканов',
          orderIndex: 1,
          createdAt: now,
          updatedAt: now,
        ),
        ListItemModel(
          id: _uuid.v4(),
          listId: testList.id,
          name: 'Бургер',
          description: 'Двойной бургер с говядиной, сыром и беконом',
          orderIndex: 2,
          createdAt: now,
          updatedAt: now,
        ),
        ListItemModel(
          id: _uuid.v4(),
          listId: testList.id,
          name: 'Паста Карбонара',
          description: 'Спагетти с беконом в сливочном соусе',
          orderIndex: 3,
          createdAt: now,
          updatedAt: now,
        ),
        ListItemModel(
          id: _uuid.v4(),
          listId: testList.id,
          name: 'Цезарь с курицей',
          description: 'Классический салат с курицей и соусом цезарь',
          orderIndex: 4,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      
      for (var item in testItems) {
        _itemsBox.put(item.id, item);
      }
    }
  }

  
  // Получить все списки
  List<ListModel> getAllLists() {
    return _listsBox.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }
  
  // Получить список по ID
  ListModel? getList(String id) {
    try {
      return _listsBox.values.firstWhere(
        (list) => list.id == id,
        orElse: () => throw Exception('List not found'),
      );
    } catch (e) {
      return null;
    }
  }
  
  // Создать новый список
  ListModel createList(String name) {
    if (_listsBox.length >= maxLists) {
      throw Exception('Максимум $maxLists списков');
    }
    
    final now = DateTime.now();
    final list = ListModel(
      id: _uuid.v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
    );
    
    _listsBox.put(list.id, list);
    return list;
  }
  
  // Обновить список
  void updateList(ListModel list) {
    list.updatedAt = DateTime.now();
    _listsBox.put(list.id, list);
  }
  
  // Удалить список и все его элементы
  void deleteList(String listId) {
    final itemsToDelete = getItemsByListId(listId);
    for (var item in itemsToDelete) {
      _itemsBox.delete(item.id);
    }
    _listsBox.delete(listId);
  }
  
  // Получить элементы списка
  List<ListItemModel> getItemsByListId(String listId) {
    return _itemsBox.values
        .where((item) => item.listId == listId)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }
  
  // Создать элемент
  ListItemModel createItem(String listId, String name) {
    final items = getItemsByListId(listId);
    if (items.length >= maxItems) {
      throw Exception('Максимум $maxItems элементов в списке');
    }
    
    final now = DateTime.now();
    final item = ListItemModel(
      id: _uuid.v4(),
      listId: listId,
      name: name,
      orderIndex: items.length,
      createdAt: now,
      updatedAt: now,
    );
    
    _itemsBox.put(item.id, item);
    return item;
  }

  // Генерация уникального имени для нового списка
  String generateUniqueListName(String baseName) {
    final existingNames = getAllLists().map((list) => list.name).toSet();
    
    if (!existingNames.contains(baseName)) {
      return baseName;
    }
    
    int counter = 1;
    String newName;
    do {
      newName = '$baseName $counter';
      counter++;
    } while (existingNames.contains(newName));
    
    return newName;
  }
  
  // Обновить элемент
  void updateItem(ListItemModel item) {
    item.updatedAt = DateTime.now();
    _itemsBox.put(item.id, item);
  }
  
  // Удалить элемент
  void deleteItem(String itemId) {
    final item = _itemsBox.get(itemId);
    if (item != null) {
      final items = getItemsByListId(item.listId);
      for (var i in items) {
        if (i.orderIndex > item.orderIndex) {
          i.orderIndex--;
          _itemsBox.put(i.id, i);
        }
      }
      _itemsBox.delete(itemId);
    }
  }
  
  // Переместить элемент
  void reorderItems(String listId, int oldIndex, int newIndex) {
    final items = getItemsByListId(listId);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    
    for (int i = 0; i < items.length; i++) {
      items[i].orderIndex = i;
      _itemsBox.put(items[i].id, items[i]);
    }
  }
  
  // Проверка лимитов
  bool canCreateList() => _listsBox.length < maxLists;
  bool canCreateItem(String listId) => getItemsByListId(listId).length < maxItems;
}