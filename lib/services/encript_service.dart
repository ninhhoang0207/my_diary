import 'dart:convert';
import 'dart:typed_data';
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncriptService {
  final storage = const FlutterSecureStorage();

  /// 🔸 Tạo seed phrase (người dùng backup)
  String generateSeedPhrase() {
    return bip39.generateMnemonic();
  }

  /// 🔸 Sinh private key từ seed phrase
  Uint8List deriveKeyFromSeed(String seedPhrase) {
    final seed = bip39.mnemonicToSeed(seedPhrase);
    // Dùng SHA256 để rút gọn còn 32 bytes (AES key)
    final hash = sha256.convert(seed);
    return Uint8List.fromList(hash.bytes);
  }

  /// 🔸 Mã hoá dữ liệu bằng AES-CBC
  String encryptData(String plaintext, Uint8List key) {
    final iv = Uint8List(16); // có thể random nếu muốn
    final cipher = CBCBlockCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(key), iv));

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final padded = _pkcs7Pad(input, cipher.blockSize);
    final output = Uint8List(padded.length);

    for (int offset = 0; offset < padded.length;) {
      offset += cipher.processBlock(padded, offset, output, offset);
    }

    return base64Encode(output);
  }

  Future getPrivateKeyByUserId(String userId) async {
    var privateKey = await storage.read(key: 'private_key_$userId') ?? '';
    if (privateKey.isEmpty || privateKey == '') {
      print("Private Key is empty, cannot get private key.");
      return null;
    }
    privateKey = privateKey.replaceAll("[", "").replaceAll("]", "");

    // 2️⃣ Tách chuỗi theo dấu ","
    List<String> stringList = privateKey.split(",");

    // 3️⃣ Ép từng phần tử sang int
    List<int> intList = stringList.map((e) => int.parse(e.trim())).toList();

    // 4️⃣ Tạo Uint8List
    Uint8List bytes = Uint8List.fromList(intList);

    return bytes;
  }

  Future<String> encryptDataWithUserId(String plaintext, String userId) async {
    if (userId.isEmpty || userId == '') {
      print("User ID is empty, cannot encrypt data.");

      return '';
    }

    var privateKey =  await getPrivateKeyByUserId(userId);

    if (privateKey.isEmpty || privateKey == '') {
      print("Private Key is empty, cannot encrypt data.");

      return '';
    }

    return encryptData(plaintext, privateKey);
  }

  String decryptData(String cipherText, Uint8List key) {
    final iv = Uint8List(16);
    final cipher = CBCBlockCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(key), iv));

    final input = base64Decode(cipherText);
    final output = Uint8List(input.length);

    for (int offset = 0; offset < input.length;) {
      offset += cipher.processBlock(input, offset, output, offset);
    }

    final unpadded = _pkcs7Unpad(output);
    return utf8.decode(unpadded);
  }

  Future<String> decriptDataWithUserId(String cipherText, String userId) async {
    if (userId.isEmpty || userId == '') {
      print("User ID is empty, cannot decrypt data.");

      return '';
    }

    var privateKey =  await getPrivateKeyByUserId(userId);

    if (privateKey.isEmpty || privateKey == '') {
      print("Private Key is empty, cannot decrypt data.");

      return '';
    }

    return decryptData(cipherText, privateKey);
  }

  Uint8List _pkcs7Pad(Uint8List data, int blockSize) {
    final padLen = blockSize - (data.length % blockSize);
    return Uint8List.fromList([...data, ...List.filled(padLen, padLen)]);
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    final padLen = data.last;
    return data.sublist(0, data.length - padLen);
  }

  /// 🔸 Lưu dữ liệu mã hoá vào local storage
  Future<void> saveEncrypted(String key, String data) async {
    await storage.write(key: key, value: data);
  }

  Future<String?> readEncrypted(String key) async {
    return await storage.read(key: key);
  }

  createAndSaveUserPrivateKey(String userId, String seedPhrase) async {
    final privateKey = deriveKeyFromSeed(seedPhrase).toString();

    await storage.write(key: 'private_key_$userId', value: privateKey);
  }
}