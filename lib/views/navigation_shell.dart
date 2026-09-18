import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/language_provider.dart';
import '../widgets/apple_ui_components.dart';
import '../widgets/app_exit_dialog.dart';
import 'home/home_screen.dart';
import 'home/courses_screen.dart';
import 'ai_teacher/ai_teacher_chat_screen.dart';
import 'zankoline/zankoline_screen.dart';
import 'profile/profile_screen.dart';
import '../services/app_version_service.dart';
import 'update/force_update_screen.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  /// Global notifier to show/hide the bottom navigation bar from any child view.
  static final ValueNotifier<bool> hideBottomNav = ValueNotifier<bool>(false);

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;

  List<Widget> get _studentScreens => const [
    HomeScreen(),
    CoursesScreen(),
    AiTeacherChatScreen(),
    ZankolineScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppVersionService().startListening((updateInfo) {
        if (mounted && updateInfo.isUpdateAvailable && updateInfo.isForced) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => ForceUpdateScreen(updateInfo: updateInfo),
            ),
            (route) => false,
          );
        }
      });
    });
  }

  void _onItemTapped(int index) {
    if (NavigationShell.hideBottomNav.value) {
      NavigationShell.hideBottomNav.value = false;
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);

    return Directionality(
      textDirection: langProvider.textDirection,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          if (_selectedIndex != 0) {
            setState(() => _selectedIndex = 0);
            return;
          }

          final shouldExit = await AppExitDialog.show(context);
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
          extendBody: true,
          body: IndexedStack(index: _selectedIndex, children: _studentScreens),
          bottomNavigationBar: ValueListenableBuilder<bool>(
            valueListenable: NavigationShell.hideBottomNav,
            builder: (context, hide, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                height: hide ? 0.0 : 100.0,
                child: OverflowBox(
                  minHeight: 0.0,
                  maxHeight: 100.0,
                  alignment: Alignment.topCenter,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeInOutCubic,
                    offset: hide ? const Offset(0, 1.2) : Offset.zero,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: hide ? 0.0 : 1.0,
                      child: IgnorePointer(
                        ignoring: hide,
                        child: GlassBottomNavigation(
                          currentIndex: _selectedIndex,
                          onTap: _onItemTapped,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
