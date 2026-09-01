import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

class UserService {
  /// Tạo salt ngẫu nhiên (base64 để lưu gọn)
  String generateSalt([int length = 16]) {
    final rnd = Random.secure();
    final saltBytes = List<int>.generate(length, (_) => rnd.nextInt(256));
    return base64.encode(saltBytes);
  }

  /// Hash SHA-256 + salt
  String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt); // nối mật khẩu + salt
    final digest = sha256.convert(bytes);

    return digest.toString(); // chuỗi hex
  }

  Future<void> setLoggedInUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', user.username);
    await prefs.setString('user_id', user.id);
    print("User ${user.username} with ID ${user.id} is set as logged in.");
  }

  Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('username') ?? '';
  }

  Future<String> getUserId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString('user_id') ?? '';
  }
}
