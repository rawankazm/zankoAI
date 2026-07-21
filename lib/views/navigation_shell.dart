import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import 'home/home_screen.dart';
import 'ai_teacher/ai_teacher_screen.dart';
import 'pdf/pdf_summary_screen.dart';
import 'quiz/quiz_screen.dart';
import 'notes/notes_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = [
    HomeScreen(),
    AiTeacherScreen(),
    PdfSummaryScreen(),
    QuizScreen(),
    NotesScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    String t(String key) => langProvider.translate(key);

    const studentPrimary = Color(0xFF1565C0);

    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: _onItemTapped,
          indicatorColor: studentPrimary.withOpacity(0.15),
          destinations: _studentDestinations(t, studentPrimary),
        ),
      ),
    );
  }

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
}
