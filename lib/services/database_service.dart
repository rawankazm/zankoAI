import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../models/schedule_model.dart';
import '../models/quiz_model.dart';
import '../models/flashcard_model.dart';
import '../models/reminder_model.dart';

abstract class DatabaseService extends ChangeNotifier {
  List<NoteModel> get notes;
  List<ScheduleModel> get schedule;
  List<QuizModel> get quizzes;
  List<FlashcardModel> get flashcards;
  List<ReminderModel> get reminders;
  List<Map<String, dynamic>> get enrollmentRequests;

  int get completedPomodoros;
  int get quizzesTaken;
  int get flashcardsFlipped;

  Future<void> loadData();
  Future<void> addNote(NoteModel note);
  Future<void> updateNote(NoteModel note);
  Future<void> deleteNote(String noteId);
  Future<void> addScheduleItem(ScheduleModel item);
  Future<void> deleteScheduleItem(String itemId);
  Future<void> addQuiz(QuizModel quiz);
  
  Future<void> addFlashcard(FlashcardModel card);
  Future<void> clearFlashcards();
  Future<void> addReminder(ReminderModel reminder);
  Future<void> toggleReminder(String id);
  Future<void> deleteReminder(String id);

  Future<void> requestEnrollment(String studentName, String studentEmail, String courseName, String teacherName);
  Future<void> approveEnrollment(String requestId);
  Future<void> rejectEnrollment(String requestId);

  void incrementPomodoros();
  void incrementQuizzesTaken();
  void incrementFlashcardsFlipped();
}

class MockDatabaseService extends ChangeNotifier implements DatabaseService {
  final List<NoteModel> _notes = [];
  final List<ScheduleModel> _schedule = [];
  final List<QuizModel> _quizzes = [];
  final List<FlashcardModel> _flashcards = [];
  final List<ReminderModel> _reminders = [];
  final List<Map<String, dynamic>> _enrollmentRequests = [];

  int _completedPomodoros = 1;
  int _quizzesTaken = 2;
  int _flashcardsFlipped = 4;

  @override
  List<NoteModel> get notes => _notes;
  @override
  List<ScheduleModel> get schedule => _schedule;
  @override
  List<QuizModel> get quizzes => _quizzes;
  @override
  List<FlashcardModel> get flashcards => _flashcards;
  @override
  List<ReminderModel> get reminders => _reminders;
  @override
  List<Map<String, dynamic>> get enrollmentRequests => _enrollmentRequests;

  @override
  int get completedPomodoros => _completedPomodoros;
  @override
  int get quizzesTaken => _quizzesTaken;
  @override
  int get flashcardsFlipped => _flashcardsFlipped;

  MockDatabaseService() {
    _loadInitialData();
  }

  void _loadInitialData() {
    // Kurdish mock notes
    _notes.addAll([
      NoteModel(
        id: 'n1',
        title: 'تێبینی دەربارەی سیستەمی کارپێکردن',
        content: 'سیستەمی کارپێکردن (OS) بریتییە لەو نەرمەکاڵایەی کە ڕەقەکاڵاکان و نەرمەکاڵاکانی تر بەڕێوەدەبات. کارە سەرەکییەکانی بریتین لە: بەڕێوەبردنی یادگە (Memory Management)، بەڕێوەبردنی پڕۆسسەکان (Process Management)، و سیستەمی فایلەکان (File System).',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        isAiFormatted: true,
        courseName: 'سیستەمی کارپێکردن',
      ),
      NoteModel(
        id: 'n2',
        title: 'کورتەی وانەی داتابەیس',
        content: 'داتابەیس (Database) سیستەمێکە بۆ کۆکردنەوە و ڕێکخستنی زانیارییەکان بە شێوازێک کە ئاسان بێت بۆ بەدەستهێنانەوە و دەستکاریکردن. جۆرە سەرەکییەکانی داتابەیس بریتین لە داتابەیسی پەیوەندیار (Relational DB) و داتابەیسی ناپەیوەندیار (NoSQL).',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isAiFormatted: false,
        courseName: 'بنکەی زانیاری',
      ),
    ]);

    // Kurdish schedule items
    _schedule.addAll([
      ScheduleModel(
        id: 's1',
        courseName: 'سیستەمی کارپێکردن (OS)',
        time: '08:30 - 10:00',
        location: 'هۆڵی ٤، بەشی تەکنەلۆجیای زانیاری',
        dayName: 'شەممە',
        teacherName: 'د. ڕێبین ئەحمەد',
      ),
      ScheduleModel(
        id: 's2',
        courseName: 'بەرنامەسازی پێشکەوتوو (Dart & Flutter)',
        time: '10:15 - 11:45',
        location: 'لابۆراتۆری ٣، بەشی کۆمپیوتەر',
        dayName: 'شەممە',
        teacherName: 'م. شادان عومەر',
      ),
      ScheduleModel(
        id: 's3',
        courseName: 'بنکەی زانیاری',
        time: '08:30 - 10:00',
        location: 'هۆڵی ٢، بەشی تەکنەلۆجیای زانیاری',
        dayName: 'یەکشەممە',
        teacherName: 'م. هێمن مستەفا',
      ),
      ScheduleModel(
        id: 's4',
        courseName: 'پێداچوونەوەی پڕۆژەی دەرچوون',
        time: '12:00 - 13:30',
        location: 'هۆڵی فڕەنسی',
        dayName: 'دووشەممە',
        teacherName: 'د. ڕێبین ئەحمەد',
      ),
    ]);

    // Kurdish quizzes
    _quizzes.add(
      QuizModel(
        id: 'q1',
        title: 'کوزی بنەماکانی کۆمپیوتەر',
        courseName: 'بنەماکانی کۆمپیوتەر',
        durationMinutes: 10,
        questions: [
          QuestionModel(
            id: 'q1_1',
            questionText: 'سی پی یو (CPU) مێشکی کۆمپیوتەرە و بەرپرسە لە پڕۆسێسکردنی فەرمانەکان.',
            type: QuestionType.trueFalse,
            correctAnswer: 'ڕاستە',
          ),
          QuestionModel(
            id: 'q1_2',
            questionText: 'کام لەمانە وەک یادگەی کاتی (Volatile memory) دادەنرێت؟',
            type: QuestionType.multipleChoice,
            options: ['RAM', 'ROM', 'HDD', 'SSD'],
            correctAnswer: 'RAM',
          ),
          QuestionModel(
            id: 'q1_3',
            questionText: 'بەشی سەرەکی و گرنگی ڕەقەکاڵا کە هەموو بەشەکانی تری پێوە دەبەسترێتەوە پێی دەوترێت: ______',
            type: QuestionType.fillInBlank,
            correctAnswer: 'Motherboard',
          ),
        ],
      ),
    );

    // Initial Flashcards
    _flashcards.addAll([
      FlashcardModel(
        id: 'c1',
        front: 'مۆدێلی OSI چییە؟',
        back: 'ڕێکخراوێکە بۆ لێکتێگەیشتنی پرۆتۆکۆلەکانی تۆڕ لە ٧ چینی جیاوازدا.',
      ),
      FlashcardModel(
        id: 'c2',
        front: 'کارکردنی CPU چییە؟',
        back: 'ئامێری سەرەکی جێبەجێکردنی فەرمانەکان و پرۆسێسەکردنی زانیارییەکان لە کۆمپیوتەردا.',
      ),
    ]);

    // Initial Homework Reminders
    _reminders.addAll([
      ReminderModel(
        id: 'rem_1',
        title: 'ڕادەستکردنی ڕاپۆرتی پڕۆسێسەکانی OS',
        deadline: DateTime.now().add(const Duration(days: 2, hours: 4)),
        courseName: 'سیستەمی کارپێکردن',
        isCompleted: false,
      ),
      ReminderModel(
        id: 'rem_2',
        title: 'تاقیکردنەوەی تیۆری داتابەیس',
        deadline: DateTime.now().add(const Duration(days: 5)),
        courseName: 'بنکەی زانیاری',
        isCompleted: false,
      ),
    ]);

    // Prepopulate some mock enrollment requests
    _enrollmentRequests.addAll([
      {
        'id': 'req_1',
        'studentName': 'ڕاوەن شێرکۆ',
        'studentEmail': 'rawan.sherko@gmail.com',
        'courseName': 'سیستەمی کارپێکردن',
        'teacherName': 'د. سارا محمد',
        'status': 'pending',
        'createdAt': DateTime.now().subtract(const Duration(hours: 3)),
      },
      {
        'id': 'req_2',
        'studentName': 'ڕاوەن شێرکۆ',
        'studentEmail': 'rawan.sherko@gmail.com',
        'courseName': 'داتابەیس',
        'teacherName': 'د. سارا محمد',
        'status': 'approved',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      },
      {
        'id': 'req_3',
        'studentName': 'ئاراس ئەحمەد',
        'studentEmail': 'aras@zanko.edu',
        'courseName': 'ئەمنیەتی سایبەر',
        'teacherName': 'د. سارا محمد',
        'status': 'pending',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 45)),
      }
    ]);
  }

  @override
  Future<void> loadData() async {}

  @override
  Future<void> addNote(NoteModel note) async {
    _notes.insert(0, note);
    notifyListeners();
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      notifyListeners();
    }
  }

  @override
  Future<void> deleteNote(String noteId) async {
    _notes.removeWhere((n) => n.id == noteId);
    notifyListeners();
  }

  @override
  Future<void> addScheduleItem(ScheduleModel item) async {
    _schedule.add(item);
    notifyListeners();
  }

  @override
  Future<void> deleteScheduleItem(String itemId) async {
    _schedule.removeWhere((item) => item.id == itemId);
    notifyListeners();
  }

  @override
  Future<void> addQuiz(QuizModel quiz) async {
    _quizzes.insert(0, quiz);
    _quizzesTaken++;
    notifyListeners();
  }

  @override
  Future<void> addFlashcard(FlashcardModel card) async {
    _flashcards.add(card);
    _flashcardsFlipped++;
    notifyListeners();
  }

  @override
  Future<void> clearFlashcards() async {
    _flashcards.clear();
    notifyListeners();
  }

  @override
  Future<void> addReminder(ReminderModel reminder) async {
    _reminders.insert(0, reminder);
    notifyListeners();
  }

  @override
  Future<void> toggleReminder(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      _reminders[index] = _reminders[index].copyWith(isCompleted: !_reminders[index].isCompleted);
      notifyListeners();
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  @override
  Future<void> requestEnrollment(String studentName, String studentEmail, String courseName, String teacherName) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _enrollmentRequests.add({
      'id': 'req_${DateTime.now().millisecondsSinceEpoch}',
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseName': courseName,
      'teacherName': teacherName,
      'status': 'pending',
      'createdAt': DateTime.now(),
    });
    notifyListeners();
  }

  @override
  Future<void> approveEnrollment(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _enrollmentRequests.indexWhere((r) => r['id'] == requestId);
    if (index != -1) {
      _enrollmentRequests[index]['status'] = 'approved';
      notifyListeners();
    }
  }

  @override
  Future<void> rejectEnrollment(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _enrollmentRequests.indexWhere((r) => r['id'] == requestId);
    if (index != -1) {
      _enrollmentRequests[index]['status'] = 'rejected';
      notifyListeners();
    }
  }

  @override
  void incrementPomodoros() {
    _completedPomodoros++;
    notifyListeners();
  }

  @override
  void incrementQuizzesTaken() {
    _quizzesTaken++;
    notifyListeners();
  }

  @override
  void incrementFlashcardsFlipped() {
    _flashcardsFlipped++;
    notifyListeners();
  }
}
