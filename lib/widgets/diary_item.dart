import 'package:flutter/material.dart';
import '../models/diary_model.dart';

class DiaryItem extends StatelessWidget {
  final DiaryModel diaryModel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const DiaryItem({
    super.key,
    required this.diaryModel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(diaryModel.title),
      subtitle: Text(
        "Created: ${diaryModel.createdAt.toLocal()}",
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
          IconButton(icon: const Icon(Icons.delete), onPressed: onDelete),
        ],
      ),
    );
  }
}
