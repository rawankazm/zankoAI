import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_provider.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() => _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _staticStudents = [
    {
      'name': 'ئاراس ئەحمەد',
      'email': 'aras@zanko.edu',
      'course': 'تۆڕەکان',
      'avgScore': 88.5,
      'quizzesTaken': 5,
      'gpa': 3.65,
      'avatar': 'آ',
      'color': const Color(0xFF2196F3),
    },
    {
      'name': 'سارا کەریم',
      'email': 'sara@zanko.edu',
      'course': 'داتابەیس',
      'avgScore': 92.0,
      'quizzesTaken': 4,
      'gpa': 3.90,
      'avatar': 'س',
      'color': const Color(0xFF9C27B0),
    },
    {
      'name': 'هاوکار ئەمین',
      'email': 'hawkar@zanko.edu',
      'course': 'ئەمنیەتی سایبەر',
      'avgScore': 75.3,
      'quizzesTaken': 3,
      'gpa': 3.20,
      'avatar': 'ه',
      'color': const Color(0xFF4CAF50),
    },
    {
      'name': 'لانە محمد',
      'email': 'lana@zanko.edu',
      'course': 'تۆڕەکان',
      'avgScore': 95.0,
      'quizzesTaken': 5,
      'gpa': 3.95,
      'avatar': 'ل',
      'color': const Color(0xFFFF9800),
    },
    {
      'name': 'کاروان ئیبراهیم',
      'email': 'karwan@zanko.edu',
      'course': 'داتابەیس',
      'avgScore': 68.0,
      'quizzesTaken': 2,
      'gpa': 2.85,
      'avatar': 'ک',
      'color': const Color(0xFFF44336),
    },
  ];

  List<Map<String, dynamic>> _getAllStudents(DatabaseService db, AuthService auth) {
    final teacherName = auth.currentUser?.name ?? 'د. سارا محمد';

    // Get approved enrollment requests for this teacher
    final approvedRequests = db.enrollmentRequests
        .where((r) => r['teacherName'] == teacherName && r['status'] == 'approved')
        .toList();

    // Map approved enrollment requests to student profiles
    final dynamicStudents = approvedRequests.map((req) {
      final sName = req['studentName'] as String;
      return {
        'name': sName,
        'email': req['studentEmail'] as String,
        'course': req['courseName'] as String,
        'avgScore': 85.0, // Default mock score
        'quizzesTaken': 2,
        'gpa': 3.40,
        'avatar': sName.isNotEmpty ? sName[0] : 'ق',
        'color': const Color(0xFF7C3AED),
      };
    }).toList();

    return [..._staticStudents, ...dynamicStudents];
  }

  List<Map<String, dynamic>> _getFilteredStudents(List<Map<String, dynamic>> allStudents) {
    if (_searchQuery.isEmpty) return allStudents;
    return allStudents
        .where((s) =>
            (s['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (s['email'] as String).toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Provider.of<LanguageProvider>(context);
    final db = Provider.of<DatabaseService>(context);
    final auth = Provider.of<AuthService>(context);
    String t(String key) => lang.translate(key);
    const blue = Color(0xFF0284C7);

    final allStudents = _getAllStudents(db, auth);
    final filteredStudents = _getFilteredStudents(allStudents);

    // Calculate dynamic average
    final double avgScoreSum = allStudents.isNotEmpty
        ? allStudents.map((s) => s['avgScore'] as double).reduce((a, b) => a + b)
        : 0.0;
    final double avgScore = allStudents.isNotEmpty ? avgScoreSum / allStudents.length : 0.0;

    return Directionality(
      textDirection: lang.textDirection,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t('teacher_students_title'),
              style: const TextStyle(fontFamily: 'Noto Sans Arabic')),
          centerTitle: true,
          backgroundColor: blue,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            // ─── Summary Banner ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                ),
              ),
              child: Row(
                children: [
                  _SummaryChip(
                      icon: Icons.people_rounded,
                      label: '${allStudents.length}',
                      sublabel: t('teacher_stats_students')),
                  const SizedBox(width: 12),
                  _SummaryChip(
                      icon: Icons.trending_up_rounded,
                      label: '${avgScore.toStringAsFixed(1)}%',
                      sublabel: t('avg_score')),
                ],
              ),
            ),

            // ─── Search Bar ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: '${t("teacher_stats_students")}...',
                  hintStyle: const TextStyle(fontFamily: 'Noto Sans Arabic'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(fontFamily: 'Noto Sans Arabic'),
              ),
            ),

            // ─── Student List ────────────────────────────────────
            Expanded(
              child: filteredStudents.isEmpty
                  ? Center(
                      child: Text(t('no_students_yet'),
                          style: TextStyle(
                              fontFamily: 'Noto Sans Arabic',
                              color: theme.colorScheme.onSurface.withOpacity(0.5))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, i) {
                        final s = filteredStudents[i];
                        final color = s['color'] as Color;
                        final studentAvgScore = s['avgScore'] as double;
                        final scoreColor = studentAvgScore >= 85
                            ? const Color(0xFF059669)
                            : studentAvgScore >= 70
                                ? const Color(0xFFD97706)
                                : const Color(0xFFDC2626);

                        return GestureDetector(
                          onTap: () => _showStudentDetail(context, s, lang, t),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: color.withOpacity(0.15),
                                  child: Text(
                                    s['avatar'] as String,
                                    style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        fontFamily: 'Noto Sans Arabic'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['name'] as String,
                                          style: const TextStyle(
                                              fontFamily: 'Noto Sans Arabic',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${s['course']} • ${s['quizzesTaken']} ${t('quizzes_taken')}',
                                        style: TextStyle(
                                            fontFamily: 'Noto Sans Arabic',
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface.withOpacity(0.55)),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: scoreColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${studentAvgScore.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                        fontFamily: 'Noto Sans Arabic',
                                        fontWeight: FontWeight.bold,
                                        color: scoreColor,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetail(BuildContext context, Map<String, dynamic> s,
      LanguageProvider lang, String Function(String) t) {
    final theme = Theme.of(context);
    final color = s['color'] as Color;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Directionality(
        textDirection: lang.textDirection,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: color.withOpacity(0.15),
                child: Text(s['avatar'] as String,
                    style: TextStyle(
                        color: color,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Noto Sans Arabic')),
              ),
              const SizedBox(height: 12),
              Text(s['name'] as String,
                  style: const TextStyle(
                      fontFamily: 'Noto Sans Arabic',
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(s['email'] as String,
                  style: TextStyle(
                      fontFamily: 'Noto Sans Arabic',
                      color: theme.colorScheme.onSurface.withOpacity(0.55))),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _DetailStat(label: t('avg_score'), value: '${(s['avgScore'] as double).toStringAsFixed(1)}%', color: color),
                  _DetailStat(label: 'GPA', value: '${s['gpa']}', color: color),
                  _DetailStat(label: t('quizzes_taken'), value: '${s['quizzesTaken']}', color: color),
                ],
              ),
              const SizedBox(height: 20),
              // Score bar
              Text(t('student_performance'),
                  style: const TextStyle(fontFamily: 'Noto Sans Arabic', fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (s['avgScore'] as double) / 100,
                  minHeight: 12,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  const _SummaryChip({required this.icon, required this.label, required this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: 'Noto Sans Arabic')),
              Text(sublabel,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11, fontFamily: 'Noto Sans Arabic')),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DetailStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontFamily: 'Noto Sans Arabic',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontFamily: 'Noto Sans Arabic',
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),
      ],
    );
  }
}
