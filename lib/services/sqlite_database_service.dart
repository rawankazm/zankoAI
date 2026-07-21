import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/note_model.dart';
import '../models/schedule_model.dart';
import '../models/quiz_model.dart';
import '../models/flashcard_model.dart';
import '../models/reminder_model.dart';
import 'database_service.dart';

class SqliteDatabaseService extends ChangeNotifier implements DatabaseService {
  Database? _db;

  final List<NoteModel> _notes = [];
  final List<ScheduleModel> _schedule = [];
  final List<QuizModel> _quizzes = [];
  final List<FlashcardModel> _flashcards = [];
  final List<ReminderModel> _reminders = [];
  final List<Map<String, dynamic>> _enrollmentRequests = [];

  int _completedPomodoros = 0;
  int _quizzesTaken = 0;
  int _flashcardsFlipped = 0;

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

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'zanko_ai.db');

    return await openDatabase(
      pathString,
      version: 1,
      onCreate: (db, version) async {
        // Create Notes Table
        await db.execute('''
          CREATE TABLE notes (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            createdAt TEXT,
            isAiFormatted INTEGER,
            courseName TEXT
          )
        ''');

        // Create Schedule Table
        await db.execute('''
          CREATE TABLE schedule (
            id TEXT PRIMARY KEY,
            courseName TEXT,
            time TEXT,
            location TEXT,
            dayName TEXT,
            teacherName TEXT
          )
        ''');

        // Create Quizzes Table
        await db.execute('''
          CREATE TABLE quizzes (
            id TEXT PRIMARY KEY,
            title TEXT,
            courseName TEXT,
            durationMinutes INTEGER
          )
        ''');

        // Create Questions Table
        await db.execute('''
          CREATE TABLE questions (
            id TEXT PRIMARY KEY,
            quizId TEXT,
            questionText TEXT,
            type TEXT,
            options TEXT,
            correctAnswer TEXT,
            FOREIGN KEY (quizId) REFERENCES quizzes (id) ON DELETE CASCADE
          )
        ''');

        // Create Flashcards Table
        await db.execute('''
          CREATE TABLE flashcards (
            id TEXT PRIMARY KEY,
            front TEXT,
            back TEXT
          )
        ''');

        // Create Reminders Table
        await db.execute('''
          CREATE TABLE reminders (
            id TEXT PRIMARY KEY,
            title TEXT,
            deadline TEXT,
            courseName TEXT,
            isCompleted INTEGER
          )
        ''');

        // Create Enrollment Requests Table
        await db.execute('''
          CREATE TABLE enrollment_requests (
            id TEXT PRIMARY KEY,
            studentName TEXT,
            studentEmail TEXT,
            courseName TEXT,
            teacherName TEXT,
            status TEXT,
            createdAt TEXT
          )
        ''');

        // Create Stats Table
        await db.execute('''
          CREATE TABLE stats (
            key TEXT PRIMARY KEY,
            value INTEGER
          )
        ''');

        // Initialize Stats
        await db.insert('stats', {'key': 'pomodoros', 'value': 1});
        await db.insert('stats', {'key': 'quizzes_taken', 'value': 2});
        await db.insert('stats', {'key': 'flashcards_flipped', 'value': 4});

        // Populate Mock Data
        await _populateInitialMockData(db);
      },
    );
  }

  Future<void> _populateInitialMockData(Database db) async {
    // Mock Notes
    await db.insert('notes', {
      'id': 'n1',
      'title': 'تێبینی دەربارەی سیستەمی کارپێکردن',
      'content': 'سیستەمی کارپێکردن (OS) بریتییە لەو نەرمەکاڵایەی کە ڕەقەکاڵاکان و نەرمەکاڵاکانی تر بەڕێوەدەبات.',
      'createdAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'isAiFormatted': 1,
      'courseName': 'سیستەمی کارپێکردن',
    });
    await db.insert('notes', {
      'id': 'n2',
      'title': 'کورتەی وانەی داتابەیس',
      'content': 'داتابەیس (Database) سیستەمێکە بۆ کۆکردنەوە و ڕێکخستنی زانیارییەکان بە شێوازێک کە ئاسان بێت.',
      'createdAt': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      'isAiFormatted': 0,
      'courseName': 'بنکەی زانیاری',
    });

    // Mock Schedule
    final mockSchedules = [
      {
        'id': 's1',
        'courseName': 'سیستەمی کارپێکردن (OS)',
        'time': '08:30 - 10:00',
        'location': 'هۆڵی ٤، بەشی تەکنەلۆجیای زانیاری',
        'dayName': 'شەممە',
        'teacherName': 'د. ڕێبین ئەحمەد',
      },
      {
        'id': 's2',
        'courseName': 'بەرنامەسازی پێشکەوتوو (Dart & Flutter)',
        'time': '10:15 - 11:45',
        'location': 'لابۆراتۆری ٣، بەشی کۆمپیوتەر',
        'dayName': 'شەممە',
        'teacherName': 'م. شادان عومەر',
      },
      {
        'id': 's3',
        'courseName': 'بنکەی زانیاری',
        'time': '08:30 - 10:00',
        'location': 'هۆڵی ٢، بەشی تەکنەلۆجیای زانیاری',
        'dayName': 'یەکشەممە',
        'teacherName': 'م. هێمن مستەفا',
      },
    ];
    for (var item in mockSchedules) {
      await db.insert('schedule', item);
    }

    // Mock Quiz
    await db.insert('quizzes', {
      'id': 'q1',
      'title': 'کوزی بنەماکانی کۆمپیوتەر',
      'courseName': 'بنەماکانی کۆمپیوتەر',
      'durationMinutes': 10,
    });

    final mockQuestions = [
      {
        'id': 'q1_1',
        'quizId': 'q1',
        'questionText': 'سی پی یو (CPU) مێشکی کۆمپیوتەرە و بەرپرسە لە پڕۆسێسکردنی فەرمانەکان.',
        'type': 'trueFalse',
        'options': null,
        'correctAnswer': 'ڕاستە',
      },
      {
        'id': 'q1_2',
        'quizId': 'q1',
        'questionText': 'کام لەمانە وەک یادگەی کاتی (Volatile memory) دادەنرێت؟',
        'type': 'multipleChoice',
        'options': jsonEncode(['RAM', 'ROM', 'HDD', 'SSD']),
        'correctAnswer': 'RAM',
      },
    ];
    for (var q in mockQuestions) {
      await db.insert('questions', q);
    }

    // Mock Flashcards
    await db.insert('flashcards', {
      'id': 'c1',
      'front': 'مۆدێلی OSI چییە؟',
      'back': 'ڕێکخراوێکە بۆ لێکتێگەیشتنی پرۆتۆکۆلەکانی تۆڕ لە ٧ چینی جیاوازدا.',
    });
    await db.insert('flashcards', {
      'id': 'c2',
      'front': 'کارکردنی CPU چییە؟',
      'back': 'ئامێری سەرەکی جێبەجێکردنی فەرمانەکان و پرۆسێسەکردنی زانیارییەکان لە کۆمپیوتەردا.',
    });

    // Mock Reminders
    await db.insert('reminders', {
      'id': 'rem_1',
      'title': 'ڕادەستکردنی ڕاپۆرتی پڕۆسێسەکانی OS',
      'deadline': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
      'courseName': 'سیستەمی کارپێکردن',
      'isCompleted': 0,
    });

    // Mock Enrollment Requests
    await db.insert('enrollment_requests', {
      'id': 'req_1',
      'studentName': 'ڕاوەن شێرکۆ',
      'studentEmail': 'rawan.sherko@gmail.com',
      'courseName': 'سیستەمی کارپێکردن',
      'teacherName': 'د. سارا محمد',
      'status': 'pending',
      'createdAt': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    });
    await db.insert('enrollment_requests', {
      'id': 'req_2',
      'studentName': 'ڕاوەن شێرکۆ',
      'studentEmail': 'rawan.sherko@gmail.com',
      'courseName': 'داتابەیس',
      'teacherName': 'د. سارا محمد',
      'status': 'approved',
      'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    });
  }

  @override
  Future<void> loadData() async {
    final db = await database;

    // Load Notes
    final notesMaps = await db.query('notes', orderBy: 'createdAt DESC');
    _notes.clear();
    for (var m in notesMaps) {
      _notes.add(NoteModel(
        id: m['id'] as String,
        title: m['title'] as String,
        content: m['content'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
        isAiFormatted: m['isAiFormatted'] == 1,
        courseName: m['courseName'] as String?,
      ));
    }

    // Load Schedule
    final scheduleMaps = await db.query('schedule');
    _schedule.clear();
    for (var m in scheduleMaps) {
      _schedule.add(ScheduleModel(
        id: m['id'] as String,
        courseName: m['courseName'] as String,
        time: m['time'] as String,
        location: m['location'] as String,
        dayName: m['dayName'] as String,
        teacherName: (m['teacherName'] as String?) ?? '',
      ));
    }

    // Load Quizzes
    final quizMaps = await db.query('quizzes');
    _quizzes.clear();
    for (var qMap in quizMaps) {
      final qId = qMap['id'] as String;
      final questionMaps = await db.query('questions', where: 'quizId = ?', whereArgs: [qId]);
      final List<QuestionModel> questions = [];
      for (var q in questionMaps) {
        final optionsStr = q['options'] as String?;
        questions.add(QuestionModel(
          id: q['id'] as String,
          questionText: q['questionText'] as String,
          type: q['type'] == 'trueFalse'
              ? QuestionType.trueFalse
              : q['type'] == 'fillInBlank'
                  ? QuestionType.fillInBlank
                  : QuestionType.multipleChoice,
          options: optionsStr != null ? List<String>.from(jsonDecode(optionsStr)) : null,
          correctAnswer: q['correctAnswer'] as String,
        ));
      }
      _quizzes.add(QuizModel(
        id: qId,
        title: qMap['title'] as String,
        courseName: qMap['courseName'] as String,
        durationMinutes: qMap['durationMinutes'] as int? ?? 10,
        questions: questions,
      ));
    }

    // Load Flashcards
    final flashcardsMaps = await db.query('flashcards');
    _flashcards.clear();
    for (var m in flashcardsMaps) {
      _flashcards.add(FlashcardModel(
        id: m['id'] as String,
        front: m['front'] as String,
        back: m['back'] as String,
      ));
    }

    // Load Reminders
    final remindersMaps = await db.query('reminders');
    _reminders.clear();
    for (var m in remindersMaps) {
      _reminders.add(ReminderModel(
        id: m['id'] as String,
        title: m['title'] as String,
        deadline: DateTime.parse(m['deadline'] as String),
        courseName: m['courseName'] as String,
        isCompleted: m['isCompleted'] == 1,
      ));
    }

    // Load Enrollment Requests
    final enrollmentMaps = await db.query('enrollment_requests', orderBy: 'createdAt DESC');
    _enrollmentRequests.clear();
    for (var m in enrollmentMaps) {
      _enrollmentRequests.add({
        'id': m['id'],
        'studentName': m['studentName'],
        'studentEmail': m['studentEmail'],
        'courseName': m['courseName'],
        'teacherName': m['teacherName'],
        'status': m['status'],
        'createdAt': DateTime.parse(m['createdAt'] as String),
      });
    }

    // Load Stats
    final statsList = await db.query('stats');
    for (var row in statsList) {
      if (row['key'] == 'pomodoros') _completedPomodoros = row['value'] as int;
      if (row['key'] == 'quizzes_taken') _quizzesTaken = row['value'] as int;
      if (row['key'] == 'flashcards_flipped') _flashcardsFlipped = row['value'] as int;
    }

    notifyListeners();
  }

  @override
  Future<void> addNote(NoteModel note) async {
    final db = await database;
    await db.insert('notes', {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'createdAt': note.createdAt.toIso8601String(),
      'isAiFormatted': note.isAiFormatted ? 1 : 0,
      'courseName': note.courseName,
    });
    await loadData();
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    final db = await database;
    await db.update(
      'notes',
      {
        'title': note.title,
        'content': note.content,
        'isAiFormatted': note.isAiFormatted ? 1 : 0,
        'courseName': note.courseName,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
    await loadData();
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
    await loadData();
  }

  @override
  Future<void> addScheduleItem(ScheduleModel item) async {
    final db = await database;
    await db.insert('schedule', {
      'id': item.id,
      'courseName': item.courseName,
      'time': item.time,
      'location': item.location,
      'dayName': item.dayName,
      'teacherName': item.teacherName,
    });
    await loadData();
  }

  @override
  Future<void> deleteScheduleItem(String itemId) async {
    final db = await database;
    await db.delete('schedule', where: 'id = ?', whereArgs: [itemId]);
    await loadData();
  }

  @override
  Future<void> addQuiz(QuizModel quiz) async {
    final db = await database;
    await db.insert('quizzes', {
      'id': quiz.id,
      'title': quiz.title,
      'courseName': quiz.courseName,
      'durationMinutes': quiz.durationMinutes,
    });

    for (var q in quiz.questions) {
      await db.insert('questions', {
        'id': q.id,
        'quizId': quiz.id,
        'questionText': q.questionText,
        'type': q.type.toString().split('.').last,
        'options': q.options != null ? jsonEncode(q.options) : null,
        'correctAnswer': q.correctAnswer,
      });
    }
    _quizzesTaken++;
    await db.update('stats', {'value': _quizzesTaken}, where: 'key = ?', whereArgs: ['quizzes_taken']);
    await loadData();
  }

  @override
  Future<void> addFlashcard(FlashcardModel card) async {
    final db = await database;
    await db.insert('flashcards', {
      'id': card.id,
      'front': card.front,
      'back': card.back,
    });
    _flashcardsFlipped++;
    await db.update('stats', {'value': _flashcardsFlipped}, where: 'key = ?', whereArgs: ['flashcards_flipped']);
    await loadData();
  }

  @override
  Future<void> clearFlashcards() async {
    final db = await database;
    await db.delete('flashcards');
    await loadData();
  }

  @override
  Future<void> addReminder(ReminderModel reminder) async {
    final db = await database;
    await db.insert('reminders', {
      'id': reminder.id,
      'title': reminder.title,
      'deadline': reminder.deadline.toIso8601String(),
      'courseName': reminder.courseName,
      'isCompleted': reminder.isCompleted ? 1 : 0,
    });
    await loadData();
  }

  @override
  Future<void> toggleReminder(String id) async {
    final db = await database;
    final maps = await db.query('reminders', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final currentCompleted = maps.first['isCompleted'] as int;
      await db.update('reminders', {'isCompleted': currentCompleted == 1 ? 0 : 1}, where: 'id = ?', whereArgs: [id]);
    }
    await loadData();
  }

  @override
  Future<void> deleteReminder(String id) async {
    final db = await database;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
    await loadData();
  }

  @override
  Future<void> requestEnrollment(String studentName, String studentEmail, String courseName, String teacherName) async {
    final db = await database;
    await db.insert('enrollment_requests', {
      'id': 'req_${DateTime.now().millisecondsSinceEpoch}',
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseName': courseName,
      'teacherName': teacherName,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await loadData();
  }

  @override
  Future<void> approveEnrollment(String requestId) async {
    final db = await database;
    await db.update('enrollment_requests', {'status': 'approved'}, where: 'id = ?', whereArgs: [requestId]);
    await loadData();
  }

  @override
  Future<void> rejectEnrollment(String requestId) async {
    final db = await database;
    await db.update('enrollment_requests', {'status': 'rejected'}, where: 'id = ?', whereArgs: [requestId]);
    await loadData();
  }

  @override
  void incrementPomodoros() async {
    final db = await database;
    _completedPomodoros++;
    await db.update('stats', {'value': _completedPomodoros}, where: 'key = ?', whereArgs: ['pomodoros']);
    await loadData();
  }

  @override
  void incrementQuizzesTaken() async {
    final db = await database;
    _quizzesTaken++;
    await db.update('stats', {'value': _quizzesTaken}, where: 'key = ?', whereArgs: ['quizzes_taken']);
    await loadData();
  }

  @override
  void incrementFlashcardsFlipped() async {
    final db = await database;
    _flashcardsFlipped++;
    await db.update('stats', {'value': _flashcardsFlipped}, where: 'key = ?', whereArgs: ['flashcards_flipped']);
    await loadData();
  }
}
