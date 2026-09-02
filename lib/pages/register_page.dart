import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../flavors.dart';
import '../models/user_model.dart';
import '../pages/login_page.dart';
import '../pages/recover_account_page.dart';
import '../services/hive_service.dart';
import '../services/user_service.dart';
import '../services/encript_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final Box<UserModel> _userBox;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _seedphaseController = TextEditingController();
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _userBox = HiveService.getUsersBox();
  }

  void _register() async {
    final username = _usernameController.text;
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final seedPhrase = _seedphaseController.text;

    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty || seedPhrase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    // Check if username already exists
    final defaultUser = UserModel(id: '-1', username: '', password: '', salt: '');
    final user = _userBox.values.firstWhere(
      (user) => user.username == username,
      orElse: () => defaultUser,
    );
    if (user.id != '-1') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username already exists')),
      );
      return;
    }

    // Show confirmation dialog before submitting
  final confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Registration'),
      content: const Text('Are you sure you want to register with these details?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

    // Add your registration logic here
    final salt = UserService().generateSalt();
    final hashedPassword = UserService().hashPassword(password, salt);
    final newUser = UserModel(
      // id: const Uuid().v4(),
      id: const Uuid().v4(),
      username: username,
      password: hashedPassword,
      salt: salt
    );
    _userBox.add(newUser);

    // save secret key
    await EncriptService().createAndSaveUserPrivateKey(newUser.id, seedPhrase);

    // Show success notification
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registration successful!')),
    );

    // Redirect to login after a short delay
    Future.delayed(const Duration(seconds: 1), () {
      _goToLogin();
    });
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginPage(title: F.title),
      ),
    );
  }

  void _generateSeedPhrase() {
    final seedPhrase = EncriptService().generateSeedPhrase();
    _seedphaseController.text = seedPhrase;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Generated Seed Phrase: $seedPhrase')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: CustomPaint(
              painter: _NotebookPainter(),
              child: Container(
                padding: const EdgeInsets.fromLTRB(48, 32, 24, 32),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Diary Notebook',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: Colors.brown[800],
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign up to your private diary',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown[400],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Username',
                              style: TextStyle(fontSize: 12, color: Colors.black87)),
                          const SizedBox(height: 6),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.0),
                            ),
                            child: TextField(
                              controller: _usernameController,
                              style: const TextStyle(fontSize: 16),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                                border: InputBorder.none,
                                hintText: 'Enter your username',
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ]
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Password',
                              style: TextStyle(fontSize: 12, color: Colors.black87)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: _obscureText,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    border: InputBorder.none,
                                    // hintText: '••••••••',
                                    hintText: '********',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                                color: Colors.brown[400],
                                onPressed: () => setState(() => _obscureText = !_obscureText),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Re-Password',
                              style: TextStyle(fontSize: 12, color: Colors.black87)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureText,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    border: InputBorder.none,
                                    hintText: '********',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      color: Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Seed Phrase',
                              style: TextStyle(fontSize: 12, color: Colors.black87)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _seedphaseController,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                                    border: InputBorder.none,
                                    hintText: 'Seed Phrase',
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.generating_tokens),
                                color: Colors.brown[400],
                                onPressed: () {
                                  _generateSeedPhrase();
                                  Clipboard.setData(ClipboardData(text: _seedphaseController.text));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Seed Phrase copied to clipboard')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4F3A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 4,
                ),
                child: const Text('Register', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
             const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RecoverAccountPage()),
                        );
                      },
                      child: const Text('Recover account using backup & seed phrase',
                          style: TextStyle(decoration: TextDecoration.underline)),
                    ),

             const SizedBox(height: 12),
            TextButton(
              onPressed: _goToLogin,
              child: const Text('Go to Login',
                  style: TextStyle(decoration: TextDecoration.underline)),
            ),
        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double gap = 28;
    final Paint linePaint = Paint()
      ..color = const Color(0xFFE1E6F0)
      ..strokeWidth = 1;

    final Paint marginPaint = Paint()
      ..color = const Color(0xFFDD6B6B)
      ..strokeWidth = 2;

    // draw horizontal ruled lines
    for (double y = 24; y < size.height; y += gap) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), linePaint);
    }

    // draw left margin line
    canvas.drawLine(Offset(44, 8), Offset(44, size.height - 8), marginPaint);

    // draw faint border
    final rectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.brown.withOpacity(0.15)
      ..strokeWidth = 1.2;
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 6, size.width - 12, size.height - 12), const Radius.circular(12));
    canvas.drawRRect(r, rectPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}