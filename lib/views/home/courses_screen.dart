import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../theme.dart';
import '../../widgets/apple_ui_components.dart';
import '../courses/course_detail_screen.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langProvider = Provider.of<LanguageProvider>(context);

    final courses = [
      {
        'title': 'Calculus & Linear Algebra',
        'subtitle': '18 Lessons • Chapter 4',
        'progress': 0.76,
        'icon': CupertinoIcons.function,
        'color': const Color(0xFF6C5CE7),
      },
      {
        'title': 'Machine Learning Fundamentals',
        'subtitle': '12 Lessons • Neural Networks',
        'progress': 0.80,
        'icon': CupertinoIcons.sparkles,
        'color': const Color(0xFFAF52DE),
      },
      {
        'title': 'Data Structures & Algorithms',
        'subtitle': '24 Lessons • Trees & Graphs',
        'progress': 0.45,
        'icon': CupertinoIcons.square_grid_2x2,
        'color': const Color(0xFF007AFF),
      },
      {
        'title': 'Python & Data Science',
        'subtitle': '20 Lessons • Pandas & NumPy',
        'progress': 0.60,
        'icon': CupertinoIcons.chevron_left_slash_chevron_right,
        'color': const Color(0xFFFF9F0A),
      },
      {
        'title': 'Operating Systems',
        'subtitle': '15 Lessons • Memory Management',
        'progress': 0.90,
        'icon': CupertinoIcons.device_desktop,
        'color': const Color(0xFF34C759),
      },
    ];

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
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: courses.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final c = courses[index];
            return CourseCard(
              title: c['title'] as String,
              subtitle: c['subtitle'] as String,
              progress: c['progress'] as double,
              icon: c['icon'] as IconData,
              gradientStart: c['color'] as Color,
              gradientEnd: (c['color'] as Color).withOpacity(0.8),
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
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
