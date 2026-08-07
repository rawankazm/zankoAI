import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreService extends ChangeNotifier {
  static final ScoreService instance = ScoreService._();
  ScoreService._() {
    loadScores();
  }

  int _quizTotalQuestions = 0;
  int _quizCorrectAnswers = 0;

  int _examTotalQuestions = 0;
  int _examCorrectAnswers = 0;

  int get quizTotalQuestions => _quizTotalQuestions;
  int get quizCorrectAnswers => _quizCorrectAnswers;
  int get examTotalQuestions => _examTotalQuestions;
  int get examCorrectAnswers => _examCorrectAnswers;

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

  Future<void> resetScores() async {
    _quizTotalQuestions = 0;
    _quizCorrectAnswers = 0;
    _examTotalQuestions = 0;
    _examCorrectAnswers = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('score_quiz_total');
    await prefs.remove('score_quiz_correct');
    await prefs.remove('score_exam_total');
    await prefs.remove('score_exam_correct');
    notifyListeners();
  }
}
