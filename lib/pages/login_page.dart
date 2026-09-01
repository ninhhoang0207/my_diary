import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:hive/hive.dart';

import '../pages/home_page.dart';
import '../pages/register_page.dart';
import '../pages/recover_account_page.dart';
import '../services/hive_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();

}

class _LoginPageState extends State<LoginPage> {
  late final Box<UserModel> _userBox;
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscure = true;
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _canAuthenticate = false;

  @override
  void initState() {
    super.initState();
    _userBox = Hive.box<UserModel>('usersBox');
    // load users for selection
    _users = _userBox.values.toList();

    if (_users.isNotEmpty) _selectedUser = _users.first;
    _initBiometrics();
    
    if (_users.isEmpty) {
     
     
      WidgetsBinding.instance.addPostFrameCallback((_) { // Fix bug cannot redirect to register page immediately
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No users found. Redirecting to registration page...')),
        );

        //  Future.delayed(const Duration(seconds: 1), () {
        //     if (mounted) _register();
        //   });
      });
    }
  }

  Future<void> _initBiometrics() async {
    bool canAuth = false;
    try {
      canAuth = await _localAuth.isDeviceSupported() || await _localAuth.canCheckBiometrics;
    } catch (e) {
      canAuth = false;
    }
    if (mounted) setState(() => _canAuthenticate = canAuth);
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to sign in',
      );

      if (!didAuthenticate) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Biometric authentication failed')),
          );
        }

        return;
      }

      // On success, try to fetch last logged-in user id from SharedPreferences
      final defaultUser = UserModel(id: '-1', username: '', password: '', salt: '');
      final user = _selectedUser ?? defaultUser;

      if (_selectedUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No user selected for biometric login')),
          );
        }
        return;
      }

      if (user.id != '-1') {
        await UserService().setLoggedInUser(user);
        if (mounted) {
          _redirectToHomePage(user);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No previously logged-in user found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Biometric error: $e')),
        );
      }
    }
  }

  void _login() {
    final password = _passwordController.text;

    final defaultUser = UserModel(id: '-1', username: '', password: '', salt: '');
    final user = _selectedUser ?? defaultUser;

    try {
      if (user.id != -1 &&
          user.password == UserService().hashPassword(password, user.salt)) {

        UserService().setLoggedInUser(user);
        // print("Login successful for user: ${user.id}");
        _redirectToHomePage(user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid username or password')),
        );
      }
    } catch (e) {
      print("Error run here $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login Error!')),
      );
    }
  }

  void _redirectToHomePage(UserModel user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(title: 'Welcome, ${user.username}', user: user),
      ),
    );
  }

  void _register() {
    // Show success message or navigate as needed
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }

  // Clear all Hive data (for testing purposes)
  
  void _clearData() async {
    await HiveService.clearAllBoxes();
    

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All data cleared!')),
    );
  }
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // subtle background color to look like paper
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
                      'Sign in to your private diary',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown[400],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Username field on paper (no border so lines show)
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
                            child: _users.isNotEmpty
                                ? DropdownButtonFormField<UserModel>(
                                    value: _selectedUser,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                      border: InputBorder.none,
                                    ),
                                    items: _users
                                        .map((u) => DropdownMenuItem<UserModel>(
                                              value: u,
                                              child: Text(u.username),
                                            ))
                                        .toList(),
                                    onChanged: (u) => setState(() {
                                          _selectedUser = u;
                                          if (u != null) _usernameController.text = u.username;
                                        }),
                                  )
                                : TextField(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password field
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
                                  obscureText: _obscure,
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
                                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                color: Colors.brown[400],
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Login button styled like leather bookmark, with optional biometrics
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B4F3A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 4,
                            ),
                            child: const Text('Sign In', style: TextStyle(fontSize: 16, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Visibility(
                          visible: _canAuthenticate,
                          child: Material(
                            color: Colors.transparent,
                            child: IconButton(
                              onPressed: _authenticateWithBiometrics,
                              iconSize: 36,
                              icon: const Icon(Icons.fingerprint),
                              tooltip: 'Sign in with biometrics',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _register,
                      child: const Text('Create an account',
                          style: TextStyle(decoration: TextDecoration.underline)),
                    ),

                    const SizedBox(height: 8),
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
                    Visibility(
                      visible: kDebugMode,
                      child: TextButton(
                        onPressed: _clearData,
                        child: const Text('Clear Data',
                            style: TextStyle(decoration: TextDecoration.underline)),
                      ),
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

/// Simple painter that draws faint ruled lines and a left red margin to mimic notebook paper.
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