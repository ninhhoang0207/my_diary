import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppLogger {
  static Future<Directory> _getLogDirectory() async {
    final appSupportDir = await getApplicationSupportDirectory();
    final logDir = Directory('${appSupportDir.path}/logs');

    if (!await logDir.exists()) {
      await logDir.create(recursive: true);
    }

    return logDir;
  }

  static Future<File> _getLogFile() async {
    final dir = await _getLogDirectory();
    return File('${dir.path}/my_diary_log.txt');
  }

  static Future<void> log(String message) async {
    final file = await _getLogFile();
    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $message\n';

    await file.writeAsString(line, mode: FileMode.append);
  }

  static Future<String> readAll() async {
    final file = await _getLogFile();
    if (!await file.exists()) return 'No log file yet';
    return await file.readAsString();
  }
}