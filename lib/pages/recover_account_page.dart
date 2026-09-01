import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

// import '../models/user_model.dart';
import '../pages/home_page.dart';
import '../pages/login_page.dart';
import '../services/backup_service.dart';
import '../services/hive_service.dart';
import '../services/user_service.dart';

class RecoverAccountPage extends StatefulWidget {
  const RecoverAccountPage({super.key});

  @override
  State<RecoverAccountPage> createState() => _RecoverAccountPageState();
}

class _RecoverAccountPageState extends State<RecoverAccountPage> {
  final _seedController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _backupService = BackupService();
  final _formKey = GlobalKey<FormState>();

  String? _backupFilePath;
  // String? _recoveredUsername;
  String? _recoveredUserId;
  bool _isLoading = false;

  @override
  void dispose() {
    _seedController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickBackupFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select backup file to recover account',
      );
      if (result == null || result.files.single.path == null) {
        return;
      }

      final path = result.files.single.path!;
      final parsed = await _backupService.parseBackupFile(path);
      setState(() {
        _backupFilePath = path;
        _recoveredUserId = parsed['userId'] as String?;
        // _recoveredUsername = parsed['username'] as String?;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup file loaded successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load backup file: $e')),
      );
    }
  }

  Future<void> _restoreAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_backupFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a backup file first')),
      );
      return;
    }

    final seedPhrase = _seedController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    if (seedPhrase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seed phrase is required')),
      );
      return;
    }

    if (_recoveredUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup file is not loaded or invalid')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _backupService.restoreFromBackup(_backupFilePath!, seedPhrase: seedPhrase, newPassword: password);
      final user = HiveService.getUsersBox().get(_recoveredUserId!);
      if (user != null) {
        await UserService().setLoggedInUser(user);
        print('✅ User ${user.username} logged in successfully after recovery');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account recovered successfully')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage(title: 'Welcome back: ${user.username}', user: user)),
          );
          return;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account recovered. Please sign in.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recovery failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      appBar: AppBar(
        title: const Text('Recover Account'),
        backgroundColor: const Color(0xFF6B4F3A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Backup File'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4F3A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _pickBackupFile,
              ),
              const SizedBox(height: 16),
              if (_backupFilePath != null) ...[
                Text('Selected backup file:', style: TextStyle(color: Colors.brown[800], fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_backupFilePath!, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 12),
              ],
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _seedController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Seed Phrase',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your seed phrase',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Seed phrase is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                        hintText: 'Enter a new password',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Password is required';
                        }
                        if (value.trim().length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(),
                        hintText: 'Repeat the password',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value.trim() != _passwordController.text.trim()) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _restoreAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4F3A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Restore Account', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      child: const Text('Back to Login', style: TextStyle(decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
