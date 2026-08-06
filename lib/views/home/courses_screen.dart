import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  late final List<Map<String, dynamic>> _courses;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _courses = [
      {
        'id': '1',
        'title': 'Calculus & Linear Algebra',
        'subtitle': '18 Lessons • Chapter 4',
        'progress': 0.76,
        'icon': CupertinoIcons.function,
        'color': const Color(0xFF6C5CE7),
        'midtermDate': now.add(const Duration(days: 5)),
        'finalDate': now.add(const Duration(days: 24)),
      },
      {
        'id': '2',
        'title': 'Machine Learning Fundamentals',
        'subtitle': '12 Lessons • Neural Networks',
        'progress': 0.80,
        'icon': CupertinoIcons.sparkles,
        'color': const Color(0xFFAF52DE),
        'midtermDate': now.add(const Duration(days: 2)),
        'finalDate': now.add(const Duration(days: 19)),
      },
      {
        'id': '3',
        'title': 'Data Structures & Algorithms',
        'subtitle': '24 Lessons • Trees & Graphs',
        'progress': 0.45,
        'icon': CupertinoIcons.square_grid_2x2,
        'color': const Color(0xFF007AFF),
        'midtermDate': now, // Today
        'finalDate': now.add(const Duration(days: 15)),
      },
      {
        'id': '4',
        'title': 'Python & Data Science',
        'subtitle': '20 Lessons • Pandas & NumPy',
        'progress': 0.60,
        'icon': CupertinoIcons.chevron_left_slash_chevron_right,
        'color': const Color(0xFFFF9F0A),
        'midtermDate': now.subtract(const Duration(days: 4)), // Passed
        'finalDate': now.add(const Duration(days: 10)),
      },
      {
        'id': '5',
        'title': 'Operating Systems',
        'subtitle': '15 Lessons • Memory Management',
        'progress': 0.90,
        'icon': CupertinoIcons.device_desktop,
        'color': const Color(0xFF34C759),
        'midtermDate': now.subtract(const Duration(days: 15)),
        'finalDate': now.add(const Duration(days: 3)),
      },
    ];
  }

  void _showAddOrEditCourseModal([Map<String, dynamic>? existingCourse, int? index]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = existingCourse != null;

    final titleController = TextEditingController(text: existingCourse?['title'] ?? '');
    final subtitleController = TextEditingController(text: existingCourse?['subtitle'] ?? '');
    double progress = existingCourse?['progress'] ?? 0.5;

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
                top: 20, left: 20, right: 20,
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
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEditing ? 'دەستکاریکردنی وانە' : 'زیادکردنی وانەی نوێ',
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
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : ZankoColors.textSecondary),
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
                                initialDate: midtermDate ?? DateTime.now(),
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

                    const SizedBox(height: 8),

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
        backgroundColor: (isDark ? ZankoColors.darkBackground : ZankoColors.background).withOpacity(0.9),
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
        actions: [
          IconButton(
            onPressed: () => _showAddOrEditCourseModal(),
            icon: const Icon(CupertinoIcons.add_circled_solid, color: ZankoColors.primary, size: 28),
            tooltip: 'زیادکردنی وانەی نوێ',
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: false,
      ),
      body: SafeArea(
        child: _courses.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.book, size: 60, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('هیچ وانەیەک نییە!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showAddOrEditCourseModal(),
                      icon: const Icon(CupertinoIcons.add, size: 18),
                      label: const Text('زیادکردنی یەکەم وانە'),
                    ),
                  ],
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
                                ZankoColors.primary.withOpacity(0.85),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: ZankoShadows.floating,
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(CupertinoIcons.add_circled_solid, color: Colors.white, size: 24),
                              SizedBox(width: 10),
                              Text(
                                '➕ زیادکردنی وانەی نوێ',
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
                      gradientEnd: (c['color'] as Color).withOpacity(0.8),
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


