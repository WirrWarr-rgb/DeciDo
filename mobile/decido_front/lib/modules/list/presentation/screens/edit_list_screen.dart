import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../repository/list_repository.dart';
import '../../models/list_model.dart';
import '../../models/list_item_model.dart';
import 'item_edit_bottom_sheet.dart';

class EditListScreen extends ConsumerStatefulWidget {
  final String listId;
  
  const EditListScreen({
    super.key,
    required this.listId,
  });

  @override
  ConsumerState<EditListScreen> createState() => _EditListScreenState();
}

class _EditListScreenState extends ConsumerState<EditListScreen> {
  final ListRepository _repository = ListRepository();
  late ListModel _list;
  late List<ListItemModel> _items;
  final _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  void _loadData() {
    final list = _repository.getList(widget.listId);
    if (list == null) {
      // Список не найден - возвращаемся назад
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Список не найден'), backgroundColor: Colors.red),
          );
          context.pop();
        }
      });
      return;
    }
    
    setState(() {
      _list = list;
      _items = _repository.getItemsByListId(widget.listId);
      _nameController.text = _list.name;
      _isLoading = false;
    });
  }
  
  void _updateListName() {
    if (_nameController.text.trim().isNotEmpty) {
      _list.name = _nameController.text.trim();
      _repository.updateList(_list);
      setState(() => _isEditingName = false);
    }
  }
  
  void _addNewItem() {
    if (!_repository.canCreateItem(widget.listId)) {
      _showError('Достигнут лимит элементов (${ListRepository.maxItems})');
      return;
    }
    
    final newItem = _repository.createItem(widget.listId, 'Новый элемент');
    _items.add(newItem);
    setState(() {});
    
    _showItemEditSheet(newItem);
  }
  
  void _editItem(ListItemModel item) {
    _showItemEditSheet(item);
  }
  
  void _deleteItem(ListItemModel item) {
    _repository.deleteItem(item.id);
    _items.remove(item);
    setState(() {});
  }
  
  void _showItemEditSheet(ListItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItemEditBottomSheet(
        item: item,
        onSave: (updatedItem) {
          _repository.updateItem(updatedItem);
          final index = _items.indexWhere((i) => i.id == updatedItem.id);
          if (index != -1) {
            _items[index] = updatedItem;
            setState(() {});
          }
        },
        onDelete: () {
          _deleteItem(item);
          Navigator.pop(context);
        },
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: _isEditingName
            ? TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Название списка',
                ),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                onSubmitted: (_) => _updateListName(),
              )
            : GestureDetector(
                onTap: () => setState(() => _isEditingName = true),
                child: Row(
                  children: [
                    Text(_list.name),
                    const SizedBox(width: 8),
                    const Icon(Icons.edit, size: 18, color: Colors.grey),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewItem,
            tooltip: 'Добавить элемент',
          ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.format_list_bulleted, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Список пуст'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addNewItem,
                    child: const Text('Добавить первый элемент'),
                  ),
                ],
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                _repository.reorderItems(widget.listId, oldIndex, newIndex);
                final item = _items.removeAt(oldIndex);
                _items.insert(newIndex, item);
                setState(() {});
              },
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  key: Key(item.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(fontSize: 16),
                    ),
                    subtitle: item.description != null
                        ? Text(
                            item.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _editItem(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _deleteItem(item),
                        ),
                      ],
                    ),
                    onTap: () => _editItem(item),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}