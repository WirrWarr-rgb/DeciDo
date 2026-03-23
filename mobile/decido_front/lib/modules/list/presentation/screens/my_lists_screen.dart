

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../config/router/route_names.dart';
import '../../../shared/widgets/custom_button.dart';

class MyListsScreen extends StatelessWidget {
  const MyListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои списки'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push(RouteNames.createList);
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                Icons.list,
                color: Theme.of(context).primaryColor,
              ),
              title: Text('Список ${index + 1}'),
              subtitle: Text('${(index + 1) * 5} элементов'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.push('/list/${index + 1}');
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push(RouteNames.createList);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}