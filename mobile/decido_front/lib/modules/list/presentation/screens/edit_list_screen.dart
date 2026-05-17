import 'package:decido_front/core/theme/app_colors.dart';
import 'package:decido_front/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
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
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isLoading = true;
  int? _editingItemIndex;

  // Параметр сдвига - измени здесь для регулировки расстояния
  final double shiftDistance = 60;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final list = _repository.getList(widget.listId);
    if (list == null) {
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
    setState(() {
      _items.add(newItem);
    });
    _showItemEditSheet(newItem);
  }

  void _editItem(int index) {
    setState(() {
      _editingItemIndex = index;
    });
    _showItemEditSheet(_items[index]);
  }

  void _deleteItem(int index) {
    final item = _items[index];
    _repository.deleteItem(item.id);
    setState(() {
      _items.removeAt(index);
      _editingItemIndex = null;
    });
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
            setState(() {
              _items[index] = updatedItem;
              _editingItemIndex = null;
            });
          }
          Navigator.pop(context);
        },
        onClose: () {
          setState(() {
            _editingItemIndex = null;
          });
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _editingItemIndex = null;
        });
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // Определяем, какие элементы должны сдвигаться
  bool _shouldShift(int index, int? editingIndex) {
    if (editingIndex == null) return false;
    final diff = (index - editingIndex).abs();
    return diff <= 2; // 2 элемента в каждую сторону
  }

  // Получаем величину сдвига для элемента (сдвиг влево, поэтому отрицательные значения)
  double _getItemOffset(int index, int? editingIndex) {
    if (editingIndex == null) return 0;
    final diff = (index - editingIndex).abs();
    if (diff == 0) return -shiftDistance;      // Выбранный элемент
    if (diff == 1) return -(shiftDistance * 0.5); // Ближайшие соседи
    if (diff == 2) return -(shiftDistance * 0.25); // Вторые соседи
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Container(
        width: 412,
        height: 892,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Stack(
          children: [
            // Затемнение при открытом bottom sheet
            if (_editingItemIndex != null)
              Container(
                width: 412,
                height: 892,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.tertiary.withOpacity(0.7),
                      AppColors.secondary.withOpacity(0.7),
                    ],
                  ),
                ),
              ),

            // Кнопка меню (назад)
            Positioned(
              left: 10,
              top: 52,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
                padding: EdgeInsets.zero,
              ),
            ),

            // Название списка
            Positioned(
              left: 60,
              top: 52,
              child: _isEditingName
                  ? SizedBox(
                      width: 200,
                      child: TextField(
                        controller: _nameController,
                        autofocus: true,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Название списка',
                        ),
                        onSubmitted: (_) => _updateListName(),
                      ),
                    )
                  : GestureDetector(
                      onTap: () => setState(() => _isEditingName = true),
                      child: Row(
                        children: [
                          Text(
                            _list.name,
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 24,
                              height: 1.67,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit, size: 18, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
            ),

            // Счетчик элементов
            Positioned(
              right: 30,
              top: 52,
              child: Text(
                '${_items.length}/${ListRepository.maxItems}',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 24,
                  fontFamily: 'Instrument Sans',
                  fontWeight: FontWeight.w500,
                  height: 1.67,
                ),
              ),
            ),

                        
            // Список элементов
            Positioned(
              left: 25,
              top: 162,
              child: Container(
                width: 512,
                height: 600,
                child: _items.isEmpty
                    ? Align(
                        alignment: Alignment(-0.6, 0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.format_list_bulleted, size: 64, color: AppColors.tertiary),
                            const SizedBox(height: 16),
                            const Text(
                              style: AppTextStyles.bodyGeneral,
                              'Список пуст'
                              ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _addNewItem,
                              child: const Text(
                                style: AppTextStyles.button,
                                'Добавить первый элемент'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final offset = _getItemOffset(index, _editingItemIndex);
                          final isEven = index % 2 == 0;
                          
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            transform: Matrix4.translationValues(offset, 0, 0),
                            child: GestureDetector(
                              onTap: () => _editItem(index),
                              child: Container(
                                height: 48,
                                margin: EdgeInsets.zero,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Иконка удаления
                                    SizedBox(
                                      width: 35,
                                      child: GestureDetector(
                                        onTap: () => _deleteItem(index),
                                        child: SvgPicture.asset(
                                          'assets/icons/delete_bin_icon.svg',
                                          //color: isEven ? AppColors.inputBackground : AppColors.primary,
                                          colorFilter: isEven ? const ColorFilter.mode(
                                            AppColors.inputBackground,
                                            BlendMode.srcIn,
                                          ) :
                                          const ColorFilter.mode(
                                            AppColors.primary,
                                            BlendMode.srcIn,
                                          ),
                                          width: 35,
                                          height: 35,
                                        ),
                                      ),
                                    ),
              
                                    const SizedBox(width: 21),
                                    
                                    // Задний план (теперь использует Expanded)
                                    Expanded(
                                      child: Container(
                                        height: 48,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                        decoration: ShapeDecoration(
                                          color: isEven ? AppColors.inputBackground : AppColors.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: Text(
                                          item.name,
                                          style: TextStyle(
                                            color: isEven ? AppColors.textPrimary : AppColors.textLight,
                                            fontSize: 20,
                                            fontFamily: 'Instrument Sans',
                                            fontWeight: FontWeight.w500,
                                            height: 1.10,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
                        
                        
            // Кнопка добавления элемента
            Positioned(
              left: 176,
              top: 775,
              child: GestureDetector(
                onTap: _addNewItem,

                child: Container(
                  width: 60,
                  height: 60,
                  decoration: ShapeDecoration(
                    color: AppColors.secondary,
                    shape: const OvalBorder(),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: SvgPicture.asset(
                        'assets/icons/add_plus_white_icon.svg',
                        width: 46,
                        height: 46,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}