import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/session_models.dart';

class SessionItemEditBottomSheet extends StatefulWidget {
  final SessionListItemModel item;
  final Function(String name, String? description, String? imageUrl) onSave;
  final VoidCallback onClose;

  const SessionItemEditBottomSheet({
    super.key,
    required this.item,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<SessionItemEditBottomSheet> createState() => _SessionItemEditBottomSheetState();
}

class _SessionItemEditBottomSheetState extends State<SessionItemEditBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _descriptionController = TextEditingController(text: widget.item.description ?? '');
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

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    widget.onSave(name, description, null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onClose();
        Navigator.pop(context);
      },
      child: Container(
        height: 322,
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: GestureDetector(
          onTap: () {},
          child: Stack(
            children: [
              // Белая карточка
              Positioned(
                left: 0,
                top: 0,
                child: Container(
                  width: 412,
                  height: 322,
                  decoration: const ShapeDecoration(
                    color: AppColors.background,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(25),
                        topRight: Radius.circular(25),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Место для картинки
              Positioned(
                left: 20,
                top: 24,
                child: Container(
                  width: 150,
                  height: 211,
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    color: AppColors.tertiary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image,
                      color: AppColors.textLight.withOpacity(0.5),
                      size: 40,
                    ),
                  ),
                ),
              ),
              
              // Поле названия
              Positioned(
                left: 178,
                top: 24,
                child: Container(
                  width: 217,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 0),
                  decoration: ShapeDecoration(
                    color: AppColors.inputBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontSize: 16,
                      fontFamily: 'Instrument Sans',
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      letterSpacing: 0.25,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Название',
                      hintStyle: TextStyle(
                        color: AppColors.inputText,
                        fontSize: 16,
                        fontFamily: 'Instrument Sans',
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                        letterSpacing: 0.25,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              
              // Поле описания
              Positioned(
                left: 178,
                top: 77,
                child: Container(
                  width: 217,
                  height: 158,
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 10),
                  decoration: ShapeDecoration(
                    color: AppColors.inputBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: TextField(
                    controller: _descriptionController,
                    style: const TextStyle(
                      color: AppColors.inputText,
                      fontSize: 16,
                      fontFamily: 'Instrument Sans',
                      fontWeight: FontWeight.w400,
                      height: 1.25,
                      letterSpacing: 0.25,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Описание',
                      hintStyle: TextStyle(
                        color: AppColors.inputText,
                        fontSize: 16,
                        fontFamily: 'Instrument Sans',
                        fontWeight: FontWeight.w400,
                        height: 1.25,
                        letterSpacing: 0.25,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    maxLines: 7,
                  ),
                ),
              ),
              
              // Кнопка сохранения
              Positioned(
                left: 284,
                top: 244,
                child: GestureDetector(
                  onTap: _save,
                  child: Container(
                    width: 110,
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: ShapeDecoration(
                      color: AppColors.secondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        'Сохранить',
                        style: AppTextStyles.bodyLarge,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}