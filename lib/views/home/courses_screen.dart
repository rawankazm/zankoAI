import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../courses/course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  List<Map<String, dynamic>> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCourses();
  }

  Future<void> _loadSavedCourses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('user_custom_courses_list_v2');

      if (savedData != null && savedData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedData);
        final List<Map<String, dynamic>> loaded = [];

        final dummyTitles = {
          'Calculus & Linear Algebra',
          'Machine Learning Fundamentals',
          'Data Structures & Algorithms',
          'Python & Data Science',
          'Operating Systems',
        };

        for (var item in decoded) {
          if (item is Map<String, dynamic>) {
            final title = item['title']?.toString() ?? '';
            if (dummyTitles.contains(title)) continue;

            loaded.add({
              'id': item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
              'title': title,
              'subtitle': item['subtitle']?.toString() ?? '10 Lessons • Chapter 1',
              'progress': (item['progress'] as num?)?.toDouble() ?? 0.0,
              'icon': _getIconFromCode(item['iconCode'] as int?),
              'color': Color(item['colorValue'] as int? ?? 0xFF6C5CE7),
              'midtermDate': item['midtermDate'] != null ? DateTime.tryParse(item['midtermDate']) : null,
              'finalDate': item['finalDate'] != null ? DateTime.tryParse(item['finalDate']) : null,
            });
          }
        }
        setState(() {
          _courses = loaded;
          _isLoading = false;
        });
      } else {
        setState(() {
          _courses = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _courses = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveCoursesToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> toSave = _courses.map((c) {
        return {
          'id': c['id'],
          'title': c['title'],
          'subtitle': c['subtitle'],
          'progress': c['progress'],
          'iconCode': (c['icon'] as IconData?)?.codePoint ?? CupertinoIcons.book.codePoint,
          'colorValue': (c['color'] as Color?)?.toARGB32() ?? 0xFF6C5CE7,
          'midtermDate': (c['midtermDate'] as DateTime?)?.toIso8601String(),
          'finalDate': (c['finalDate'] as DateTime?)?.toIso8601String(),
        };
      }).toList();

      await prefs.setString('user_custom_courses_list_v2', jsonEncode(toSave));
    } catch (_) {}
  }

  IconData _getIconFromCode(int? code) {
    if (code == null) return CupertinoIcons.book;
    final Map<int, IconData> iconMap = {
      CupertinoIcons.function.codePoint: CupertinoIcons.function,
      CupertinoIcons.sparkles.codePoint: CupertinoIcons.sparkles,
      CupertinoIcons.square_grid_2x2.codePoint: CupertinoIcons.square_grid_2x2,
      CupertinoIcons.chevron_left_slash_chevron_right.codePoint: CupertinoIcons.chevron_left_slash_chevron_right,
      CupertinoIcons.device_desktop.codePoint: CupertinoIcons.device_desktop,
      CupertinoIcons.book.codePoint: CupertinoIcons.book,
    };
    return iconMap[code] ?? CupertinoIcons.book;
  }

  void _showAddOrEditCourseModal([Map<String, dynamic>? existingCourse, int? index]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = existingCourse != null;

    final titleController = TextEditingController(text: existingCourse?['title'] ?? '');
    final subtitleController = TextEditingController(text: existingCourse?['subtitle'] ?? '');
    double progress = existingCourse?['progress'] ?? 0.0;

    DateTime? midtermDate = existingCourse?['midtermDate'] as DateTime?;
    DateTime? finalDate = existingCourse?['finalDate'] as DateTime?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String formatDate(DateTime? date) {
              if (date == null) return 'دیاری نەکراوە';
              return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
            }

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: isDark ? ZankoColors.darkCard : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEditing ? 'دەستکاریکردنی وانە ✏️' : 'زیادکردنی وانەی نوێ 📚',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'ناوی وانە',
                        hintText: 'نموونە: سیستەمی کارپێکردن',
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subtitleController,
                      style: TextStyle(color: isDark ? Colors.white : ZankoColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'زانیاری وانە و ژمارەی بەشەکان',
                        hintText: 'نموونە: 12 Lessons • Chapter 1',
                        filled: true,
                        fillColor: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ڕێژەی پێشکەوتن: ${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[300] : ZankoColors.textSecondary,
                      ),
                    ),
                    Slider(
                      value: progress,
                      min: 0.0,
                      max: 1.0,
                      activeColor: ZankoColors.primary,
                      onChanged: (val) {
                        setModalState(() {
                          progress = val;
                        });
                      },
                    ),

                    const SizedBox(height: 12),
                    Text(
                      '📅 ژێرمێژووی تاقیکردنەوەکان (Exam Countdown)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : ZankoColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Midterm Date Picker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.timer, color: Color(0xFF007AFF), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تاقیکردنەوەی میدترم', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                                Text(
                                  formatDate(midtermDate),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: midtermDate ?? DateTime.now().add(const Duration(days: 14)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  midtermDate = picked;
                                });
                              }
                            },
                            child: const Text('هەڵبژاردن', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          if (midtermDate != null)
                            IconButton(
                              icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: Colors.grey),
                              onPressed: () => setModalState(() => midtermDate = null),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Final Date Picker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? ZankoColors.darkBackground : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.flag_fill, color: Color(0xFFAF52DE), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('تاقیکردنەوەی فایناڵ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                                Text(
                                  formatDate(finalDate),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : ZankoColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: finalDate ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() {
                                  finalDate = picked;
                                });
                              }
                            },
                            child: const Text('هەڵبژاردن', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          if (finalDate != null)
                            IconButton(
                              icon: const Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: Colors.grey),
                              onPressed: () => setModalState(() => finalDate = null),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final title = titleController.text.trim();
                          final subtitle = subtitleController.text.trim();
                          if (title.isEmpty) return;

                          setState(() {
                            if (isEditing && index != null) {
                              _courses[index]['title'] = title;
                              _courses[index]['subtitle'] = subtitle.isNotEmpty ? subtitle : '0 Lessons • Chapter 1';
                              _courses[index]['progress'] = progress;
                              _courses[index]['midtermDate'] = midtermDate;
                              _courses[index]['finalDate'] = finalDate;
                            } else {
                              _courses.add({
                                'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                'title': title,
                                'subtitle': subtitle.isNotEmpty ? subtitle : '10 Lessons • Chapter 1',
                                'progress': progress,
                                'icon': CupertinoIcons.book,
                                'color': const Color(0xFF6C5CE7),
                                'midtermDate': midtermDate,
                                'finalDate': finalDate,
                              });
                            }
                          });

                          _saveCoursesToPrefs();

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEditing ? '✅ وانەکە بە سەرکەوتوویی دەستکاری کرا' : '✅ وانەی نوێ بە سەرکەوتوویی زیادکرا'),
                              backgroundColor: const Color(0xFF10B981),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ZankoColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          isEditing ? 'پاشەکەوتکردنی گۆڕانکارییەکان' : 'زیادکردنی وانە',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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

  void _deleteCourse(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سڕینەوەی وانە', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('ئایا دڵنیایت لە سڕینەوەی وانەی (${_courses[index]['title']})؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('پەشیمانبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _courses.removeAt(index);
              });
              _saveCoursesToPrefs();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🗑️ وانەکە بە سەرکەوتوویی سڕایەوە'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('سڕینەوە', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? ZankoColors.darkBackground : ZankoColors.background,
      appBar: AppBar(
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withValues(alpha: 0.9),
        elevation: 0,
        title: Text(
          langProvider.translate('all_courses'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: isDark ? Colors.white : ZankoColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _courses.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: ZankoColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(CupertinoIcons.book_fill, size: 40, color: ZankoColors.primary),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'هیچ وانەیەک تۆمار نەکراوە',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : ZankoColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'دەتوانیت وانەکانی ئەم سیمیستەرەت لێرە زیاد بکەیت تا کاتی تاقیکردنەوە و بەرەوپێشچوونت بزانیت.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : ZankoColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _showAddOrEditCourseModal(),
                            icon: const Icon(CupertinoIcons.add, size: 18, color: Colors.white),
                            label: const Text('زیادکردنی وانەی نوێ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ZankoColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 110),
                    itemCount: _courses.length + 1,
                    itemBuilder: (context, index) {
                      // Top Add Course Banner Card
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GestureDetector(
                            onTap: () => _showAddOrEditCourseModal(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    ZankoColors.primary,
                                    ZankoColors.primary.withValues(alpha: 0.85),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: ZankoShadows.floating,
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(CupertinoIcons.add_circled_solid, color: Colors.white, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'زیادکردنی وانەی نوێ',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final c = _courses[index - 1];
                      final courseIndex = index - 1;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: CourseCard(
                          title: c['title'] as String,
                          subtitle: c['subtitle'] as String,
                          progress: c['progress'] as double,
                          icon: c['icon'] as IconData,
                          gradientStart: c['color'] as Color,
                          gradientEnd: (c['color'] as Color).withValues(alpha: 0.8),
                          midtermDate: c['midtermDate'] as DateTime?,
                          finalDate: c['finalDate'] as DateTime?,
                          onEdit: () => _showAddOrEditCourseModal(c, courseIndex),
                          onDelete: () => _deleteCourse(courseIndex),
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => CourseDetailScreen(
                                  courseTitle: c['title'] as String,
                                  courseSubtitle: c['subtitle'] as String,
                                  progress: c['progress'] as double,
                                  icon: c['icon'] as IconData,
                                  themeColor: c['color'] as Color,
                                  midtermDate: c['midtermDate'] as DateTime?,
                                  finalDate: c['finalDate'] as DateTime?,
                                  onExamDatesChanged: (mDate, fDate) {
                                    setState(() {
                                      _courses[courseIndex]['midtermDate'] = mDate;
                                      _courses[courseIndex]['finalDate'] = fDate;
                                    });
                                    _saveCoursesToPrefs();
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}


