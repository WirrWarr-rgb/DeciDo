import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../repository/list_repository.dart';
import '../../models/list_model.dart';
import 'edit_list_screen.dart';

class MyListsScreen extends ConsumerStatefulWidget {
  const MyListsScreen({super.key});

  @override
  ConsumerState<MyListsScreen> createState() => _MyListsScreenState();
}

class _MyListsScreenState extends ConsumerState<MyListsScreen> {
  final ListRepository _repository = ListRepository();
  late List<ListModel> _lists;
  
  @override
  void initState() {
    super.initState();
    _loadLists();
  }
  
  void _loadLists() {
    setState(() {
      _lists = _repository.getAllLists();
    });
  }
  
  Future<void> _createNewList() async {
  try {
    if (!_repository.canCreateList()) {
      _showError('Достигнут лимит списков (${ListRepository.maxLists})');
      return;
    }
    
    // Генерируем уникальное имя
    final uniqueName = _repository.generateUniqueListName('Новый список');
    
    // Создаем список с уникальным именем
    final newList = _repository.createList(uniqueName);
    
    // Создаем элемент по умолчанию
    _repository.createItem(newList.id, 'Первый элемент');
    
    if (mounted) {
      context.pushNamed('editList', 
        pathParameters: {'id': newList.id},
        extra: {'isNew': true},
      ).then((_) => _loadLists());
    }
  } catch (e) {
    _showError(e.toString());
  }
  }
  
  void _editList(ListModel list) {
    context.pushNamed('editList', pathParameters: {'id': list.id},
          extra: {'isNew': false}).then((_) => _loadLists());
  }
  
  void _deleteList(ListModel list) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить список?'),
        content: Text('Вы уверены, что хотите удалить "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              _repository.deleteList(list.id);
              Navigator.pop(context);
              _loadLists();
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои списки'),
      ),
      body: _lists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.list_alt, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'У вас пока нет списков',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: 'Создать первый список',
                    onPressed: _createNewList,
                    width: 200,
                    fontSize: 16,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _lists.length,
              itemBuilder: (context, index) {
                final list = _lists[index];
                final itemsCount = _repository.getItemsByListId(list.id).length;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.secondary,
                      child: Text('${index + 1}'),
                    ),
                    title: Text(
                      list.name,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.background, // Явно указываем темный цвет
                      ),
                    ),
                    subtitle: Text(
                      '$itemsCount элементов',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: AppColors.primary),
                          onPressed: () => _editList(list),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteList(list),
                        ),
                      ],
                    ),
                    onTap: () => _editList(list),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewList,
        child: const Icon(Icons.add),
      ),
    );
  }
}