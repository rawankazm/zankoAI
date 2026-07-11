import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/language_provider.dart';
import '../models/user_model.dart';
import 'home/home_screen.dart';
import 'ai_teacher/ai_teacher_screen.dart';
import 'pdf/pdf_summary_screen.dart';
import 'quiz/quiz_screen.dart';
import 'notes/notes_screen.dart';
import 'teacher/teacher_dashboard_screen.dart';
import 'teacher/teacher_quiz_create_screen.dart';
import 'teacher/teacher_courses_screen.dart';
import 'teacher/teacher_students_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  // ─── Student screens ─────────────────────────────────────────
  static const List<Widget> _studentScreens = [
    HomeScreen(),
    AiTeacherScreen(),
    PdfSummaryScreen(),
    QuizScreen(),
    NotesScreen(),
  ];

  // ─── Teacher screens ─────────────────────────────────────────
  static const List<Widget> _teacherScreens = [
    TeacherDashboardScreen(),
    TeacherCoursesScreen(),
    TeacherQuizCreateScreen(),
    TeacherStudentsScreen(),
    AiTeacherScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final langProvider = Provider.of<LanguageProvider>(context);
    final authService = Provider.of<AuthService>(context);
    String t(String key) => langProvider.translate(key);

    final isTeacher = authService.currentUser?.role == UserRole.teacher;

    // Reset index if role changes and index out of range
    final screens = isTeacher ? _teacherScreens : _studentScreens;
    final safeIndex = _selectedIndex.clamp(0, screens.length - 1);

    final teacherPrimary = const Color(0xFF7C3AED);
    final studentPrimary = const Color(0xFF1565C0);
    final navColor = isTeacher ? teacherPrimary : studentPrimary;

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        body: IndexedStack(
          index: safeIndex,
          children: screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: safeIndex,
          onDestinationSelected: _onItemTapped,
          indicatorColor: navColor.withOpacity(0.15),
          destinations: isTeacher
              ? _teacherDestinations(t, navColor)
              : _studentDestinations(t, navColor),
        ),
      ),
    );
  }

  // ─── Student Navigation Destinations ─────────────────────────
  List<NavigationDestination> _studentDestinations(
      String Function(String) t, Color color) {
    return [
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home, color: color),
        label: t('nav_home'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        selectedIcon: Icon(Icons.chat_bubble, color: color),
        label: t('nav_ai_teacher'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.picture_as_pdf_outlined),
        selectedIcon: Icon(Icons.picture_as_pdf, color: color),
        label: t('nav_courses'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.quiz_outlined),
        selectedIcon: Icon(Icons.quiz, color: color),
        label: t('nav_quiz'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.note_alt_outlined),
        selectedIcon: Icon(Icons.note_alt, color: color),
        label: t('nav_notes'),
      ),
    ];
  }

  // ─── Teacher Navigation Destinations ─────────────────────────
  List<NavigationDestination> _teacherDestinations(
      String Function(String) t, Color color) {
    return [
      NavigationDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded, color: color),
        label: t('nav_teacher_dashboard'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.book_outlined),
        selectedIcon: Icon(Icons.book_rounded, color: color),
        label: t('nav_teacher_courses'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.add_circle_outline_rounded),
        selectedIcon: Icon(Icons.add_circle_rounded, color: color),
        label: t('nav_teacher_quiz'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.groups_outlined),
        selectedIcon: Icon(Icons.groups_rounded, color: color),
        label: t('nav_teacher_students'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.auto_awesome_outlined),
        selectedIcon: Icon(Icons.auto_awesome_rounded, color: color),
        label: t('nav_teacher_ai'),
      ),
    ];
  }
}
