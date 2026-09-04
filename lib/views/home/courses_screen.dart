import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/language_provider.dart';
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
  String _searchQuery = '';
  String _selectedFilter = 'all'; // 'all', 'in_progress', 'completed'

  static const Color _primaryBlue = Color(0xFF035EC2);
  static const Color _azureCyan = Color(0xFF0284C7);
  static const Color _accentGold = Color(0xFFE4D27D);

  List<Map<String, dynamic>> _getDefaultCourses() {
    return [
      {
        'id': 'c1',
        'title': 'Programming Fundamentals',
        'subtitle': '12 / 18 Lessons • Chapter 4',
        'progress': 0.68,
        'icon': HugeIcons.strokeRoundedCode,
        'color': _primaryBlue,
        'midtermDate': DateTime.now().add(const Duration(days: 12)),
        'finalDate': DateTime.now().add(const Duration(days: 45)),
      },
      {
        'id': 'c2',
        'title': 'Database Systems',
        'subtitle': '8 / 19 Lessons • SQL Queries',
        'progress': 0.42,
        'icon': HugeIcons.strokeRoundedDatabase,
        'color': _primaryBlue,
        'midtermDate': DateTime.now().add(const Duration(days: 18)),
        'finalDate': DateTime.now().add(const Duration(days: 52)),
      },
      {
        'id': 'c3',
        'title': 'Computer Networks',
        'subtitle': '16 / 20 Lessons • TCP/IP',
        'progress': 0.81,
        'icon': HugeIcons.strokeRoundedWifi01,
        'color': _primaryBlue,
        'midtermDate': DateTime.now().add(const Duration(days: 5)),
        'finalDate': DateTime.now().add(const Duration(days: 35)),
      },
      {
        'id': 'c4',
        'title': 'Operating Systems',
        'subtitle': '5 / 15 Lessons • Process Scheduling',
        'progress': 0.33,
        'icon': HugeIcons.strokeRoundedComputer,
        'color': _primaryBlue,
        'midtermDate': DateTime.now().add(const Duration(days: 25)),
        'finalDate': DateTime.now().add(const Duration(days: 60)),
      },
    ];
  }

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
              'color': Color(item['colorValue'] as int? ?? 0xFF035EC2),
              'midtermDate': item['midtermDate'] != null ? DateTime.tryParse(item['midtermDate']) : null,
              'finalDate': item['finalDate'] != null ? DateTime.tryParse(item['finalDate']) : null,
            });
          }
        }
        if (loaded.isEmpty) {
          loaded.addAll(_getDefaultCourses());
        }
        setState(() {
          _courses = loaded;
          _isLoading = false;
        });
      } else {
        setState(() {
          _courses = _getDefaultCourses();
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _courses = _getDefaultCourses();
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
          'iconCode': (c['icon'] is IconData) ? (c['icon'] as IconData).codePoint : 0,
          'colorValue': (c['color'] as Color?)?.toARGB32() ?? 0xFF035EC2,
          'midtermDate': (c['midtermDate'] as DateTime?)?.toIso8601String(),
          'finalDate': (c['finalDate'] as DateTime?)?.toIso8601String(),
        };
      }).toList();

      await prefs.setString('user_custom_courses_list_v2', jsonEncode(toSave));
    } catch (_) {}
  }

  dynamic _getIconFromCode(int? code) {
    if (code == null || code == 0) return HugeIcons.strokeRoundedBook02;
    final Map<int, dynamic> iconMap = {
      CupertinoIcons.function.codePoint: HugeIcons.strokeRoundedAnalytics01,
      CupertinoIcons.sparkles.codePoint: HugeIcons.strokeRoundedAiMagic,
      CupertinoIcons.square_grid_2x2.codePoint: HugeIcons.strokeRoundedLayers01,
      CupertinoIcons.chevron_left_slash_chevron_right.codePoint: HugeIcons.strokeRoundedCode,
      CupertinoIcons.device_desktop.codePoint: HugeIcons.strokeRoundedComputer,
      CupertinoIcons.book.codePoint: HugeIcons.strokeRoundedBook02,
    };
    return iconMap[code] ?? HugeIcons.strokeRoundedBook02;
  }

  // Calculate stats
  double get _averageProgress {
    if (_courses.isEmpty) return 0.0;
    final sum = _courses.fold<double>(0.0, (acc, c) => acc + ((c['progress'] as num?)?.toDouble() ?? 0.0));
    return sum / _courses.length;
  }

  int get _inProgressCount => _courses.where((c) => ((c['progress'] as num?)?.toDouble() ?? 0.0) < 1.0).length;
  int get _completedCount => _courses.where((c) => ((c['progress'] as num?)?.toDouble() ?? 0.0) >= 1.0).length;

  Map<String, dynamic>? get _nextUpcomingExamInfo {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Map<String, dynamic>? closest;
    int minDays = 99999;

    for (final c in _courses) {
      final midterm = c['midtermDate'] as DateTime?;
      final finalExam = c['finalDate'] as DateTime?;

      if (midterm != null) {
        final examDate = DateTime(midterm.year, midterm.month, midterm.day);
        final diff = examDate.difference(today).inDays;
        if (diff >= 0 && diff < minDays) {
          minDays = diff;
          closest = {
            'courseTitle': c['title'],
            'type': 'Midterm',
            'days': diff,
            'date': midterm,
          };
        }
      }

      if (finalExam != null) {
        final examDate = DateTime(finalExam.year, finalExam.month, finalExam.day);
        final diff = examDate.difference(today).inDays;
        if (diff >= 0 && diff < minDays) {
          minDays = diff;
          closest = {
            'courseTitle': c['title'],
            'type': 'Final',
            'days': diff,
            'date': finalExam,
          };
        }
      }
    }

    return closest;
  }

  Map<String, dynamic>? get _featuredCourse {
    if (_courses.isEmpty) return null;
    final nextExam = _nextUpcomingExamInfo;
    if (nextExam != null) {
      final match = _courses.firstWhere(
        (c) => c['title'] == nextExam['courseTitle'],
        orElse: () => _courses.first,
      );
      return match;
    }

    // Default to the in-progress course with the highest completion
    final inProgress = _courses.where((c) {
      final p = (c['progress'] as num?)?.toDouble() ?? 0.0;
      return p > 0.0 && p < 1.0;
    }).toList();

    if (inProgress.isNotEmpty) {
      inProgress.sort((a, b) => ((b['progress'] as num?) ?? 0.0).compareTo((a['progress'] as num?) ?? 0.0));
      return inProgress.first;
    }

    return _courses.first;
  }

  void _showAddOrEditCourseModal([Map<String, dynamic>? existingCourse, int? index]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = existingCourse != null;
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);

    final titleController = TextEditingController(text: existingCourse?['title'] ?? '');
    final subtitleController = TextEditingController(text: existingCourse?['subtitle'] ?? '');
    double progress = existingCourse?['progress'] ?? 0.0;
    dynamic selectedIcon = existingCourse?['icon'] ?? HugeIcons.strokeRoundedBook02;

    DateTime? midtermDate = existingCourse?['midtermDate'] as DateTime?;
    DateTime? finalDate = existingCourse?['finalDate'] as DateTime?;

    final availableIcons = [
      HugeIcons.strokeRoundedBook02,
      HugeIcons.strokeRoundedCode,
      HugeIcons.strokeRoundedDatabase,
      HugeIcons.strokeRoundedWifi01,
      HugeIcons.strokeRoundedComputer,
      HugeIcons.strokeRoundedAnalytics01,
      HugeIcons.strokeRoundedAiMagic,
      HugeIcons.strokeRoundedAtom01,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            String formatDate(DateTime? date) {
              if (date == null) return langProvider.currentLanguage == AppLanguage.english ? 'Not Set' : 'دیاری نەکراوە';
              return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
            }

            final cardBg = isDark ? const Color(0xFF171B23) : Colors.white;
            final inputBg = isDark ? const Color(0xFF0E1117) : const Color(0xFFF1F5F9);
            final borderColor = isDark ? const Color(0xFF262C36) : const Color(0xFFE2E8F0);

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[700] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _primaryBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedMortarboard02,
                              color: _primaryBlue,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isEditing
                              ? (langProvider.currentLanguage == AppLanguage.english ? 'Edit Course' : 'دەستکاریکردنی وانە')
                              : (langProvider.currentLanguage == AppLanguage.english ? 'Add New Course' : 'زیادکردنی وانەی نوێ'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: isDark ? Colors.white : const Color(0xFF17191F),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Icon Selector Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: availableIcons.map((ic) {
                          final isSel = selectedIcon == ic;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedIcon = ic),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsetsDirectional.only(end: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSel ? _primaryBlue : inputBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel ? _primaryBlue : borderColor,
                                  width: 1.2,
                                ),
                              ),
                              child: HugeIcon(
                                icon: ic,
                                color: isSel ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                size: 20,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: titleController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF17191F)),
                      decoration: InputDecoration(
                        labelText: langProvider.currentLanguage == AppLanguage.english ? 'Course Title' : 'ناوی وانە',
                        hintText: langProvider.currentLanguage == AppLanguage.english ? 'e.g. Operating Systems' : 'نموونە: سیستەمی کارپێکردن',
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: subtitleController,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF17191F)),
                      decoration: InputDecoration(
                        labelText: langProvider.currentLanguage == AppLanguage.english ? 'Lessons & Chapters' : 'زانیاری وانە و ژمارەی بەشەکان',
                        hintText: langProvider.currentLanguage == AppLanguage.english ? 'e.g. 12 Lessons • Chapter 1' : 'نموونە: 12 Lessons • Chapter 1',
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Progress Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          langProvider.currentLanguage == AppLanguage.english ? 'Course Completion:' : 'ڕێژەی پێشکەوتن:',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: _primaryBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(progress * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: _primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: progress,
                      min: 0.0,
                      max: 1.0,
                      activeColor: _primaryBlue,
                      inactiveColor: isDark ? const Color(0xFF262C36) : const Color(0xFFE2E8F0),
                      onChanged: (val) {
                        setModalState(() => progress = val);
                      },
                    ),

                    const SizedBox(height: 14),
                    Text(
                      langProvider.currentLanguage == AppLanguage.english ? '📅 Exam Schedules' : '📅 بەرواری تاقیکردنەوەکان',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF17191F),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Midterm Date Picker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Row(
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: _primaryBlue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  langProvider.currentLanguage == AppLanguage.english ? 'Midterm Exam' : 'تاقیکردنەوەی میدترم',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey),
                                ),
                                Text(
                                  formatDate(midtermDate),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF17191F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: modalCtx,
                                initialDate: midtermDate ?? DateTime.now().add(const Duration(days: 14)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() => midtermDate = picked);
                              }
                            },
                            child: Text(
                              langProvider.currentLanguage == AppLanguage.english ? 'Pick Date' : 'هەڵبژاردن',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: _primaryBlue),
                            ),
                          ),
                          if (midtermDate != null)
                            IconButton(
                              icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, size: 18, color: Colors.grey),
                              onPressed: () => setModalState(() => midtermDate = null),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Final Date Picker
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Row(
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedFlag01, color: _azureCyan, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  langProvider.currentLanguage == AppLanguage.english ? 'Final Exam' : 'تاقیکردنەوەی فایناڵ',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.grey),
                                ),
                                Text(
                                  formatDate(finalDate),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF17191F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: modalCtx,
                                initialDate: finalDate ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() => finalDate = picked);
                              }
                            },
                            child: Text(
                              langProvider.currentLanguage == AppLanguage.english ? 'Pick Date' : 'هەڵبژاردن',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: _azureCyan),
                            ),
                          ),
                          if (finalDate != null)
                            IconButton(
                              icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancelCircle, size: 18, color: Colors.grey),
                              onPressed: () => setModalState(() => finalDate = null),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),
                    GestureDetector(
                      onTap: () {
                        final title = titleController.text.trim();
                        final subtitle = subtitleController.text.trim();
                        if (title.isEmpty) return;

                        HapticFeedback.mediumImpact();
                        setState(() {
                          if (isEditing && index != null) {
                            _courses[index]['title'] = title;
                            _courses[index]['subtitle'] = subtitle.isNotEmpty ? subtitle : '0 Lessons • Chapter 1';
                            _courses[index]['progress'] = progress;
                            _courses[index]['icon'] = selectedIcon;
                            _courses[index]['midtermDate'] = midtermDate;
                            _courses[index]['finalDate'] = finalDate;
                          } else {
                            _courses.add({
                              'id': DateTime.now().millisecondsSinceEpoch.toString(),
                              'title': title,
                              'subtitle': subtitle.isNotEmpty ? subtitle : '10 Lessons • Chapter 1',
                              'progress': progress,
                              'icon': selectedIcon,
                              'color': _primaryBlue,
                              'midtermDate': midtermDate,
                              'finalDate': finalDate,
                            });
                          }
                        });

                        _saveCoursesToPrefs();
                        Navigator.pop(modalCtx);
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_primaryBlue, Color(0xFF024A9B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryBlue.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            isEditing
                                ? (langProvider.currentLanguage == AppLanguage.english ? 'Save Changes' : 'پاشەکەوتکردنی گۆڕانکارییەکان')
                                : (langProvider.currentLanguage == AppLanguage.english ? 'Add Course' : 'زیادکردنی وانە'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
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
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          langProvider.currentLanguage == AppLanguage.english ? 'Delete Course' : 'سڕینەوەی وانە',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          langProvider.currentLanguage == AppLanguage.english
              ? 'Are you sure you want to delete "${_courses[index]['title']}"?'
              : 'ئایا دڵنیایت لە سڕینەوەی وانەی (${_courses[index]['title']})؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(langProvider.currentLanguage == AppLanguage.english ? 'Cancel' : 'پەشیمانبوونەوە'),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _courses.removeAt(index);
              });
              _saveCoursesToPrefs();
              Navigator.pop(dialogCtx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              langProvider.currentLanguage == AppLanguage.english ? 'Delete' : 'سڕینەوە',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _openCourseDetail(Map<String, dynamic> c, int courseIndex) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => CourseDetailScreen(
          courseTitle: c['title'] as String,
          courseSubtitle: c['subtitle'] as String,
          progress: c['progress'] as double,
          icon: c['icon'] ?? HugeIcons.strokeRoundedBook02,
          themeColor: _primaryBlue,
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    final filteredCourses = _courses.where((c) {
      final title = (c['title'] as String? ?? '').toLowerCase();
      final matchesSearch = _searchQuery.isEmpty || title.contains(_searchQuery.toLowerCase());
      if (!matchesSearch) return false;

      final progress = (c['progress'] as num?)?.toDouble() ?? 0.0;
      if (_selectedFilter == 'in_progress') return progress < 1.0;
      if (_selectedFilter == 'completed') return progress >= 1.0;
      return true;
    }).toList();

    final textPrimary = isDark ? Colors.white : const Color(0xFF17191F);
    final textSecondary = isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280);
    final cardBg = isDark ? const Color(0xFF171B23) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2);

    final featured = _featuredCourse;
    final nextExam = _nextUpcomingExamInfo;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0E1117) : const Color(0xFFFAFAFB),
      appBar: AppBar(
        backgroundColor: (isDark ? const Color(0xFF0E1117) : const Color(0xFFFAFAFB)).withValues(alpha: 0.95),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              langProvider.translate('all_courses'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: textPrimary,
              ),
            ),
            Text(
              '${_courses.length} ${langProvider.translate('active_courses_count')}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showAddOrEditCourseModal();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primaryBlue, Color(0xFF024A9B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryBlue.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HugeIcon(icon: HugeIcons.strokeRoundedAdd01, color: Colors.white, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      langProvider.translate('add_new_course'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // ─── 1. Academic Performance Dashboard ──────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Stat 1: Total Courses
                        Expanded(
                          child: _buildMetricTile(
                            icon: HugeIcons.strokeRoundedMortarboard02,
                            iconColor: _primaryBlue,
                            value: '${_courses.length}',
                            label: langProvider.translate('active_courses_count'),
                            isDark: isDark,
                          ),
                        ),
                        Container(width: 1, height: 38, color: borderColor),
                        // Stat 2: Average Progress
                        Expanded(
                          child: _buildMetricTile(
                            icon: HugeIcons.strokeRoundedAnalytics01,
                            iconColor: _azureCyan,
                            value: '${(_averageProgress * 100).round()}%',
                            label: langProvider.translate('course_progress'),
                            isDark: isDark,
                          ),
                        ),
                        Container(width: 1, height: 38, color: borderColor),
                        // Stat 3: Next Exam Countdown
                        Expanded(
                          child: _buildMetricTile(
                            icon: HugeIcons.strokeRoundedClock01,
                            iconColor: nextExam != null && (nextExam['days'] as int) <= 5 ? Colors.amber[700]! : _accentGold,
                            value: nextExam != null ? '${nextExam['days']}d' : '-',
                            label: langProvider.translate('upcoming_exams'),
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── 2. Hero Spotlight Card: "Continue Studying" ─────────
                  if (featured != null && _searchQuery.isEmpty && _selectedFilter == 'all') ...[
                    GestureDetector(
                      onTap: () {
                        final idx = _courses.indexOf(featured);
                        _openCourseDetail(featured, idx >= 0 ? idx : 0);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [const Color(0xFF0F2B54), const Color(0xFF131D2D)]
                                : [const Color(0xFFE3F0FF), const Color(0xFFF1F6FD)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _primaryBlue.withValues(alpha: isDark ? 0.4 : 0.25),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryBlue.withValues(alpha: isDark ? 0.25 : 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _primaryBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const HugeIcon(icon: HugeIcons.strokeRoundedPlay, color: Colors.white, size: 11),
                                      const SizedBox(width: 4),
                                      Text(
                                        langProvider.translate('continue_studying'),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                if (nextExam != null && nextExam['courseTitle'] == featured['title'])
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFF9500).withValues(alpha: 0.3), width: 1),
                                    ),
                                    child: Text(
                                      '${nextExam['type']} in ${nextExam['days']}d 🔥',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFF9500),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [_primaryBlue, _azureCyan],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primaryBlue.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: appIcon(
                                      featured['icon'] ?? HugeIcons.strokeRoundedBook02,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        featured['title'] as String,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                          color: textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        featured['subtitle'] as String,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _primaryBlue,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        langProvider.translate('resume_learning'),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ((featured['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: isDark ? const Color(0xFF263345) : const Color(0xFFD6E4F7),
                                valueColor: const AlwaysStoppedAnimation<Color>(_primaryBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ─── 3. Search Bar ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedSearch01,
                          size: 18,
                          color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: TextStyle(
                              fontSize: 13.5,
                              color: textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: langProvider.translate('search_course_hint'),
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: textSecondary,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _searchQuery = ''),
                            child: const HugeIcon(
                              icon: HugeIcons.strokeRoundedCancelCircle,
                              color: Color(0xFFA6ACB8),
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── 4. Filter Chips Row ────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildFilterPill(
                          label: langProvider.translate('filter_all'),
                          count: _courses.length,
                          value: 'all',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          label: langProvider.translate('filter_in_progress'),
                          count: _inProgressCount,
                          value: 'in_progress',
                          isDark: isDark,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterPill(
                          label: langProvider.translate('filter_completed'),
                          count: _completedCount,
                          value: 'completed',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── 5. Courses List ────────────────────────────────────
                  if (filteredCourses.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: _primaryBlue.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedBook02,
                                size: 30,
                                color: _primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            langProvider.translate('no_courses_found'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            langProvider.currentLanguage == AppLanguage.english
                                ? 'Add your first academic course to get started'
                                : 'وانەیەکی نوێ زیاد بکە بۆ دەستپێکردنی خوێندن',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showAddOrEditCourseModal(),
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(langProvider.translate('add_new_course')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredCourses.map((c) {
                      final originalIndex = _courses.indexOf(c);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildModernCourseCard(
                          c: c,
                          index: originalIndex,
                          isDark: isDark,
                          lang: langProvider,
                        ),
                      );
                    }),
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildMetricTile({
    required dynamic icon,
    required Color iconColor,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(icon: icon, color: iconColor, size: 16),
            const SizedBox(width: 5),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF17191F),
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPill({
    required String label,
    required int count,
    required String value,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [_primaryBlue, Color(0xFF024A9B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? const Color(0xFF171B23) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _primaryBlue
                : (isDark ? const Color(0xFF262C36) : const Color(0xFFE2E8F0)),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFFA6ACB8) : const Color(0xFF64748B)),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : (isDark ? const Color(0xFF262C36) : const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernCourseCard({
    required Map<String, dynamic> c,
    required int index,
    required bool isDark,
    required LanguageProvider lang,
  }) {
    final title = c['title'] as String? ?? '';
    final subtitle = c['subtitle'] as String? ?? '';
    final progress = ((c['progress'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 1.0);
    final icon = c['icon'] ?? HugeIcons.strokeRoundedBook02;
    final midterm = c['midtermDate'] as DateTime?;
    final finalExam = c['finalDate'] as DateTime?;

    final cardBg = isDark ? const Color(0xFF171B23) : Colors.white;
    final borderColor = isDark ? const Color(0xFF262C36) : const Color(0xFFECEEF2);
    final textPrimary = isDark ? Colors.white : const Color(0xFF17191F);
    final textSecondary = isDark ? const Color(0xFFA6ACB8) : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () => _openCourseDetail(c, index),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Icon + Title + Menu
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? _primaryBlue.withValues(alpha: 0.18) : const Color(0xFFE2EDFB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: appIcon(icon, color: _primaryBlue, size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedMoreVertical,
                    color: textSecondary,
                    size: 18,
                  ),
                  onSelected: (val) {
                    if (val == 'edit') _showAddOrEditCourseModal(c, index);
                    if (val == 'delete') _deleteCourse(index);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedPencilEdit02, size: 16, color: _primaryBlue),
                          const SizedBox(width: 8),
                          Text(lang.translate('edit_profile'), style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const HugeIcon(icon: HugeIcons.strokeRoundedDelete02, size: 16, color: Colors.redAccent),
                          const SizedBox(width: 8),
                          Text(lang.currentLanguage == AppLanguage.english ? 'Delete' : 'سڕینەوە', style: const TextStyle(fontSize: 13, color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Middle: Exam Badges (if configured)
            if (midterm != null || finalExam != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (midterm != null)
                    _buildExamBadge(
                      label: lang.currentLanguage == AppLanguage.english ? 'Midterm' : 'میدترم',
                      date: midterm,
                      icon: HugeIcons.strokeRoundedClock01,
                      isDark: isDark,
                    ),
                  if (finalExam != null)
                    _buildExamBadge(
                      label: lang.currentLanguage == AppLanguage.english ? 'Final' : 'فایناڵ',
                      date: finalExam,
                      icon: HugeIcons.strokeRoundedFlag01,
                      isDark: isDark,
                    ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Bottom: Progress Header & Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang.translate('course_progress'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: isDark ? const Color(0xFF232A38) : const Color(0xFFE5EBF5),
                valueColor: const AlwaysStoppedAnimation<Color>(_primaryBlue),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamBadge({
    required String label,
    required DateTime date,
    required dynamic icon,
    required bool isDark,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(date.year, date.month, date.day);
    final diff = examDay.difference(today).inDays;

    Color badgeBg;
    Color textColor;
    String statusText;

    if (diff < 0) {
      statusText = 'Done';
      badgeBg = isDark ? const Color(0xFF262C36) : const Color(0xFFE2E8F0);
      textColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    } else if (diff == 0) {
      statusText = 'Today! ⚠️';
      badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.15);
      textColor = const Color(0xFFEF4444);
    } else if (diff <= 3) {
      statusText = '${diff}d left 🔥';
      badgeBg = const Color(0xFFFF9500).withValues(alpha: 0.15);
      textColor = const Color(0xFFFF9500);
    } else {
      statusText = '${diff}d left';
      badgeBg = _primaryBlue.withValues(alpha: 0.12);
      textColor = _primaryBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          appIcon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            '$label: $statusText',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
