import 'package:decido_front/modules/shared/widgets/custom_button.dart';
import 'package:decido_front/modules/shared/widgets/custom_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/custom_drawer.dart';
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
  List<ListModel> _lists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  void _loadLists() {
    setState(() {
      _lists = _repository.getAllLists();
      _isLoading = false;
    });
  }

  Future<void> _createNewList() async {
    try {
      if (!_repository.canCreateList()) {
        _showError('Достигнут лимит списков (${ListRepository.maxLists})');
        return;
      }

      final uniqueName = _repository.generateUniqueListName('Новый список');
      final newList = _repository.createList(uniqueName);
      _repository.createItem(newList.id, 'Первый элемент');

      if (mounted) {
        context.push('/edit-list/${newList.id}').then((_) => _loadLists());
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _editList(ListModel list) {
    context.push('/edit-list/${list.id}').then((_) => _loadLists());
  }

void _deleteList(ListModel list) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(20),
        decoration: ShapeDecoration(
          color: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              list.name,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontFamily: 'Instrument Sans',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Вы уверены, что хотите удалить этот список?',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontFamily: 'Instrument Sans',
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 40,
                      decoration: ShapeDecoration(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(
                            width: 2,
                            color: AppColors.textSecondary,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Нет, отменить',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _repository.deleteList(list.id);
                      Navigator.pop(context);
                      _loadLists();
                    },
                    child: Container(
                      height: 40,
                      decoration: ShapeDecoration(
                        color: AppColors.secondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'Удалить',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Color _getListColor(int index) {
    final colors = [
      AppColors.secondary,  // Оранжевый
      AppColors.primary,     // Зеленый
      AppColors.tertiary,    // Темно-синий
      AppColors.inputBackground, // Серо-голубой
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      title: 'Мои списки',
      menuIconColor: AppColors.textPrimary,
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

            // Список
            Positioned(
              left: 41,
              top: 110,
              child: Container(
                width: 355,
                height: 650,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _lists.isEmpty
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
                                  textStyle: AppTextStyles.buttonBig,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _lists.length,
                            itemBuilder: (context, index) {
                              final list = _lists[index];
                              final itemsCount = _repository.getItemsByListId(list.id).length;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                child: GestureDetector(
                                  onTap: () => _editList(list),
                                  child: Row(
                                    children: [
                                      // Цветная иконка списка
                                      Container(
                                        width: 66,
                                        height: 66,
                                        decoration: ShapeDecoration(
                                          color: _getListColor(index),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        //child: Center(
                                        //  child: Text(
                                        //    '${index + 1}',
                                        //    style: const TextStyle(
                                        //      color: AppColors.background,
                                        //      fontSize: 24,
                                        //      fontWeight: FontWeight.bold,
                                        //    ),
                                        //  ),
                                        //),
                                      ),
                                      const SizedBox(width: 15),
                                      // Информация о списке
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              list.name,
                                              style: AppTextStyles.bodyGeneral,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '$itemsCount элементов',
                                              style: TextStyle(
                                                color: AppColors.textSecondary,
                                                fontSize: 14,
                                                fontFamily: 'Instrument Sans',
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      // Кнопки редактирования и удаления// Кнопки редактирования и удаления
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: SvgPicture.asset(
                                              'assets/icons/edit_pen_icon.svg',
                                              width: 30,
                                              height: 30,
                                            ),
                                            onPressed: () => _editList(list),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          const SizedBox(width: 2.5),
                                          IconButton(
                                            icon: SvgPicture.asset(
                                              'assets/icons/delete_bin_icon.svg',
                                              width: 35,
                                              height: 35,
                                              colorFilter: const ColorFilter.mode(
                                                AppColors.secondary,
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                            onPressed: () => _deleteList(list),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),

            // Кнопка добавления списка
            Positioned(
              left: 176,
              top: 775,
              child: GestureDetector(
                onTap: _createNewList,
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