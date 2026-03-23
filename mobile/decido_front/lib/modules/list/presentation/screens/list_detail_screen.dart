

import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class ListDetailScreen extends StatelessWidget {
  final String listId;
  
  const ListDetailScreen({
    super.key,
    required this.listId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали списка'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Список #$listId',
              style: AppTextStyles.headline1,
            ),
            const SizedBox(height: 16),
            Text(
              'Здесь будут элементы списка',
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}