import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../session/models/session_models.dart';
import '../../../session/presentation/screens/select_list_bottom_sheet.dart';
import '../../../session/presentation/screens/session_item_edit_bottom_sheet.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_scaffold.dart';
import '../../../shared/widgets/loading_widget.dart';
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
  List<RandomItemModel> _items = [];
  int? _editingItemIndex;
  final double shiftDistance = 60;
  bool _showListDropdown = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedList != null) {
      _selectedList = widget.preselectedList;
      _items = List.from(widget.preselectedList!.items);
    }
  }

  void _selectList(SessionListModel list, String originalId) {
    // Создаем копию списка для случайного выбора
    final copiedItems = list.items.map((item) => RandomItemModel(
      id: item.id.toString(),
      name: item.name,
      description: item.description,
      imageUrl: item.imageUrl,
      orderIndex: item.orderIndex,
    )).toList();
    
    final randomList = RandomListModel(
      id: originalId,
      name: list.name,
      items: copiedItems,
      createdAt: DateTime.now(),
    );
    
    setState(() {
      _selectedList = randomList;
      _items = copiedItems;
      _showListDropdown = false;
    });
  }

  void _toggleListDropdown() {
    setState(() {
      _showListDropdown = !_showListDropdown;
    });
  }

  void _addNewItem() {
    if (_items.length >= 20) {
      _showError('Достигнут лимит элементов (20)');
      return;
    }

    final newItem = RandomItemModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Новый элемент',
      description: null,
      imageUrl: null,
      orderIndex: _items.length,
    );
    
    setState(() {
      _items.add(newItem);
      _editingItemIndex = _items.length - 1;
    });
    
    _showItemEditSheet(newItem, _items.length - 1);
  }

  void _editItem(int index) {
    setState(() {
      _editingItemIndex = index;
    });
    _showItemEditSheet(_items[index], index);
  }

  void _deleteItem(int index) {
    setState(() {
      _items.removeAt(index);
      _editingItemIndex = null;
    });
  }

  void _showItemEditSheet(RandomItemModel item, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SessionItemEditBottomSheet(
        item: SessionListItemModel(
          id: int.tryParse(item.id) ?? item.id.hashCode,
          name: item.name,
          description: item.description,
          imageUrl: item.imageUrl,
          orderIndex: item.orderIndex,
        ),
        onSave: (name, description, imageUrl) {
          setState(() {
            // Обновляем элемент по конкретному индексу
            _items[index] = item.copyWith(
              name: name,
              description: description,
              imageUrl: imageUrl,
            );
            _editingItemIndex = null;
          });
          Navigator.pop(context);
        },
        onClose: () {
          setState(() {
            _editingItemIndex = null;
          });
          Navigator.pop(context);
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

  double _getItemOffset(int index, int? editingIndex) {
    if (editingIndex == null) return 0;
    final diff = (index - editingIndex).abs();
    if (diff == 0) return -shiftDistance;
    if (diff == 1) return -(shiftDistance * 0.5);
    if (diff == 2) return -(shiftDistance * 0.25);
    return 0;
  }

  void _startRandom() {
    if (_selectedList == null) {
      _showError('Выберите список');
      return;
    }
    
    if (_items.isEmpty) {
      _showError('Список пуст. Добавьте элементы');
      return;
    }
    
    // Создаем обновленный список с текущими элементами
    final updatedList = RandomListModel(
      id: _selectedList!.id,
      name: _selectedList!.name,
      items: _items,
      createdAt: _selectedList!.createdAt,
    );
    
    context.push('/random-wheel', extra: updatedList);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasList = _selectedList != null;
    // Определяем позицию кнопки добавления в зависимости от того, выбран ли список
    final addButtonTop = hasList ? 310 : 310;
    final listTop = hasList ? 375 : 310;
    final listHeight = hasList ? 385 : 430;
    
    return CustomScaffold(
      title: "Подготовка",
      showBackButton: true,
      body: Stack(
        children: [
          Container(
            width: 412,
            height: 892,
            decoration: ShapeDecoration(
              color: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Stack(
              children: [
                
                // Счетчик элементов списка
                Positioned(
                  left: 102,
                  top: 142,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Список  ',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontFamily: 'Instrument Sans',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: '${_items.length}/20',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 20,
                            fontFamily: 'Instrument Sans',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Кнопка выбора списка
                Positioned(
                  left: 78,
                  top: 175,
                  child: GestureDetector(
                    onTap: _toggleListDropdown,
                    child: Container(
                      width: 257,
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                      decoration: ShapeDecoration(
                        color: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedList?.name ?? 'Выберите список',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 16,
                              fontFamily: 'Instrument Sans',
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Icon(
                            _showListDropdown ? Icons.chevron_left : Icons.chevron_right,
                            color: AppColors.textLight,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Кнопка добавления элемента (над списком, как в лобби)
                if (hasList)
                  Positioned(
                    left: 81,
                    top: 249,
                    child: GestureDetector(
                      onTap: _addNewItem,
                      child: Container(
                        width: 368,
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                        decoration: ShapeDecoration(
                          color: AppColors.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.add, color: AppColors.textLight, size: 25),
                            const SizedBox(width: 10),
                            Text(
                              'Добавить новый элемент',
                              style: TextStyle(
                                color: AppColors.textLight,
                                fontSize: 18,
                                fontFamily: 'Instrument Sans',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                
                // Список элементов (под кнопкой добавления)
                if (hasList)
                  Positioned(
                    left: 25,
                    top: 297,
                    child: Container(
                      width: 512,
                      height: 385,
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
                                              colorFilter: isEven 
                                                  ? const ColorFilter.mode(
                                                      AppColors.inputBackground,
                                                      BlendMode.srcIn,
                                                    )
                                                  : const ColorFilter.mode(
                                                      AppColors.primary,
                                                      BlendMode.srcIn,
                                                    ),
                                              width: 35,
                                              height: 35,
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(width: 21),
                                        
                                        // Задний план (кликабельный для редактирования)
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => _editItem(index),
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
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                
                // Кнопка "Крутить колесо"
                Positioned(
                  left: 141,
                  bottom: 30,
                  child: CustomButton(
                    text: 'КРУТИТЬ КОЛЕСО',
                    onPressed: _startRandom,
                    width: 130,
                    backgroundColor: AppColors.secondary,
                    textStyle: AppTextStyles.buttonBig,
                  ),
                ),
              ],
            ),
          ),
          
          // Выпадающий список поверх всего
          if (_showListDropdown)
            Positioned(
              left: 78,
              top: 175 + 45,
              child: SelectListBottomSheet(
                onSelectList: _selectList,
                onClose: () => setState(() => _showListDropdown = false),
              ),
            ),
          
          // Затемнение при открытом bottom sheet редактирования
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
        ],
      ),
    );
  }
}