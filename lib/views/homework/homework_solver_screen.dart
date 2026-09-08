import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/homework_solution_model.dart';
import '../../services/homework_service.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';

/// Interactive UI screen for students & teachers to solve homework problems
/// (via text prompt or image) and view step-by-step educational explanations.
class HomeworkSolverScreen extends StatefulWidget {
  final String? initialSubject;
  final String? initialCourse;

  const HomeworkSolverScreen({
    super.key,
    this.initialSubject,
    this.initialCourse,
  });

  @override
  State<HomeworkSolverScreen> createState() => _HomeworkSolverScreenState();
}

class _HomeworkSolverScreenState extends State<HomeworkSolverScreen> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();

  // Inputs
  String _difficulty = 'medium';
  String _language = 'ku';
  Uint8List? _imageBytes;
  String? _imagePath;
  String? _imageFilename;

  // Processing state
  bool _isLoading = false;
  String? _errorMessage;
  HomeworkSolutionModel? _solution;

  final List<String> _popularSubjects = [
    'بیرکاری',
    'فیزیا',
    'کیمیا',
    'زیندەوەرزانی',
    'کۆمپیوتەر و پرۆگرامین',
    'ئەندازیاری',
    'پزیشکی',
    'ئابووری و ژمێریاری',
    'زمانەوانی',
  ];

  @override
  void initState() {
    super.initState();
    _subjectController.text = widget.initialSubject ?? 'بیرکاری';
    if (widget.initialCourse != null) {
      _courseController.text = widget.initialCourse!;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _subjectController.dispose();
    _courseController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imagePath = picked.path;
          _imageFilename = picked.name;
          _errorMessage = null;
        });
      }
    } catch (e) {
      _pickFileImage();
    }
  }

  Future<void> _pickFileImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        Uint8List? bytes = file.bytes;

        if (!kIsWeb && bytes == null && file.path != null) {
          final local = io.File(file.path!);
          if (await local.exists()) {
            bytes = await local.readAsBytes();
          }
        }

        if (bytes != null) {
          setState(() {
            _imageBytes = bytes;
            _imagePath = file.path;
            _imageFilename = file.name;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('هەڵە لە هەڵبژاردنی وێنە: $e');
    }
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _imagePath = null;
      _imageFilename = null;
    });
  }

  Future<void> _solveProblem() async {
    final text = _questionController.text.trim();
    final subject = _subjectController.text.trim();
    final course = _courseController.text.trim();

    if (text.isEmpty && _imageBytes == null && _imagePath == null) {
      _showErrorSnackBar('تکایە دەقی پرسیارەکە بنووسە یان وێنەکەی هەڵبژێرە.');
      return;
    }

    if (subject.isEmpty) {
      _showErrorSnackBar('تکایە بابەتی زانستی دیاریبکە.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      io.File? fileToPass;
      if (!kIsWeb && _imagePath != null) {
        fileToPass = io.File(_imagePath!);
      }

      final result = await HomeworkService.instance.solveHomework(
        text: text,
        imageFile: fileToPass,
        imageBytes: _imageBytes,
        filename: _imageFilename,
        subject: subject,
        course: course.isNotEmpty ? course : null,
        difficulty: _difficulty,
        language: _language,
      );

      if (mounted) {
        setState(() {
          _solution = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'شیکاری ئەرکی ماڵەوە (AI Homework)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: lang.textDirection,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Input Form Card ──────────────────────────────────────────
              _buildInputCard(isDark),

              const SizedBox(height: 16),

              // ── 2. Submit Button ────────────────────────────────────────────
              ElevatedButton(
                onPressed: _isLoading ? null : _solveProblem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'خەریکی شیکارکردنی پرسیارەکەیە...',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAiMagic,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'شیکارکردنی هەنگاو بە هەنگاو 🚀',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),

              // ── 3. Error Banner ─────────────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.redAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── 4. Solution Result View ─────────────────────────────────────
              if (_solution != null) ...[
                const SizedBox(height: 24),
                _buildSolutionView(_solution!, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question text field
          TextField(
            controller: _questionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'دەقی پرسیار یان هاوکێشەکە',
              hintText:
                  'نموونە: Calculate the limit of (sin x)/x as x -> 0 ...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Optional Image attachment section
          if (_imageBytes != null) ...[
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Center(
                    child: Image.memory(
                      _imageBytes!,
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 14,
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: _clearImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('وێنە بە کامێرا'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('وێنە لە گەلەری'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Subject chips & field
          const Text(
            'بابەتی زانستی:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _popularSubjects.length,
              separatorBuilder: (_, index) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final sub = _popularSubjects[idx];
                final isSelected = _subjectController.text.trim() == sub;
                return ChoiceChip(
                  label: Text(sub, style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _subjectController.text = sub);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Course input (Optional)
          TextField(
            controller: _courseController,
            decoration: InputDecoration(
              labelText: 'ناوی کۆرس (ئارەزوومەندانە)',
              hintText: 'نموونە: Calculus II یان General Physics',
              prefixIcon: const Icon(Icons.book_outlined, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Difficulty & Language Row
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _difficulty,
                  decoration: InputDecoration(
                    labelText: 'ئاستی سەختی',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'easy', child: Text('ئاسان')),
                    DropdownMenuItem(value: 'medium', child: Text('مامناوەند')),
                    DropdownMenuItem(value: 'hard', child: Text('سەخت')),
                    DropdownMenuItem(
                      value: 'advanced',
                      child: Text('پێشکەوتوو'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _difficulty = val);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _language,
                  decoration: InputDecoration(
                    labelText: 'زمانی شیکار',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ku', child: Text('کوردی')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'ar', child: Text('عربي')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _language = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 4. Structured Educational Solution View ─────────────────────────────────

  Widget _buildSolutionView(HomeworkSolutionModel sol, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Direct Answer Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'وەڵامی یەکلاکەرەوە (Answer)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: sol.answer));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('وەڵامەکە لەبەرگیرایەوە! 📋'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                sol.answer,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. Educational Explanation
        _buildSectionCard(
          title: 'ڕوونکردنەوەی فێرکاری (Explanation)',
          icon: Icons.menu_book_rounded,
          color: const Color(0xFF0284C7),
          isDark: isDark,
          content: Text(
            sol.explanation,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        ),

        const SizedBox(height: 16),

        // 3. Step-by-Step Reasoning
        _buildSectionCard(
          title: 'هەنگاوەکانی شیکارکردن (${sol.stepsCount} هەنگاو)',
          icon: Icons.format_list_numbered_rounded,
          color: const Color(0xFF059669),
          isDark: isDark,
          content: Column(
            children: sol.stepByStepReasoning.map((step) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: const Color(0xFF059669),
                      child: Text(
                        '${step.stepNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step.content,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark
                                  ? Colors.white70
                                  : ZankoColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // 4. Common Mistakes
        if (sol.mistakesIdentified.isNotEmpty) ...[
          _buildSectionCard(
            title: 'هەڵە باوەکان (Common Mistakes)',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFE11D48),
            isDark: isDark,
            content: Column(
              children: sol.mistakesIdentified.map((m) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.close_rounded,
                        color: Color(0xFFE11D48),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 5. Helpful Hints
        if (sol.hints.isNotEmpty) ...[
          _buildSectionCard(
            title: 'ڕێنمایی و کلیلەکان (Helpful Hints)',
            icon: Icons.lightbulb_outline_rounded,
            color: const Color(0xFFD97706),
            isDark: isDark,
            content: Column(
              children: sol.hints.map((h) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.tips_and_updates,
                        color: Color(0xFFD97706),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          h,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 6. Related Concepts
        if (sol.relatedConcepts.isNotEmpty) ...[
          _buildSectionCard(
            title: 'چەمک و یاسا پەیوەندیدارەکان (Related Concepts)',
            icon: Icons.hub_outlined,
            color: const Color(0xFF7C3AED),
            isDark: isDark,
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sol.relatedConcepts.map((c) {
                return Chip(
                  backgroundColor: const Color(
                    0xFF7C3AED,
                  ).withValues(alpha: 0.12),
                  side: BorderSide(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                  ),
                  label: Text(
                    c,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? ZankoColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : ZankoColors.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(height: 18),
          content,
        ],
      ),
    );
  }
}
