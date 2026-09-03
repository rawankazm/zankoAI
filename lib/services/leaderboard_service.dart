import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'score_service.dart';
import '../models/user_model.dart';

class BadgeModel {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final double progress; // 0.0 to 1.0

  BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    required this.progress,
  });
}

class StudentRankModel {
  final int rank;
  final String name;
  final String departmentName;
  final String universityName;
  final String? photoUrl;
  final int points;
  final int streak;
  final int score100;
  final bool isCurrentUser;

  StudentRankModel({
    required this.rank,
    required this.name,
    required this.departmentName,
    required this.universityName,
    this.photoUrl,
    required this.points,
    required this.streak,
    required this.score100,
    this.isCurrentUser = false,
  });
}

class LeaderboardService extends ChangeNotifier {
  static final LeaderboardService instance = LeaderboardService._();
  LeaderboardService._();

  /// Returns streak for current user via ScoreService (device-local).
  int get currentUserStreak => ScoreService.instance.streakCount;
  int get streakDays => currentUserStreak;

  int calculatePoints({
    required int studyMinutes,
    required int totalQuestions,
    required int score100,
    required int streak,
  }) {
    return (studyMinutes * 2) + (totalQuestions * 5) + (score100 * 10) + (streak * 40);
  }

  List<BadgeModel> getBadges(ScoreService scoreService) {
    final studyMins = scoreService.todayStudyMinutes;
    final totalQ = scoreService.totalQuestionsAnswered;
    final score100 = scoreService.totalScore100;

    return [
      BadgeModel(
        id: 'streak_3',
        title: '🔥 بەردەوامی ٣ ڕۆژ',
        description: 'بۆ ۳ ڕۆژ لەسەر یەک بەردەوام بە لەسەر خوێندن',
        icon: '🔥',
        isUnlocked: currentUserStreak >= 3,
        progress: (currentUserStreak / 3).clamp(0.0, 1.0),
      ),
      BadgeModel(
        id: 'quiz_master',
        title: '🎯 مامۆستای کویز',
        description: 'وەڵامدانەوەی لانی کەم ۲۰ پرسیار لە کویزەکاندا',
        icon: '🎯',
        isUnlocked: totalQ >= 20,
        progress: (totalQ / 20).clamp(0.0, 1.0),
      ),
      BadgeModel(
        id: 'study_hero',
        title: '📚 پاڵەوانی خوێندن',
        description: 'خوێندنی ۱۲۰ خولەک (۲ کاتژمێر) لە ڕۆژێکدا',
        icon: '📚',
        isUnlocked: studyMins >= 120,
        progress: (studyMins / 120).clamp(0.0, 1.0),
      ),
      BadgeModel(
        id: 'perfect_score',
        title: '💯 نمرەی بەرز',
        description: 'بەدەستهێنانی نمرەی ٨٠ یان زیاتر لە تاقیکردنەوەکاندا',
        icon: '👑',
        isUnlocked: score100 >= 80,
        progress: (score100 / 80).clamp(0.0, 1.0),
      ),
      BadgeModel(
        id: 'dept_leader',
        title: '🏆 پێشەنگی بەش',
        description: 'گەیشتن بە پلەی یەکەم تا سێیەم لە بەشەکەی خۆتدا',
        icon: '🥇',
        isUnlocked: true,
        progress: 1.0,
      ),
    ];
  }

  Future<List<String>> getRegisteredDepartments({UserModel? currentUser}) async {
    final Set<String> depts = {};

    // 1. Add current user's registered department first
    if (currentUser?.departmentName != null && currentUser!.departmentName!.trim().isNotEmpty) {
      depts.add(currentUser.departmentName!.trim());
    }

    // 2. Fetch registered student departments from Firestore (departments & leaderboard)
    try {
      final deptSnap = await FirebaseFirestore.instance.collection('departments').limit(50).get();
      for (var doc in deptSnap.docs) {
        final name = doc.data()['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          depts.add(name.trim());
        }
      }
      final lbSnap = await FirebaseFirestore.instance.collection('leaderboard').limit(50).get();
      for (var doc in lbSnap.docs) {
        final dept = doc.data()['departmentName'] as String?;
        if (dept != null && dept.trim().isNotEmpty) {
          depts.add(dept.trim());
        }
      }
    } catch (_) {}

    // 3. Fallback defaults if few registered users in DB
    final defaults = [
      'ئەندازیاری سیستەمی زانیاری',
      'تەکنەلۆجیای زانیاری',
      'پزیشکی گشتی',
      'ئەندازیاری کۆمپیوتەر',
      'یاسا',
      'پۆلی ١٢ زانستی',
      'پۆلی ١٢ وێژەیی',
    ];
    for (final d in defaults) {
      depts.add(d);
    }

    return depts.toList();
  }

  Future<List<StudentRankModel>> getLeaderboard({
    required UserModel? currentUser,
    required ScoreService scoreService,
    String? selectedDepartment,
  }) async {
    List<StudentRankModel> list = [];

    // Fallback/Demo students to make the leaderboard alive and dynamic
    final demoStudents = [
      StudentRankModel(
        rank: 1,
        name: 'ئاراس شێروانی',
        departmentName: 'تەکنەلۆجیای زانیاری',
        universityName: 'زانکۆی سلێمانی',
        points: 2450,
        streak: 12,
        score100: 95,
      ),
      StudentRankModel(
        rank: 2,
        name: 'لەنیا کاروان',
        departmentName: 'پزیشکی گشتی',
        universityName: 'زانکۆی هەولێری پزیشکی',
        points: 2180,
        streak: 9,
        score100: 92,
      ),
      StudentRankModel(
        rank: 3,
        name: 'دیار بەختیار',
        departmentName: 'ئەندازیاری کۆمپیوتەر',
        universityName: 'زانکۆی دهۆک',
        points: 1950,
        streak: 7,
        score100: 88,
      ),
      StudentRankModel(
        rank: 4,
        name: 'سارە عومەر',
        departmentName: 'یاسا',
        universityName: 'زانکۆی سەلاحەدین',
        points: 1720,
        streak: 6,
        score100: 85,
      ),
      StudentRankModel(
        rank: 5,
        name: 'ڕێبین محەمەد',
        departmentName: 'پۆلی ١٢ زانستی',
        universityName: 'ئامادەیی هەڵبجە',
        points: 1540,
        streak: 5,
        score100: 84,
      ),
      StudentRankModel(
        rank: 6,
        name: 'سۆما فارووق',
        departmentName: 'تەکنەلۆجیای زانیاری',
        universityName: 'زانکۆی سلێمانی',
        points: 1380,
        streak: 4,
        score100: 80,
      ),
      StudentRankModel(
        rank: 7,
        name: 'ئالان کامەران',
        departmentName: 'کۆمپیوتەر و ژیریی دەستکرد',
        universityName: 'زانکۆی سلێمانی',
        points: 1210,
        streak: 3,
        score100: 78,
      ),
    ];

    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirebaseFirestore.instance.collection('leaderboard').orderBy('points', descending: true).limit(30).get();
      } catch (_) {
        snap = await FirebaseFirestore.instance.collection('leaderboard').limit(30).get();
      }
      if (snap.docs.isNotEmpty) {
        for (var doc in snap.docs) {
          final d = doc.data();
          final name = d['name'] ?? 'Student';
          final dept = d['departmentName'] ?? 'تەکنەلۆجیای زانیاری';
          final uni = d['universityName'] ?? 'زانکۆی سلێمانی';
          final photo = d['photoUrl'];
          final isMe = currentUser != null && doc.id == currentUser.id;

          int pts = 0;
          int strk = 3;
          int sc100 = 0;

          if (isMe) {
            sc100 = scoreService.totalScore100;
            strk = currentUserStreak;
            pts = calculatePoints(
              studyMinutes: scoreService.todayStudyMinutes,
              totalQuestions: scoreService.totalQuestionsAnswered,
              score100: sc100,
              streak: strk,
            );
          } else {
            // Use actual Firestore score fields when available
            sc100 = (d['score100'] as num?)?.toInt() ?? (d['gpa'] != null ? ((d['gpa'] as num).toDouble() * 25).round().clamp(0, 100) : 60);
            strk = (d['studyStreak'] as num?)?.toInt() ?? 1;
            final totalQ = (d['totalQuestionsAnswered'] as num?)?.toInt() ?? 0;
            final studyMins = (d['todayStudyMinutes'] as num?)?.toInt() ?? 0;
            pts = calculatePoints(
              studyMinutes: studyMins,
              totalQuestions: totalQ,
              score100: sc100,
              streak: strk,
            );
            // Minimum floor so new users with no data still appear
            if (pts == 0) pts = 100;
          }

          list.add(
            StudentRankModel(
              rank: 0,
              name: name,
              departmentName: dept,
              universityName: uni,
              photoUrl: photo,
              points: pts,
              streak: strk,
              score100: sc100,
              isCurrentUser: isMe,
            ),
          );
        }
      }
    } catch (_) {}

    // Add demo items if list is empty or small
    if (list.length < 5) {
      list.addAll(demoStudents);
    }

    // Include current user if not in list
    if (currentUser != null && !list.any((e) => e.isCurrentUser)) {
      final myPts = calculatePoints(
        studyMinutes: scoreService.todayStudyMinutes,
        totalQuestions: scoreService.totalQuestionsAnswered,
        score100: scoreService.totalScore100,
        streak: currentUserStreak,
      );

      list.add(
        StudentRankModel(
          rank: 0,
          name: currentUser.name,
          departmentName: currentUser.departmentName ?? 'تەکنەلۆجیای زانیاری',
          universityName: currentUser.universityName ?? 'زانکۆی سلێمانی',
          photoUrl: currentUser.photoUrl,
          points: myPts,
          streak: currentUserStreak,
          score100: scoreService.totalScore100,
          isCurrentUser: true,
        ),
      );

      if (currentUser.id.isNotEmpty && !currentUser.isGuest) {
        FirebaseFirestore.instance.collection('leaderboard').doc(currentUser.id).set({
          'name': currentUser.name,
          'departmentName': currentUser.departmentName ?? 'تەکنەلۆجیای زانیاری',
          'universityName': currentUser.universityName ?? 'زانکۆی سلێمانی',
          'photoUrl': currentUser.photoUrl,
          'points': myPts,
          'streak': currentUserStreak,
          'score100': scoreService.totalScore100,
          'studyStreak': currentUserStreak,
          'totalQuestionsAnswered': scoreService.totalQuestionsAnswered,
          'todayStudyMinutes': scoreService.todayStudyMinutes,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).catchError((_) {});
      }
    }

    // Filter by department if specified and not 'all'
    if (selectedDepartment != null && selectedDepartment.isNotEmpty && selectedDepartment != 'all') {
      list = list.where((item) {
        return item.departmentName.toLowerCase().contains(selectedDepartment.toLowerCase()) ||
               selectedDepartment.toLowerCase().contains(item.departmentName.toLowerCase());
      }).toList();
    }

    // Sort descending by points
    list.sort((a, b) => b.points.compareTo(a.points));

    // Assign rank positions 1, 2, 3...
    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      list[i] = StudentRankModel(
        rank: i + 1,
        name: item.name,
        departmentName: item.departmentName,
        universityName: item.universityName,
        photoUrl: item.photoUrl,
        points: item.points,
        streak: item.streak,
        score100: item.score100,
        isCurrentUser: item.isCurrentUser,
      );
    }

    return list;
  }
}
