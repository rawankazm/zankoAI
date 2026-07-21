import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/database_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/language_provider.dart';
import '../../../services/notification_service.dart';

class StudentCoursesEnrollScreen extends StatefulWidget {
  const StudentCoursesEnrollScreen({super.key});

  @override
  State<StudentCoursesEnrollScreen> createState() =>
      _StudentCoursesEnrollScreenState();
}

class _StudentCoursesEnrollScreenState
    extends State<StudentCoursesEnrollScreen> {
  final List<Map<String, String>> _availableCourses = [
    {
      'courseName': 'سیستەمی کارپێکردن',
      'teacherName': 'د. سارا محمد',
      'code': 'CS301',
    },
    {
      'courseName': 'داتابەیس',
      'teacherName': 'د. سارا محمد',
      'code': 'CS302',
    },
    {
      'courseName': 'ئەمنیەتی سایبەر',
      'teacherName': 'د. سارا محمد',
      'code': 'CS401',
    },
    {
      'courseName': 'بەرنامەسازی موبایل',
      'teacherName': 'م. ئاسۆ ئەحمەد',
      'code': 'CS402',
    },
    {
      'courseName': 'زەکاتی ژیری دەستکرد',
      'teacherName': 'د. ڕێبین ئەحمەد',
      'code': 'AI101',
    },
  ];

  bool _isRequesting = false;

  Future<void> _enrollRequest(
    String courseName,
    String teacherName,
    String studentName,
    String studentEmail,
    DatabaseService db,
    String Function(String) t,
  ) async {
    setState(() => _isRequesting = true);

    await db.requestEnrollment(studentName, studentEmail, courseName, teacherName);

    // Simulate sending local notification to the teacher/student
    final notifyService = NotificationService();
    await notifyService.showInstantNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: t('new_request_title'),
      body: '${t("new_request_body")}: $courseName',
    );

    if (mounted) {
      setState(() => _isRequesting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('enroll_success'),
              style: const TextStyle(fontFamily: 'Noto Sans Arabic')),
          backgroundColor: const Color(0xFF059669),
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
    final studentEmail = currentUser?.email ?? 'student@zanko.edu';
    final studentName = currentUser?.name ?? 'خوێندکار';

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('course_enrollment'),
              style: const TextStyle(fontFamily: 'Noto Sans Arabic')),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _availableCourses.length,
          itemBuilder: (context, i) {
            final course = _availableCourses[i];
            final cName = course['courseName']!;
            final tName = course['teacherName']!;
            final code = course['code']!;

            // Find current enrollment status
            final requests = db.enrollmentRequests.where((r) =>
                r['studentEmail'] == studentEmail &&
                r['courseName'] == cName);

            final hasRequest = requests.isNotEmpty;
            final status = hasRequest ? requests.first['status'] as String : '';

            Color statusColor = const Color(0xFF8E8E93);
            String statusLabel = '';

            if (status == 'pending') {
              statusColor = const Color(0xFFD97706);
              statusLabel = t('pending_approval');
            } else if (status == 'approved') {
              statusColor = const Color(0xFF059669);
              statusLabel = t('approved');
            } else if (status == 'rejected') {
              statusColor = const Color(0xFFDC2626);
              statusLabel = t('rejected');
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasRequest
                      ? statusColor.withOpacity(0.4)
                      : theme.colorScheme.outline.withOpacity(0.15),
                  width: hasRequest ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                  // Book icon container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (hasRequest ? statusColor : const Color(0xFF1565C0))
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: hasRequest ? statusColor : const Color(0xFF1565C0),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Course & Teacher details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              code,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          cName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Noto Sans Arabic',
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface.withOpacity(0.5)),
                            const SizedBox(width: 4),
                            Text(
                              tName,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                                fontFamily: 'Noto Sans Arabic',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action Button or Status Chip
                  if (hasRequest)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontFamily: 'Noto Sans Arabic',
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isRequesting
                          ? null
                          : () => _enrollRequest(
                                cName,
                                tName,
                                studentName,
                                studentEmail,
                                db,
                                t,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      child: Text(
                        t('request_enrollment'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Noto Sans Arabic',
                        ),
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
}
