import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../pages/diary_content_page.dart';
import '../models/diary_model.dart';
import '../services/hive_service.dart';
import '../widgets/diary_item.dart';

class DiaryListPage extends StatefulWidget {
  const DiaryListPage({super.key});

  @override
  State<DiaryListPage> createState() => _DiaryListPageState();
}

class _DiaryListPageState extends State<DiaryListPage> {
   final _editController = TextEditingController();
  late final Box<DiaryModel> _box;

  @override
  void initState() {
    super.initState();
    _box = HiveService.getDiariesBox();
  }

  void _addNote() {
  }

  void _editNote(int index, DiaryModel oldNote) {
    final selectedDate = DateTime.parse(oldNote.title);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiaryContentPage(date: selectedDate),
      ),
    );
  }

  void _deleteNote(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this diary entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _box.deleteAt(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Diary")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _editController,
                    decoration: const InputDecoration(hintText: "Enter content"),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _addNote),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: _box.listenable(),
              builder: (context, Box<DiaryModel> box, _) {
                if (box.isEmpty) {
                  return const Center(child: Text("No diary was found yet!"));
                }
                return ListView.builder(
                  itemCount: box.length,
                  itemBuilder: (context, index) {
                    final diaryData = box.getAt(index)!;
                    return DiaryItem(
                      diaryModel: diaryData,
                      onEdit: () => _editNote(index, diaryData),
                      onDelete: () => _deleteNote(index),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
