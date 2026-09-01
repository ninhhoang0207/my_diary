import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';
import '../models/diary_model.dart';
import 'hive_service.dart';
import 'user_service.dart';
import 'encript_service.dart';

class BackupService {
  final _userService = UserService();
  final _encryptService = EncriptService();
  /// 📤 Export user-specific database to JSON file
  Future<String> exportDatabase(String userId) async {
    try {
      final usersBox = HiveService.getUsersBox();
      final diariesBox = HiveService.getDiariesBox();
      final username = usersBox.values
          .firstWhere(
            (user) => user.id == userId,
            orElse: () => UserModel(id: '', username: '', password: '', salt: ''),
          )
          .username;

      // Export only diaries for this user
      final List<Map<String, dynamic>> diaries = [];
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

      // Create backup data structure
      final backupData = {
        'version': '1.0',
        'exportedAt': DateTime.now().toIso8601String(),
        'userId': userId,
        'username': username,
        'diaries': diaries,
      };

      // Get documents directory and save JSON file
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${dir.path}/diary_backup_${userId}_$timestamp.json';
      final file = File(filePath);

      final jsonString = jsonEncode(backupData);
      await file.writeAsString(jsonString);

      print('✅ Database exported for user $userId to: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error exporting database: $e');
      throw Exception('Failed to export database: $e');
    }
  }

  /// 📥 Import user-specific database from JSON file
  Future<bool> importDatabase(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found: $filePath');
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate backup structure
      if (backupData['diaries'] == null) {
        throw Exception('Invalid backup file format');
      }

      final userId = backupData['userId'] as String?;
      if (userId == null) {
        throw Exception('Backup file does not contain userId');
      }

      return _importBackupDiaries(backupData);
    } catch (e) {
      print('❌ Error importing database: $e');
      throw Exception('Failed to import database: $e');
    }
  }

  Future<Map<String, dynamic>> parseBackupFile(String filePath) async {
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

    final username = backupData['username'] as String? ?? '';

    return {
      'userId': userId,
      'username': username,
      'backupData': backupData,
    };
  }

  Future<bool> restoreFromBackup(String filePath, {required String seedPhrase, String? newPassword}) async {
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

      if (seedPhrase.isEmpty) {
        throw Exception('Seed phrase is required for account recovery');
      }
      if (newPassword == null || newPassword.isEmpty) {
        throw Exception('New password is required for account recovery');
      }

      final backupUsername = backupData['username'] as String?;
      await _encryptService.createAndSaveUserPrivateKey(userId, seedPhrase);
      await _ensureUserRecord(userId, backupUsername, newPassword);
      await _clearUserDiaries(userId);
      await _importBackupDiaries(backupData);

      print('✅ Database restored from backup: $filePath');
      return true;
    } catch (e) {
      print('❌ Error restoring from backup: $e');
      throw Exception('Failed to restore from backup: $e');
    }
  }

  Future<void> _clearUserDiaries(String userId) async {
    final diariesBox = HiveService.getDiariesBox();
    final keysToDelete = <dynamic>[];
    for (var key in diariesBox.keys) {
      final diary = diariesBox.get(key) as DiaryModel;
      if (diary.userId == userId) {
        keysToDelete.add(key);
      }
    }
    for (var key in keysToDelete) {
      await diariesBox.delete(key);
    }
  }

  Future<void> _ensureUserRecord(String userId, String? backupUsername, String newPassword) async {
    final usersBox = HiveService.getUsersBox();
    final existingUser = usersBox.get(userId);
    final salt = _userService.generateSalt();
    final hashedPassword = _userService.hashPassword(newPassword, salt);

    if (existingUser == null) {
      final username = backupUsername != null && backupUsername.isNotEmpty
          ? backupUsername
          : 'recovered_${userId.substring(0, 8)}';
      final user = UserModel(
        id: userId,
        username: username,
        password: hashedPassword,
        salt: salt,
      );
      await usersBox.put(userId, user);
    } else {
      existingUser.username = backupUsername != null && backupUsername.isNotEmpty
          ? backupUsername
          : existingUser.username;
      existingUser.password = hashedPassword;
      existingUser.salt = salt;
      await usersBox.put(userId, existingUser);
    }
  }

  Future<bool> _importBackupDiaries(Map<String, dynamic> backupData) async {
    final diariesBox = HiveService.getDiariesBox();
    final diariesList = backupData['diaries'] as List<dynamic>;

    for (var diaryData in diariesList) {
      final diaryMap = diaryData as Map<String, dynamic>;
      final diary = DiaryModel(
        id: diaryMap['id'] as int,
        title: diaryMap['title'] as String,
        content: diaryMap['content'] as String,
        createdAt: DateTime.parse(diaryMap['createdAt'] as String),
        userId: diaryMap['userId'] as String,
      );
      await diariesBox.put('${diary.userId}-${diary.title}', diary);
    }
    return true;
  }

  /// 📋 Get JSON string of user-specific database backup (without saving to file)
  Future<String> getBackupJson(String userId) async {
    try {
      final usersBox = HiveService.getUsersBox();
      final diariesBox = HiveService.getDiariesBox();
      final username = usersBox.values
          .firstWhere(
            (user) => user.id == userId,
            orElse: () => UserModel(id: '', username: '', password: '', salt: ''),
          )
          .username;

      // Get only diaries for this user
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

      return jsonEncode(backupData);
    } catch (e) {
      print('❌ Error getting backup JSON: $e');
      throw Exception('Failed to get backup JSON: $e');
    }
  }

  /// 📁 Get list of backup files for specific user
  Future<List<String>> getBackupFilesList(String userId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupFiles = <String>[];

      final files = dir.listSync();
      for (var file in files) {
        if (file.path.contains('diary_backup_${userId}_') && file.path.endsWith('.json')) {
          backupFiles.add(file.path);
        }
      }

      backupFiles.sort((a, b) => b.compareTo(a)); // Sort by newest first
      return backupFiles;
    } catch (e) {
      print('❌ Error getting backup files list: $e');
      return [];
    }
  }

  /// 🗑️ Delete a backup file
  Future<bool> deleteBackupFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('✅ Backup file deleted: $filePath');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error deleting backup file: $e');
      return false;
    }
  }
}
