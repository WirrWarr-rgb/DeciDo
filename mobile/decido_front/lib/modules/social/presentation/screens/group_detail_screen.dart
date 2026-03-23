

import 'package:flutter/material.dart';
import '../../../../core/theme/app_text_styles.dart';

class GroupDetailScreen extends StatelessWidget {
  final String groupId;
  
  const GroupDetailScreen({
    super.key,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали группы'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Группа #$groupId',
              style: AppTextStyles.headline1,
            ),
            const SizedBox(height: 16),
            Text(
              'Здесь будет информация о группе',
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}