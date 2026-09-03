import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/user_model.dart';
import '../models/diary_model.dart';
import '../pages/diary_content_page.dart';
import '../pages/login_page.dart';
import '../services/hive_service.dart';
import '../services/log_service.dart';

class HomePage extends StatefulWidget {
  final String title;
  final UserModel user;
  const HomePage({super.key, required this.title, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Box<DiaryModel> _box;
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _box = HiveService.getDiariesBox();
  }

  String _formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String getPrettyDate(String date) {
    try {
      final dt = DateTime.parse(date).toLocal();
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final dayOfWeek = days[dt.weekday - 1];

      return '$dayOfWeek, ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e) {
      print("Error parsing date: $e");

      return date; // Return the original string if parsing fails
    }
  }

  void _openDiary(DiaryModel diary) {
    final date = DateTime.tryParse(diary.title);
    if (date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Invalid date format in diary title: ${diary.title}"),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryContentPage(
          date: date,
          isEditMode: false,
          userId: widget.user.id,
        ),
      ),
    );
  }

  void _createDiary() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiaryContentPage(
          date: DateTime.now(),
          isEditMode: true,
          userId: widget.user.id,
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DiaryContentPage(
            date: picked,
            isEditMode: true,
            userId: widget.user.id,
          ),
        ),
      );
    }
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _exportData() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final suggestedFileName =
          'diary_backup_${widget.user.id}_$timestamp.json';
      final filePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save diary backup',
        fileName: suggestedFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (filePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('⚠️ Export cancelled')));
        }
        return;
      }

      // Export to the selected location
      final exportedPath = await HiveService.exportDatabaseToCustomPath(
        widget.user.id,
        filePath,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Data exported successfully!\n$exportedPath'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      await AppLogger.log('Export error for user ${widget.user.id}: $e');

      if (mounted) {
        await AppLogger.log('Export error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      // Open file picker to select backup file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select backup file to import',
      );

      if (result == null) {
        // User cancelled the picker
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('⚠️ Import cancelled')));
        }
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        throw Exception('Invalid file path');
      }

      // Show confirmation dialog
      if (!mounted) return;

      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Import Backup'),
              content: const Text(
                'This will restore your diary from the backup file. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'Import',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('⚠️ Import cancelled')));
        }
        return;
      }

      // Import the backup
      await HiveService.importDatabaseFromFile(filePath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data imported successfully!'),
            duration: Duration(seconds: 3),
          ),
        );
        // Refresh the page
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Import failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Widget _buildSubFab({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Offset offset,
  }) {
    // Animated sub button that moves from main FAB to offset when _fabOpen true
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      right: _fabOpen ? 100 + offset.dx : 20,
      bottom: _fabOpen ? 100 + offset.dy : 20,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _fabOpen ? 1.0 : 0.0,
        child: FloatingActionButton(
          heroTag: tooltip,
          mini: true,
          onPressed: onTap,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF6B4F3A),
          tooltip: tooltip,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA),
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6B4F3A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: CustomPaint(
            painter: _NotebookPainter(),
            child: Container(
              padding: const EdgeInsets.fromLTRB(48, 24, 24, 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'My Diary',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.brown[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: _box.listenable(),
                      builder: (context, Box<DiaryModel> box, _) {
                        final diaries = box.values
                            .where((diary) => diary.userId == widget.user.id)
                            .toList()
                            .reversed
                            .toList();
                        // final keys = box.keys.toList().reversed.toList();
                        if (diaries.isEmpty) {
                          return const Center(
                            child: Text(
                              'No entries yet.\nTap + to add a diary entry.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          );
                        }
                        return ListView.separated(
                          itemCount: diaries.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final diary = diaries[index];

                            return InkWell(
                              onTap: () => _openDiary(diary),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 6,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.article_outlined,
                                      size: 20,
                                      color: Colors.brown,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        diary.title.isEmpty
                                            ? '(No title)'
                                            : getPrettyDate(diary.title),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.brown,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(
                                        _formatDate(diary.createdAt),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                    // Delete button
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Delete',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Confirm Delete'),
                                            content: const Text(
                                              'Are you sure you want to delete this diary entry?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  context,
                                                ).pop(true),
                                                child: const Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          final diaryKey = box.keys.firstWhere((
                                            key,
                                          ) {
                                            final d = box.get(key);
                                            return d != null &&
                                                d.id == diary.id &&
                                                d.userId == widget.user.id;
                                          }, orElse: () => null);

                                          if (diaryKey == null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Error: Diary entry not found',
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Diary entry deleted',
                                              ),
                                            ),
                                          );
                                          await box.delete(diaryKey);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // Use a Stack to position main FAB and surrounding sub-buttons
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Sub buttons (arranged around the main FAB)
            // Left
            _buildSubFab(
              icon: Icons.add,
              tooltip: 'Today\'s Entry',
              onTap: () {
                setState(() => _fabOpen = false);
                _createDiary();
              },
              offset: const Offset(0, 80),
            ),
            // Up-left
            _buildSubFab(
              icon: Icons.calendar_today,
              tooltip: 'Pick Date',
              onTap: () {
                setState(() => _fabOpen = false);
                _pickDate();
              },
              offset: const Offset(56, 56),
            ),
            // Up
            _buildSubFab(
              icon: Icons.logout,
              tooltip: 'Logout',
              onTap: () {
                setState(() => _fabOpen = false);
                _logout();
              },
              offset: const Offset(-10, -36),
            ),
            // Left
            _buildSubFab(
              icon: Icons.download,
              tooltip: 'Export Data',
              onTap: () {
                setState(() => _fabOpen = false);
                _exportData();
              },
              offset: const Offset(-36, 10),
            ),
            // Up-Left
            _buildSubFab(
              icon: Icons.upload,
              tooltip: 'Import Backup',
              onTap: () {
                setState(() => _fabOpen = false);
                _importData();
              },
              offset: const Offset(80, 0),
            ),
            // Main FAB
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton(
                onPressed: () => setState(() => _fabOpen = !_fabOpen),
                backgroundColor: const Color(0xFF6B4F3A),
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _fabOpen ? 0.125 : 0.0,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
          ],
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

    for (double y = 24; y < size.height; y += gap) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), linePaint);
    }

    canvas.drawLine(Offset(44, 8), Offset(44, size.height - 8), marginPaint);

    final rectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.brown.withOpacity(0.12)
      ..strokeWidth = 1.0;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
      const Radius.circular(12),
    );
    canvas.drawRRect(r, rectPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
