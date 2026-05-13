import 'package:flutter/material.dart';
import 'custom_app_bar.dart';
import 'custom_drawer.dart';

class CustomScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool showBackButton;
  final Color? menuIconColor;
  final bool resizeToAvoidBottomInset;

  const CustomScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.showBackButton = false,
    this.menuIconColor,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: Stack(
        children: [
          // Основное содержимое
          Positioned.fill(
            child: body,
          ),
          // AppBar поверх содержимого
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomAppBar(
              title: title,
              actions: actions,
              showBackButton: showBackButton,
              menuIconColor: menuIconColor,
            ),
          ),
        ],
      ),
    );
  }
}