import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../list/repository/list_repository.dart';
import '../../../list/models/list_model.dart';
import '../../../list/models/list_item_model.dart';
import '../../models/session_models.dart';

class SelectListBottomSheet extends ConsumerStatefulWidget {
  final Function(SessionListModel, String) onSelectList;
  final VoidCallback onClose;

  const SelectListBottomSheet({
    super.key,
    required this.onSelectList,
    required this.onClose,
  });

  @override
  ConsumerState<SelectListBottomSheet> createState() => _SelectListBottomSheetState();
}

class _SelectListBottomSheetState extends ConsumerState<SelectListBottomSheet> {
  final ListRepository _listRepository = ListRepository();
  List<ListModel> _lists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  void _loadLists() {
    setState(() {
      _lists = _listRepository.getAllLists();
      _isLoading = false;
    });
  }


  void _selectList(ListModel list) {
    final items = _listRepository.getItemsByListId(list.id);
    
    final sessionList = SessionListModel(
       id: list.id.hashCode,
      name: list.name,
      isActive: true,
      items: items.map((item) => SessionListItemModel(
        id: list.id.hashCode,  // item.id теперь String
        name: item.name,
        description: item.description,
        imageUrl: item.imageUrl,
        orderIndex: item.orderIndex,
      )).toList(),
      createdAt: list.createdAt,
    );
    
    widget.onSelectList(sessionList, list.id);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 257,
        constraints: BoxConstraints(
          maxHeight: 300,
        ),
        decoration: ShapeDecoration(
          color: AppColors.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _lists.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.list_alt, size: 32, color: AppColors.textLight),
                          const SizedBox(height: 8),
                          Text(
                            'У вас нет списков',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _lists.length,
                      itemBuilder: (context, index) {
                        final list = _lists[index];
                        final itemsCount = _listRepository.getItemsByListId(list.id).length;
                        
                        return GestureDetector(
                          onTap: () => _selectList(list),
                          child: Container(
                            width: 247,
                            height: 56,
                            margin: const EdgeInsets.all(5),
                            decoration: ShapeDecoration(
                              color: AppColors.background,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              visualDensity: const VisualDensity(vertical: -4), // Отрицательное значение уменьшает отступы
                              title: Text(
                                list.name,
                                style: AppTextStyles.dropbox.copyWith(color: AppColors.secondary)
                              ),
                              subtitle: Text(
                                '$itemsCount элементов',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontFamily: 'Instrument Sans',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.secondary,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}