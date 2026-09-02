import 'package:hive/hive.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../flavors.dart';
import '../models/user_model.dart';
import '../models/diary_model.dart';

class HiveService {
  static String get diariesBoxName => 'diariesBox_${F.name}';
  static String get usersBoxName => 'usersBox_${F.name}';

  static Future<void> init() async {
    Hive.registerAdapter(DiaryModelAdapter());
    await Hive.openBox<DiaryModel>(diariesBoxName);

    Hive.registerAdapter(UserModelAdapter());
    await Hive.openBox<UserModel>(usersBoxName);
  }

  static Box<DiaryModel> getDiariesBox() {
    try {
      return Hive.box<DiaryModel>(diariesBoxName);
    } catch (e) {
      print('❌ Error getting diaries box: $e');
      throw Exception('Diaries box not initialized: $e');
    }
  }

  static Box<UserModel> getUsersBox() {
    try {
      return Hive.box<UserModel>(usersBoxName);
    } catch (e) {
      print('❌ Error getting users box: $e');
      throw Exception('Users box not initialized: $e');
    }
  }

  static Future<void> clearAllBoxes() async {
    await Hive.box<DiaryModel>(diariesBoxName).clear();
    await Hive.box<UserModel>(usersBoxName).clear();
    // print("🧹 Đã xóa toàn bộ dữ liệu trong Hive boxes.");
  }

  /// 📤 Export user-specific database to JSON file
  static Future<String> exportDatabaseToFile(String userId) async {
    try {
      final usersBox = getUsersBox();
      final diariesBox = getDiariesBox();

      final username = usersBox.values
          .firstWhere(
            (user) => user.id == userId,
            orElse: () => UserModel(id: '', username: '', password: '', salt: ''),
          )
          .username;

      // Export only diaries for this user
      List<Map<String, dynamic>> diaries = [];
      for (var key in diariesBox.keys) {
        final diary = diariesBox.get(key) as DiaryModel;
        if (diary.userId == userId) {
          diaries.add({
            'id': diary.id,
            'title': diary.title,
            'content': diary.content,
            'createdAt': diary.createdAt.toIso8601String(),
            'userId': diary.userId,
          });
        }
      }

      final backupData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'userId': userId,
        'username': username,
        'diaries': diaries,
      };

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${dir.path}/diary_backup_${userId}_$timestamp.json';
      final file = File(filePath);

      final jsonString = jsonEncode(backupData);
      await file.writeAsString(jsonString);

      // print('✅ Database exported for user $userId to: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error exporting database: $e');
      throw Exception('Failed to export database: $e');
    }
  }

  /// � Export user-specific database to custom file path
  static Future<String> exportDatabaseToCustomPath(String userId, String customPath) async {
    try {
      final usersBox = getUsersBox();
      final diariesBox = getDiariesBox();

      final username = usersBox.values
          .firstWhere(
            (user) => user.id == userId,
            orElse: () => UserModel(id: '', username: '', password: '', salt: ''),
          )
          .username;

      // Export only diaries for this user
      List<Map<String, dynamic>> diaries = [];
      for (var key in diariesBox.keys) {
        final diary = diariesBox.get(key) as DiaryModel;
        if (diary.userId == userId) {
          diaries.add({
            'id': diary.id,
            'title': diary.title,
            'content': diary.content,
            'createdAt': diary.createdAt.toIso8601String(),
            'userId': diary.userId,
          });
        }
      }

      final backupData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'userId': userId,
        'username': username,
        'diaries': diaries,
      };

      final file = File(customPath);
      // Ensure parent directory exists
      final directory = file.parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final jsonString = jsonEncode(backupData);
      await file.writeAsString(jsonString);

      // print('✅ Database exported for user $userId to: $customPath');
      return customPath;
    } catch (e) {
      print('❌ Error exporting database: $e');
      throw Exception('Failed to export database: $e');
    }
  }
  static Future<bool> importDatabaseFromFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found: $filePath');
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (backupData['diaries'] == null) {
        throw Exception('Invalid backup file format');
      }

      final userId = backupData['userId'] as String?;
      if (userId == null) {
        throw Exception('Backup file does not contain userId');
      }

      final diariesBox = getDiariesBox();
      final diariesList = backupData['diaries'] as List<dynamic>;
      for (var diaryData in diariesList) {
        final diary = DiaryModel(
          id: diaryData['id'] as int,
          title: diaryData['title'] as String,
          content: diaryData['content'] as String,
          createdAt: DateTime.parse(diaryData['createdAt'] as String),
          userId: diaryData['userId'] as String,
        );
        await diariesBox.put('${diary.userId}-${diary.title}', diary);
      }

      // print('✅ Database imported successfully for user $userId from: $filePath');
      return true;
    } catch (e) {
      print('❌ Error importing database: $e');
      throw Exception('Failed to import database: $e');
    }
  }

  /// 📋 Get backup files list for specific user
  static Future<List<String>> getBackupFilesList(String userId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupFiles = <String>[];

      final files = dir.listSync();
      for (var file in files) {
        if (file.path.contains('diary_backup_${userId}_') && file.path.endsWith('.json')) {
          backupFiles.add(file.path);
        }
      }

      backupFiles.sort((a, b) => b.compareTo(a));
      return backupFiles;
    } catch (e) {
      // print('❌ Error getting backup files list: $e');
      return [];
    }
  }

  /// 🗑️ Delete a backup file
  static Future<bool> deleteBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        // print('✅ Backup file deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting backup file: $e');
      return false;
    }
  }
}
