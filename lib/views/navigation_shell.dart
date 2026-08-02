import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../widgets/apple_ui_components.dart';
import 'home/home_screen.dart';
import 'home/courses_screen.dart';
import 'ai_teacher/ai_teacher_chat_screen.dart';
import 'pdf/pdf_chat_screen.dart';
import 'profile/profile_screen.dart';
import 'teacher/teacher_dashboard_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  late final List<Widget> _studentScreens;

  @override
  void initState() {
    super.initState();
    _studentScreens = [
      const HomeScreen(),
      const CoursesScreen(),
      const AiTeacherChatScreen(),
      const PdfChatScreen(),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    // ─── TEACHER ROLE NAVIGATION ─────────────────────────────────────
    if (user?.role == UserRole.teacher) {
      return Directionality(
        textDirection: langProvider.textDirection,
        child: Scaffold(
          body: const TeacherDashboardScreen(),
        ),
      );
    }

    // ─── STUDENT ROLE NAVIGATION ─────────────────────────────────────
    return Directionality(
      textDirection: langProvider.textDirection,
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _selectedIndex,
          children: _studentScreens,
        ),
        bottomNavigationBar: GlassBottomNavigation(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
