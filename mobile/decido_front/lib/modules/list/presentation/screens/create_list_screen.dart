

import 'package:flutter/material.dart';

class CreateListScreen extends StatelessWidget {
  const CreateListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать список'),
      ),
      body: const Center(
        child: Text('Форма создания списка'),
      ),
    );
  }
}