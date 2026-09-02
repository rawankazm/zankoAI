import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ScoreService extends ChangeNotifier {
  static final ScoreService instance = ScoreService._();
  ScoreService._() {
    loadScores();
  }

  int _quizTotalQuestions = 0;
  int _quizCorrectAnswers = 0;

  int _examTotalQuestions = 0;
  int _examCorrectAnswers = 0;

  int _todayStudyMinutes = 0;

  int get quizTotalQuestions => _quizTotalQuestions;
  int get quizCorrectAnswers => _quizCorrectAnswers;
  int get examTotalQuestions => _examTotalQuestions;
  int get examCorrectAnswers => _examCorrectAnswers;
  int get todayStudyMinutes => _todayStudyMinutes;

  int get totalQuestionsAnswered => _quizTotalQuestions + _examTotalQuestions;

  double get overallAccuracy {
    if (totalQuestionsAnswered == 0) return 0.0;
    final totalCorrect = _quizCorrectAnswers + _examCorrectAnswers;
    return (totalCorrect / totalQuestionsAnswered).clamp(0.0, 1.0);
  }

  /// Quiz score out of 40 marks
  double get quizScore40 {
    if (_quizTotalQuestions == 0) return 0.0;
    return (_quizCorrectAnswers / _quizTotalQuestions) * 40.0;
  }

  /// Exam score out of 60 marks
  double get examScore60 {
    if (_examTotalQuestions == 0) return 0.0;
    return (_examCorrectAnswers / _examTotalQuestions) * 60.0;
  }

  /// Total combined score out of 100 marks (starts at 0)
  int get totalScore100 {
    if (_quizTotalQuestions == 0 && _examTotalQuestions == 0) return 0;
    return (quizScore40 + examScore60).round().clamp(0, 100);
  }

  Future<void> loadScores() async {
    final prefs = await SharedPreferences.getInstance();
    _quizTotalQuestions = prefs.getInt('score_quiz_total') ?? 0;
    _quizCorrectAnswers = prefs.getInt('score_quiz_correct') ?? 0;
    _examTotalQuestions = prefs.getInt('score_exam_total') ?? 0;
    _examCorrectAnswers = prefs.getInt('score_exam_correct') ?? 0;
    _todayStudyMinutes = prefs.getInt('today_study_minutes') ?? 0;
    await checkAndUpdateStreak();
    notifyListeners();
  }

  Future<void> addQuizResult({required int correct, required int total}) async {
    _quizTotalQuestions += total;
    _quizCorrectAnswers += correct;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('score_quiz_total', _quizTotalQuestions);
    await prefs.setInt('score_quiz_correct', _quizCorrectAnswers);
    notifyListeners();
  }

  Future<void> addExamResult({required int correct, required int total}) async {
    _examTotalQuestions += total;
    _examCorrectAnswers += correct;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('score_exam_total', _examTotalQuestions);
    await prefs.setInt('score_exam_correct', _examCorrectAnswers);
    notifyListeners();
  }

  Future<void> addStudyMinutes(int minutes) async {
    _todayStudyMinutes += minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('today_study_minutes', _todayStudyMinutes);
    notifyListeners();
  }

  // ─── Daily Study Streak 🔥 ────────────────────────────────────────────────
  int _streakCount = 1;
  String? _lastStreakDate;
  int get streakCount => _streakCount;

  bool get isStreakCompletedToday {
    if (_lastStreakDate == null) return false;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _lastStreakDate == todayStr;
  }

  Future<void> checkAndUpdateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    _streakCount = prefs.getInt('study_streak_count') ?? 1;
    _lastStreakDate = prefs.getString('study_last_streak_date');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (_lastStreakDate == null) {
      _streakCount = 1;
      _lastStreakDate = todayStr;
      await prefs.setInt('study_streak_count', _streakCount);
      await prefs.setString('study_last_streak_date', todayStr);
    } else {
      final parts = _lastStreakDate!.split('-').map(int.parse).toList();
      final lastDate = DateTime(parts[0], parts[1], parts[2]);
      final diffDays = today.difference(lastDate).inDays;

      if (diffDays == 1) {
        // Consecutive day streak increment!
        _streakCount += 1;
        _lastStreakDate = todayStr;
        await prefs.setInt('study_streak_count', _streakCount);
        await prefs.setString('study_last_streak_date', todayStr);
      } else if (diffDays > 1) {
        // Missed more than 1 day - reset streak
        _streakCount = 1;
        _lastStreakDate = todayStr;
        await prefs.setInt('study_streak_count', _streakCount);
        await prefs.setString('study_last_streak_date', todayStr);
      }
    }
    syncToCloud();
    notifyListeners();
  }

  /// Syncs current study progress and streak count to user's Firestore profile
  Future<void> syncToCloud([String? uid]) async {
    try {
      final targetUid = uid ?? FirebaseAuth.instance.currentUser?.uid;
      if (targetUid != null && targetUid.isNotEmpty && !targetUid.startsWith('guest_')) {
        await FirebaseFirestore.instance.collection('users').doc(targetUid).set({
          'studyStreak': _streakCount,
          'lastStreakDate': _lastStreakDate,
          'todayStudyMinutes': _todayStudyMinutes,
          'totalQuestionsAnswered': totalQuestionsAnswered,
          'score100': totalScore100,
          'lastScoreSync': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  Future<void> resetScores() async {
    _quizTotalQuestions = 0;
    _quizCorrectAnswers = 0;
    _examTotalQuestions = 0;
    _examCorrectAnswers = 0;
    _todayStudyMinutes = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('score_quiz_total');
    await prefs.remove('score_quiz_correct');
    await prefs.remove('score_exam_total');
    await prefs.remove('score_exam_correct');
    await prefs.remove('today_study_minutes');
    notifyListeners();
  }
}
