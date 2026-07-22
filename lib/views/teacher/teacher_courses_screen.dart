import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key});

  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  final List<Map<String, dynamic>> _courses = [
    {
      'title': 'تۆڕەکان و کۆمپیوتەر',
      'desc': 'بنەماکانی تۆڕ، پرۆتۆکۆل، TCP/IP',
      'students': 42,
      'quizzes': 5,
      'color': const Color(0xFF2196F3),
      'icon': Icons.lan_rounded,
    },
    {
      'title': 'داتابەیس',
      'desc': 'SQL، ڕەوانەکاری داتا، نورمالایزیشن',
      'students': 38,
      'quizzes': 4,
      'color': const Color(0xFF4CAF50),
      'icon': Icons.storage_rounded,
    },
    {
      'title': 'ئەمنیەتی سایبەر',
      'desc': 'کریپتۆگرافی، ئەمنیەتی تۆڕ',
      'students': 29,
      'quizzes': 3,
      'color': const Color(0xFFF44336),
      'icon': Icons.security_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Provider.of<LanguageProvider>(context);
    String t(String key) => lang.translate(key);
    const green = Color(0xFF059669);

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('teacher_courses_title'),
              style: const TextStyle()),
          centerTitle: true,
          backgroundColor: green,
          foregroundColor: Colors.white,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: green,
          foregroundColor: Colors.white,
          onPressed: () => _showAddCourseDialog(context, lang, t),
          icon: const Icon(Icons.add_rounded),
          label: Text(t('teacher_add_course'),
              style: const TextStyle()),
        ),
        body: _courses.isEmpty
            ? _EmptyState(t: t, theme: theme)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _courses.length,
                itemBuilder: (context, i) {
                  final c = _courses[i];
                  final color = c['color'] as Color;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: theme.colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withOpacity(0.7)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(c['icon'] as IconData,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c['title'] as String,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      c['desc'] as String,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                onSelected: (v) {
                                  if (v == 'delete') {
                                    setState(() => _courses.removeAt(i));
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(value: 'edit', child: Text(t('edit'))),
                                  PopupMenuItem(value: 'delete', child: Text(t('delete'))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Stats Footer
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              _CourseStat(
                                icon: Icons.people_rounded,
                                value: '${c['students']}',
                                label: t('course_students_count'),
                                color: color,
                              ),
                              const Spacer(),
                              _CourseStat(
                                icon: Icons.quiz_rounded,
                                value: '${c['quizzes']}',
                                label: t('teacher_stats_quizzes'),
                                color: color,
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {},
                                child: Text(t('view_all'),
                                    style: TextStyle(
                                        color: color)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _showAddCourseDialog(
      BuildContext context, LanguageProvider lang, String Function(String) t) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: lang.textDirection,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t('teacher_add_course_title'),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: t('course_title_field'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                style: const TextStyle(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: t('course_desc_field'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                maxLines: 2,
                style: const TextStyle(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (titleCtrl.text.isNotEmpty) {
                    setState(() {
                      _courses.add({
                        'title': titleCtrl.text,
                        'desc': descCtrl.text,
                        'students': 0,
                        'quizzes': 0,
                        'color': const Color(0xFF7C3AED),
                        'icon': Icons.book_rounded,
                      });
                    });
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(t('teacher_add_course'),
                    style: const TextStyle()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _CourseStat({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text('$value $label',                style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String Function(String) t;
  final ThemeData theme;
  const _EmptyState({required this.t, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_rounded,
              size: 72, color: theme.colorScheme.outline.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(t('no_courses_yet'),
              style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.5))),
          const SizedBox(height: 8),
          Text(t('add_first_course'),
              style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withOpacity(0.35))),
        ],
      ),
    );
  }
}
