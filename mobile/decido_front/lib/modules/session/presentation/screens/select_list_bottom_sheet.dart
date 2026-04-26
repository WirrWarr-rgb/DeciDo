import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../list/repository/list_repository.dart';
import '../../../list/models/list_model.dart';
import '../../providers/session_providers.dart';

class SelectListBottomSheet extends ConsumerStatefulWidget {
  const SelectListBottomSheet({super.key});

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
    // Преобразуем String ID в int (для бэкенда)
    // Если ID не число, используем хеш или -1
    final int listId = int.tryParse(list.id) ?? list.id.hashCode;

    ref.read(selectedListIdProvider.notifier).state = listId;
    ref.read(selectedListNameProvider.notifier).state = list.name;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Выберите список',
            style: AppTextStyles.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 8),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_lists.isEmpty)
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.list_alt, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    'У вас нет списков',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _lists.length,
                itemBuilder: (context, index) {
                  final list = _lists[index];
                  final isSelected = ref.read(selectedListIdProvider) == list.id;
                  
                  return ListTile(
                    leading: Icon(
                      Icons.list,
                      color: isSelected ? AppColors.primary : Colors.grey,
                    ),
                    title: Text(
                      list.name,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppColors.primary : null,
                      ),
                    ),
                    subtitle: Text(
                      '${_listRepository.getItemsByListId(list.id).length} элементов',
                      style: AppTextStyles.bodySmall,
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () => _selectList(list),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}