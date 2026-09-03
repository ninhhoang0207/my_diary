import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:hive/hive.dart';
import 'package:flutter/material.dart';

import '../models/diary_model.dart';
import '../services/encript_service.dart';
import '../services/user_service.dart';
import '../services/hive_service.dart';

class DiaryContentPage extends StatefulWidget {
  final DateTime date;
  final bool isEditMode;
  final String? userId;

  const DiaryContentPage({super.key, required this.date, this.isEditMode = false, this.userId});

  @override
  State<DiaryContentPage> createState() => _DiaryContentPageState();
}

class _DiaryContentPageState extends State<DiaryContentPage> {
  bool _isEditMode = false;
  String userId = '';
  late quill.QuillController _quillController;
  late final Box<DiaryModel> _box;
  late DiaryModel? diary = DiaryModel(id: 0, title: '', content: '', createdAt: DateTime.now(), userId: userId);

  @override
  void initState() {
    super.initState();
    _quillController = quill.QuillController.basic();
    _quillController.readOnly = !_isEditMode;

    _box = HiveService.getDiariesBox();
    UserService().getUserId().then((id) {
      setState(() {
        userId = id;
        try {
          final String title = getSelectedDateString();
          final newDiary = DiaryModel(id: 0, title: title, content: '', createdAt: DateTime.now(), userId: userId);
          final diaryId = getDiaryId();
          diary = _box.get(diaryId, defaultValue: newDiary);
        } catch (e) {
          print("Error loading diary content: $e");
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final String pageTitle = '${getDayOfWeek()}, ${getFomattedDate()}';
    final diaryId = getDiaryId();
    loadDiaryContent();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        actions: [
          IconButton(
            icon: Icon(_isEditMode ? Icons.check : Icons.edit),
            tooltip: _isEditMode ? 'Save' : 'Edit',
            onPressed: () {
              if (_isEditMode) {
                // Lưu nội dung khi chuyển từ chế độ chỉnh sửa sang chế độ xem
                 if (!_quillController.document.isEmpty()) {
                  final diaryContent = jsonEncode(_quillController.document.toDelta().toJson());
                  EncriptService().encryptDataWithUserId(diaryContent, userId).then((encriptData) {
                    final String title = getSelectedDateString();
                    final diaryData = DiaryModel(
                      id: DateTime.now().millisecondsSinceEpoch,
                      title: title,
                      content: encriptData,
                      createdAt: DateTime.now(),
                      userId: userId,
                    );
                    _box.put(diaryId, diaryData);
                    diary = diaryData;
                    
                    loadDiaryContent();
                  });
                }
              }
              setState(() {
                _isEditMode = !_isEditMode;
                _quillController.readOnly = !_isEditMode;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isEditMode)
              quill.QuillSimpleToolbar(
                controller: _quillController,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: quill.QuillEditor.basic(
                  controller: _quillController,
                  config: const quill.QuillEditorConfig(
                    // autoFocus: true,
                    expands: true,
                    padding: EdgeInsets.all(8.0),
                    enableSelectionToolbar: true
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  String getSelectedDateString() {
    final String dateString = '${widget.date.toLocal()}'.split(' ')[0];
    return dateString;
  }

  String getFomattedDate() {
    final dt = widget.date.toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  String getDayOfWeek() {
    final dt = widget.date.toLocal();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[dt.weekday - 1];
  }

  String getDiaryId() {
    final String diaryId = '$userId-${getSelectedDateString()}';
    return diaryId;
  }

  void loadDiaryContent() {
    try {
      final encriptDiaryContent = diary?.content ?? '';

      if (encriptDiaryContent.isNotEmpty && encriptDiaryContent != '') {
        EncriptService().decriptDataWithUserId(encriptDiaryContent, userId).then((decriptData) {
          _quillController.document = decriptData.isNotEmpty
            ? quill.Document.fromJson(jsonDecode(decriptData))
            : quill.Document();
        });
      } else {
        _quillController.document = quill.Document();
      }
    } catch (e) {
      print("Error loading diary content: $e");
    }
  }
}