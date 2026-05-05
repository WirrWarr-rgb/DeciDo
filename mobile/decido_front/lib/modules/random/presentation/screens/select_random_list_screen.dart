import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../session/presentation/screens/select_list_bottom_sheet.dart';
import '../../../shared/widgets/custom_scaffold.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../list/repository/list_repository.dart';
import '../../repository/random_repository.dart';
import '../../models/random_item_model.dart';
import 'random_wheel_screen.dart';

class SelectRandomListScreen extends ConsumerStatefulWidget {
  final RandomListModel? preselectedList;

  const SelectRandomListScreen({super.key, this.preselectedList});

  @override
  ConsumerState<SelectRandomListScreen> createState() => _SelectRandomListScreenState();
}

class _SelectRandomListScreenState extends ConsumerState<SelectRandomListScreen> {
  final ListRepository _listRepository = ListRepository();
  final RandomRepository _randomRepository = RandomRepository();
  
  RandomListModel? _selectedList;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedList != null) {
      _selectedList = widget.preselectedList;
    }
  }

  void _showSelectListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SelectListBottomSheet(
        onSelectList: (list, originalId) {
          setState(() {
            _selectedList = _randomRepository.getRandomListFromOriginal(originalId);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _startRandom() {
    if (_selectedList == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите список'), backgroundColor: Colors.red),
      );
      return;
    }
    
    context.push('/random-wheel', extra: _selectedList);
  }

  void _addItem() {
    if (_selectedList == null) return;
    _showItemEditBottomSheet(isNew: true);
  }

  void _editItem(RandomItemModel item) {
    _showItemEditBottomSheet(item: item);
  }

  void _deleteItem(RandomItemModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить элемент'),
        content: Text('Вы уверены, что хотите удалить "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedList!.items.remove(item);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showItemEditBottomSheet({bool isNew = false, RandomItemModel? item}) {
    final controller = TextEditingController(text: isNew ? '' : item?.name);
    final descriptionController = TextEditingController(text: isNew ? '' : item?.description);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateSheet) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isNew ? 'Новый элемент' : 'Редактирование',
                      style: AppTextStyles.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        border: OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Описание (необязательно)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (!isNew)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _deleteItem(item!);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text('Удалить'),
                            ),
                          ),
                        if (!isNew) const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (controller.text.trim().isEmpty) return;
                              setState(() {
                                if (isNew) {
                                  _selectedList!.items.add(
                                    RandomItemModel(
                                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                                      name: controller.text.trim(),
                                      description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                                      orderIndex: _selectedList!.items.length,
                                    ),
                                  );
                                } else {
                                  item!.name = controller.text.trim();
                                  item.description = descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim();
                                }
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                            child: const Text('Сохранить'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'Случайный выбор',
      showBackButton: true,
      menuIconColor: AppColors.textPrimary,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Выбранный список
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Список для выбора',
                        style: AppTextStyles.headlineSmall,
                      ),
                      TextButton.icon(
                        onPressed: _showSelectListSheet,
                        icon: const Icon(Icons.list, size: 18),
                        label: const Text('Выбрать другой'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedList == null)
                    Text(
                      'Список не выбран',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedList!.name,
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selectedList!.items.length} элементов',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Редактирование списка (сразу раскрыто)
            if (_selectedList != null)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Редактирование списка',
                            style: AppTextStyles.headlineSmall,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: _addItem,
                            tooltip: 'Добавить элемент',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _selectedList!.items.isEmpty
                            ? Center(
                                child: Text(
                                  'Список пуст',
                                  style: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _selectedList!.items.length,
                                separatorBuilder: (_, __) => const Divider(),
                                itemBuilder: (context, index) {
                                  final item = _selectedList!.items[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.primary.withOpacity(0.2),
                                      child: Text(
                                        '${index + 1}',
                                        style: TextStyle(color: AppColors.primary, fontSize: 12),
                                      ),
                                    ),
                                    title: Text(
                                      item.name,
                                      style: AppTextStyles.bodyLarge,
                                    ),
                                    subtitle: item.description != null
                                        ? Text(
                                            item.description!,
                                            style: AppTextStyles.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 18),
                                          onPressed: () => _editItem(item),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                          onPressed: () => _deleteItem(item),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            CustomButton(
              text: 'Крутить колесо',
              onPressed: _startRandom,
              backgroundColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}