import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/language_provider.dart';
import '../../services/score_service.dart';
import '../../theme.dart';

class CourseScoreItem {
  final String id;
  final String title;
  final double quizScore; // Out of 40
  final double examScore; // Out of 60

  CourseScoreItem({
    required this.id,
    required this.title,
    required this.quizScore,
    required this.examScore,
  });

  double get totalScore => (quizScore + examScore).clamp(0.0, 100.0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'quizScore': quizScore,
        'examScore': examScore,
      };

  factory CourseScoreItem.fromJson(Map<String, dynamic> json) => CourseScoreItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        quizScore: (json['quizScore'] as num?)?.toDouble() ?? 0.0,
        examScore: (json['examScore'] as num?)?.toDouble() ?? 0.0,
      );
}

class GpaTrackerScreen extends StatefulWidget {
  const GpaTrackerScreen({super.key});

  @override
  State<GpaTrackerScreen> createState() => _GpaTrackerScreenState();
}

class _GpaTrackerScreenState extends State<GpaTrackerScreen> {
  List<CourseScoreItem> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourseScores();
  }

  Future<void> _loadCourseScores() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = prefs.getString('saved_course_scores_v2');

    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawJson);
        setState(() {
          _courses = decoded.map((item) => CourseScoreItem.fromJson(item)).toList();
          _isLoading = false;
        });
        return;
      } catch (_) {}
    }

    // Default sample courses if empty
    setState(() {
      _courses = [
        CourseScoreItem(id: 'c1', title: 'Operating Systems', quizScore: 36.0, examScore: 52.0),
        CourseScoreItem(id: 'c2', title: 'Machine Learning Fundamentals', quizScore: 38.0, examScore: 55.0),
        CourseScoreItem(id: 'c3', title: 'Calculus & Linear Algebra', quizScore: 32.0, examScore: 45.0),
        CourseScoreItem(id: 'c4', title: 'Python & Data Science', quizScore: 35.0, examScore: 48.0),
        CourseScoreItem(id: 'c5', title: 'Data Structures & Algorithms', quizScore: 30.0, examScore: 42.0),
      ];
      _isLoading = false;
    });
    _saveCourseScores();
  }

  Future<void> _saveCourseScores() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJson = jsonEncode(_courses.map((c) => c.toJson()).toList());
    await prefs.setString('saved_course_scores_v2', rawJson);
  }

  double get _overallAverageScore {
    if (_courses.isEmpty) return 0.0;
    final totalSum = _courses.fold<double>(0.0, (sum, c) => sum + c.totalScore);
    return totalSum / _courses.length;
  }

  void _showAddOrEditCourseModal([CourseScoreItem? existingCourse]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = existingCourse != null;

    final titleController = TextEditingController(text: existingCourse?.title ?? '');
    final quizController = TextEditingController(text: existingCourse != null ? existingCourse.quizScore.toStringAsFixed(1) : '35.0');
    final examController = TextEditingController(text: existingCourse != null ? existingCourse.examScore.toStringAsFixed(1) : '50.0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final quizVal = double.tryParse(quizController.text.trim()) ?? 0.0;
            final examVal = double.tryParse(examController.text.trim()) ?? 0.0;
            final currentTotal = (quizVal + examVal).clamp(0.0, 100.0);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E222A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEFEFF7),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      isEditing ? 'دەستکاری نمرەی وانە 📝' : 'زیادکردنی وانە و نمرەی نوێ 🎓',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                        fontFamily: 'Noto Sans Arabic',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'نمرەی کویز (لە سەر ٤٠) و تاقیکردنەوە (لە سەر ٦٠) بنووسە تا کۆی گشتی لەسەر ١٠٠ دیاری بێت:',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                        fontFamily: 'Noto Sans Arabic',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Course Name
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: 'ناوی وانە (Course Name)',
                        prefixIcon: const Icon(Icons.book_rounded, color: ZankoColors.primary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Scores Row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quizController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              labelText: 'نمرەی کویز (/40)',
                              prefixIcon: const Icon(CupertinoIcons.checkmark_circle, color: Color(0xFF38BDF8)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: examController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              labelText: 'نمرەی تاقیکردنەوە (/60)',
                              prefixIcon: const Icon(CupertinoIcons.doc_text_fill, color: Color(0xFFFF9F0A)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Live Total Calculation Preview
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: ZankoColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ZankoColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'کۆی گشتی وانەکە (لەسەر ١٠٠):',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Noto Sans Arabic'),
                          ),
                          Text(
                            '${currentTotal.toStringAsFixed(1)} / 100',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: ZankoColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZankoColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          final title = titleController.text.trim();
                          if (title.isEmpty) return;

                          setState(() {
                            if (isEditing) {
                              final index = _courses.indexWhere((c) => c.id == existingCourse.id);
                              if (index != -1) {
                                _courses[index] = CourseScoreItem(
                                  id: existingCourse.id,
                                  title: title,
                                  quizScore: quizVal.clamp(0.0, 40.0),
                                  examScore: examVal.clamp(0.0, 60.0),
                                );
                              }
                            } else {
                              _courses.add(
                                CourseScoreItem(
                                  id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                                  title: title,
                                  quizScore: quizVal.clamp(0.0, 40.0),
                                  examScore: examVal.clamp(0.0, 60.0),
                                ),
                              );
                            }
                          });

                          _saveCourseScores();
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          isEditing ? 'نوێکردنەوەی نمرە' : 'خەزنکردنی وانە',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Noto Sans Arabic'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    final avg = _overallAverageScore;
    String statusBadge = 'ئاستی بەرز و شایستە 🌟';
    Color badgeColor = const Color(0xFF10B981);

    if (avg < 70) {
      statusBadge = 'پێویستی بە ڕاهێنانە 📈';
      badgeColor = const Color(0xFFFF9F0A);
    } else if (avg < 85) {
      statusBadge = 'ئاستی باش و گونجاو 👍';
      badgeColor = const Color(0xFF6C5CE7);
    }

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF11141A) : const Color(0xFFF8F9FE),
        appBar: AppBar(
          title: const Text('نمرە و ئەنجامی وانەکان', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Noto Sans Arabic')),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(CupertinoIcons.add_circled),
              tooltip: 'زیادکردنی وانە',
              onPressed: () => _showAddOrEditCourseModal(),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero Total Score Card (out of 100) ─────────────────
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [ZankoColors.darkCardSecondary, Color(0xFF312E81), Color(0xFF4338CA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'تێکڕای نمرەکان (Overall Score)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                  fontFamily: 'Noto Sans Arabic',
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusBadge,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'Noto Sans Arabic'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Giant Score Display
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                avg.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 54,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '/ 100',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Linear Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (avg / 100.0).clamp(0.0, 1.0),
                              minHeight: 10,
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Quick Summary Badges
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildHeaderStat('کۆی وانەکان', '${_courses.length} وانە'),
                              Container(width: 1, height: 24, color: Colors.white24),
                              _buildHeaderStat('تێکڕای کویز', '${(_courses.isEmpty ? 0 : _courses.fold<double>(0, (s, c) => s + c.quizScore) / _courses.length).toStringAsFixed(1)} / 40'),
                              Container(width: 1, height: 24, color: Colors.white24),
                              _buildHeaderStat('تێکڕای تاقیکردنەوە', '${(_courses.isEmpty ? 0 : _courses.fold<double>(0, (s, c) => s + c.examScore) / _courses.length).toStringAsFixed(1)} / 60'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Add Course Button Card ────────────────────────────────
                    InkWell(
                      onTap: () => _showAddOrEditCourseModal(),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E222A) : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: ZankoColors.primary.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: isDark ? [] : ZankoShadows.card,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ZankoColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(CupertinoIcons.add, color: ZankoColors.primary, size: 22),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'زیادکردنی وانە و نمرەی نوێ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Noto Sans Arabic',
                                ),
                              ),
                            ),
                            const Icon(CupertinoIcons.chevron_forward, color: ZankoColors.primary, size: 18),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Courses Breakdown Header ──────────────────────────────
                    Text(
                      'وانەکان و نمرەکانیان (لە سەر ١٠٠)',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                        fontFamily: 'Noto Sans Arabic',
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (_courses.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(30),
                          child: Text(
                            'هیچ وانەیەک زیادت نەکردووە، بەتنەکە لەسەرەوە دابگرە',
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontFamily: 'Noto Sans Arabic'),
                          ),
                        ),
                      )
                    else
                      ..._courses.map((course) {
                        final total = course.totalScore;
                        Color scoreColor = const Color(0xFF10B981);
                        if (total < 70) scoreColor = const Color(0xFFFF9F0A);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E222A) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF0F0F6),
                            ),
                            boxShadow: isDark ? [] : ZankoShadows.card,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: scoreColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(Icons.school_rounded, color: scoreColor, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course.title,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                                        fontFamily: 'Noto Sans Arabic',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'کویز: ${course.quizScore.toStringAsFixed(1)}/40  •  تاقیکردنەوە: ${course.examScore.toStringAsFixed(1)}/60',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                                        fontFamily: 'Noto Sans Arabic',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${total.toInt()}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: scoreColor,
                                    ),
                                  ),
                                  const Text(
                                    '/ 100 نمرە',
                                    style: TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'Noto Sans Arabic'),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, color: Colors.grey, size: 20),
                                onSelected: (val) {
                                  if (val == 'edit') {
                                    _showAddOrEditCourseModal(course);
                                  } else if (val == 'delete') {
                                    setState(() {
                                      _courses.removeWhere((c) => c.id == course.id);
                                    });
                                    _saveCourseScores();
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('دەستکاری', style: TextStyle(fontSize: 13, fontFamily: 'Noto Sans Arabic')),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete, size: 18, color: Colors.redAccent),
                                        SizedBox(width: 8),
                                        Text('سڕینەوە', style: TextStyle(fontSize: 13, color: Colors.redAccent, fontFamily: 'Noto Sans Arabic')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white60, fontFamily: 'Noto Sans Arabic'),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }
}
