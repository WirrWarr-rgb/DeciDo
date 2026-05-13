import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Color? menuIconColor;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.menuIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 52, left: 10, right: 33),
      child: Row(
        children: [
          // Кнопка меню или назад (X = 10, Y = 52, размер 37x37)
          SizedBox(
            width: 37,
            height: 37,
            child: showBackButton
                ? IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.arrow_back,
                      color: menuIconColor ?? AppColors.textPrimary,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  )
                : Builder(
                    builder: (context) => IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.menu,
                        color: menuIconColor ?? AppColors.textPrimary,
                        size: 24,
                      ),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),
          ),
          
          const SizedBox(width: 35), // Отступ до X = 82
          
          // Текст заголовка
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Действия справа
          if (actions != null) ...actions!,
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(92);
}