import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/session_models.dart';

class ItemEditBottomSheet extends StatefulWidget {
  final SessionListItemModel? item;
  final bool isNew;
  final Function(String name, String? description, String? imageUrl) onSave;
  final VoidCallback? onDelete;

  const ItemEditBottomSheet({
    super.key,
    this.item,
    required this.isNew,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ItemEditBottomSheet> createState() => _ItemEditBottomSheetState();
}

class _ItemEditBottomSheetState extends State<ItemEditBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _descriptionController = TextEditingController(text: widget.item?.description ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название'), backgroundColor: Colors.red),
      );
      return;
    }
    
    widget.onSave(
      _nameController.text.trim(),
      _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            widget.isNew ? 'Новый элемент' : 'Редактирование',
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Описание (необязательно)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (!widget.isNew && widget.onDelete != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.onDelete!(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Удалить'),
                  ),
                ),
              if (!widget.isNew && widget.onDelete != null) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}