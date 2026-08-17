import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/language_provider.dart';
import '../services/auth_service.dart';
import '../widgets/apple_ui_components.dart';
import '../widgets/app_exit_dialog.dart';
import 'home/home_screen.dart';
import 'home/courses_screen.dart';
import 'ai_teacher/ai_teacher_chat_screen.dart';
import 'zankoline/zankoline_screen.dart';
import 'profile/profile_screen.dart';
import 'notifications/notifications_screen.dart';
import '../theme.dart';

class NavigationShell extends StatefulWidget {
  const NavigationShell({super.key});

  @override
  State<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends State<NavigationShell> {
  int _selectedIndex = 0;
  StreamSubscription? _directMessageSubscription;
  StreamSubscription? _broadcastSubscription;
  final Set<String> _notifiedDocIds = {};

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
      _listenForRealtimeDirectMessages();
    });
  }

  @override
  void dispose() {
    _directMessageSubscription?.cancel();
    _broadcastSubscription?.cancel();
    super.dispose();
  }

  void _listenForRealtimeDirectMessages() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;
    if (user == null || user.isGuest) return;

    // 1. Direct Messages Listener (Messages targeted to this user)
    _directMessageSubscription = FirebaseFirestore.instance
        .collection('direct_messages')
        .where('userId', isEqualTo: user.id)
        .snapshots()
        .listen((snap) {
      for (var doc in snap.docs) {
        final data = doc.data();
        final isRead = data['isRead'] == true;
        final docId = doc.id;

        if (!isRead && !_notifiedDocIds.contains(docId)) {
          _notifiedDocIds.add(docId);
          final senderName = data['senderName'] ?? '👑 ئەدمینی ZankoAI';
          final title = data['title'] ?? data['header'] ?? data['subject'] ?? 'پەیام لە ئەدمینەوە';
          final message = data['message'] ?? data['body'] ?? data['content'] ?? data['text'] ?? '';
          final displayTitle = '$senderName • $title';

          if (mounted) {
            HapticFeedback.mediumImpact();
            _showInAppNotificationBanner(displayTitle, message.toString(), docId, isDirect: true);
          }
        }
      }
    });

    // 2. Broadcast Notifications Listener (Announcements to all or VIP)
    _broadcastSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .snapshots()
        .listen((snap) {
      for (var doc in snap.docs) {
        final data = doc.data();
        final docId = doc.id;
        final target = (data['target'] ?? data['to'] ?? 'all').toString().toLowerCase();
        final docUserId = data['userId'] ?? data['user_id'] ?? data['recipientId'];

        final isTargeted = target == 'all' ||
            target == 'all_students' ||
            target == 'students' ||
            (target == 'vip' && user.isVip) ||
            (docUserId != null && docUserId == user.id);

        if (isTargeted && !_notifiedDocIds.contains(docId)) {
          _notifiedDocIds.add(docId);
          final title = data['title'] ?? data['header'] ?? data['subject'] ?? '📢 ئاگاداریی ئەدمین';
          final body = data['body'] ?? data['message'] ?? data['content'] ?? data['text'] ?? '';

          if (mounted) {
            HapticFeedback.mediumImpact();
            _showInAppNotificationBanner(title.toString(), body.toString(), docId, isDirect: false);
          }
        }
      }
    });
  }

  void _showInAppNotificationBanner(String title, String body, String docId, {bool isDirect = true}) {
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 10, left: 16, right: 16, bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: ZankoColors.darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: ZankoColors.primary, width: 1.5),
        ),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ZankoColors.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDirect ? CupertinoIcons.mail_solid : CupertinoIcons.bell_fill,
                color: isDirect ? ZankoColors.accent : const Color(0xFFFF9F0A),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'بینین',
          textColor: const Color(0xFFFFD700),
          onPressed: () {
            if (isDirect) {
              FirebaseFirestore.instance
                  .collection('direct_messages')
                  .doc(docId)
                  .update({'isRead': true});
            }
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (_) => const NotificationsScreen()),
            );
          },
        ),
      ),
    );
  }


  void _onItemTapped(int index) {
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
          body: IndexedStack(
            index: _selectedIndex,
            children: _studentScreens,
          ),
          bottomNavigationBar: GlassBottomNavigation(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}
