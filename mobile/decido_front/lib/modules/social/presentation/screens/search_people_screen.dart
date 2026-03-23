

import 'package:flutter/material.dart';

class SearchPeopleScreen extends StatefulWidget {
  const SearchPeopleScreen({super.key});

  @override
  State<SearchPeopleScreen> createState() => _SearchPeopleScreenState();
}

class _SearchPeopleScreenState extends State<SearchPeopleScreen> {
  final _searchController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск людей'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Введите никнейм',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                // TODO: Поиск пользователей
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text('user${index + 1}'),
                    subtitle: Text('user${index + 1}@example.com'),
                    trailing: ElevatedButton(
                      onPressed: () {
                        // TODO: Отправить заявку в друзья
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Заявка отправлена'),
                          ),
                        );
                      },
                      child: const Text('Добавить'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}