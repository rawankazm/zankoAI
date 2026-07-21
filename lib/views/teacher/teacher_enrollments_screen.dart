import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/language_provider.dart';
import '../../../services/notification_service.dart';

class TeacherEnrollmentsScreen extends StatefulWidget {
  const TeacherEnrollmentsScreen({super.key});

  @override
  State<TeacherEnrollmentsScreen> createState() =>
      _TeacherEnrollmentsScreenState();
}

class _TeacherEnrollmentsScreenState extends State<TeacherEnrollmentsScreen> {
  bool _isProcessing = false;

  Future<void> _handleApproval(
    String requestId,
    String studentName,
    String courseName,
    bool approve,
    DatabaseService db,
    String Function(String) t,
  ) async {
    setState(() => _isProcessing = true);

    if (approve) {
      await db.approveEnrollment(requestId);

      // Simulate sending local notification to student
      final notifyService = NotificationService();
      await notifyService.showInstantNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: t('request_approved_title'),
        body: '${t("request_approved_body")} "$courseName"',
      );
    } else {
      await db.rejectEnrollment(requestId);
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'داواکارییەکە قبوڵکرا! ✅' : 'داواکارییەکە ڕەتکرایەوە. ❌',
            style: const TextStyle(fontFamily: 'Noto Sans Arabic'),
          ),
          backgroundColor: approve ? const Color(0xFF059669) : const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Provider.of<LanguageProvider>(context);
    final db = Provider.of<DatabaseService>(context);
    final auth = Provider.of<AuthService>(context);
    String t(String key) => lang.translate(key);

    final currentUser = auth.currentUser;
    final teacherName = currentUser?.name ?? 'د. سارا محمد';

    // Get pending enrollment requests for this teacher
    final pendingRequests = db.enrollmentRequests
        .where((r) => r['teacherName'] == teacherName && r['status'] == 'pending')
        .toList();

    const purple = Color(0xFF7C3AED);

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('enrollment_requests'),
              style: const TextStyle(fontFamily: 'Noto Sans Arabic')),
          centerTitle: true,
          backgroundColor: purple,
          foregroundColor: Colors.white,
        ),
        body: pendingRequests.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.supervised_user_circle_outlined,
                      size: 72,
                      color: theme.colorScheme.outline.withOpacity(0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t('no_pending_requests'),
                      style: TextStyle(
                        fontFamily: 'Noto Sans Arabic',
                        fontSize: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pendingRequests.length,
                itemBuilder: (context, i) {
                  final req = pendingRequests[i];
                  final reqId = req['id'] as String;
                  final sName = req['studentName'] as String;
                  final sEmail = req['studentEmail'] as String;
                  final cName = req['courseName'] as String;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: purple.withOpacity(0.1),
                              child: Text(
                                sName.isNotEmpty ? sName[0] : 'ق',
                                style: const TextStyle(
                                  color: purple,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Noto Sans Arabic',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Noto Sans Arabic',
                                    ),
                                  ),
                                  Text(
                                    sEmail,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Icon(
                              Icons.book_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${t("nav_courses")}: ',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontFamily: 'Noto Sans Arabic',
                              ),
                            ),
                            Text(
                              cName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: purple,
                                fontFamily: 'Noto Sans Arabic',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _handleApproval(
                                          reqId,
                                          sName,
                                          cName,
                                          false,
                                          db,
                                          t,
                                        ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                ),
                                child: Text(
                                  t('reject'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Noto Sans Arabic',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _handleApproval(
                                          reqId,
                                          sName,
                                          cName,
                                          true,
                                          db,
                                          t,
                                        ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                ),
                                child: Text(
                                  t('approve'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Noto Sans Arabic',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
