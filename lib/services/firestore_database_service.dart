import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/note_model.dart';
import '../models/schedule_model.dart';
import '../models/quiz_model.dart';
import '../models/flashcard_model.dart';
import '../models/reminder_model.dart';
import '../models/lecture_model.dart';
import '../models/announcement_model.dart';
import 'database_service.dart';

class FirestoreDatabaseService extends ChangeNotifier implements DatabaseService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  final List<NoteModel> _notes = [];
  final List<ScheduleModel> _schedule = [];
  final List<QuizModel> _quizzes = [];
  final List<FlashcardModel> _flashcards = [];
  final List<ReminderModel> _reminders = [];
  final List<Map<String, dynamic>> _enrollmentRequests = [];
  final List<LectureModel> _lectures = [];
  final List<AnnouncementModel> _announcements = [];
  final List<Map<String, dynamic>> _departments = [];
  final List<Map<String, dynamic>> _courses = [];

  int _completedPomodoros = 0;
  int _quizzesTaken = 0;
  int _flashcardsFlipped = 0;

  StreamSubscription? _notesSub;
  StreamSubscription? _scheduleSub;
  StreamSubscription? _quizzesSub;
  StreamSubscription? _flashcardsSub;
  StreamSubscription? _remindersSub;
  StreamSubscription? _lecturesSub;
  StreamSubscription? _announcementsSub;
  StreamSubscription? _enrollmentsSub;
  StreamSubscription? _departmentsSub;
  StreamSubscription? _coursesSub;
  StreamSubscription? _authSub;

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
  List<LectureModel> get lectures => _lectures;
  @override
  List<AnnouncementModel> get announcements => _announcements;
  @override
  List<Map<String, dynamic>> get departments => _departments;
  @override
  List<Map<String, dynamic>> get courses => _courses;

  @override
  int get completedPomodoros => _completedPomodoros;
  @override
  int get quizzesTaken => _quizzesTaken;
  @override
  int get flashcardsFlipped => _flashcardsFlipped;

  String? get _userId => _auth.currentUser?.uid;

  FirestoreDatabaseService() {
    _authSub = _auth.authStateChanges().listen((_) {
      loadData();
    });
    loadData();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelAllSubscriptions();
    super.dispose();
  }

  void _cancelAllSubscriptions() {
    _notesSub?.cancel();
    _scheduleSub?.cancel();
    _quizzesSub?.cancel();
    _flashcardsSub?.cancel();
    _remindersSub?.cancel();
    _lecturesSub?.cancel();
    _announcementsSub?.cancel();
    _enrollmentsSub?.cancel();
    _departmentsSub?.cancel();
    _coursesSub?.cancel();
  }

  @override
  Future<void> loadData() async {
    try {
      _listenToNotes();
      _listenToSchedule();
      _listenToQuizzes();
      _listenToFlashcards();
      _listenToReminders();
      _listenToLectures();
      _listenToAnnouncements();
      _listenToEnrollmentRequests();
      _listenToDepartments();
      _listenToCourses();
    } catch (e) {
      if (kDebugMode) print('Firestore loadData note: $e');
    }
  }

  void _listenToNotes() {
    _notesSub?.cancel();
    final uid = _userId;
    if (uid == null) {
      _notes.clear();
      notifyListeners();
      return;
    }

    _notesSub = _firestore
        .collection('notes')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      _notes.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _notes.add(NoteModel(
          id: doc.id,
          title: data['title'] ?? '',
          content: data['content'] ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isAiFormatted: data['isAiFormatted'] ?? false,
          courseName: data['courseName'],
        ));
      }
      _notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }, onError: (_) {});
  }

  void _listenToSchedule() {
    _scheduleSub?.cancel();
    final uid = _userId;
    if (uid == null) {
      _schedule.clear();
      notifyListeners();
      return;
    }

    _scheduleSub = _firestore
        .collection('schedule')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      _schedule.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _schedule.add(ScheduleModel(
          id: doc.id,
          courseName: data['courseName'] ?? '',
          time: data['time'] ?? '',
          location: data['location'] ?? '',
          dayName: data['dayName'] ?? 'شەممە',
          teacherName: data['teacherName'],
        ));
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _listenToQuizzes() {
    _quizzesSub?.cancel();
    _quizzesSub = _firestore.collection('quizzes').snapshots().listen((snapshot) {
      _quizzes.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List<QuestionModel> questions = [];
        if (data['questions'] is List) {
          for (var q in (data['questions'] as List)) {
            if (q is Map) {
              final qMap = Map<String, dynamic>.from(q);
              questions.add(QuestionModel(
                id: qMap['id'] ?? '',
                questionText: qMap['questionText'] ?? qMap['question'] ?? '',
                type: QuestionType.values.firstWhere(
                  (e) => e.name == qMap['type'],
                  orElse: () => QuestionType.multipleChoice,
                ),
                options: qMap['options'] != null ? List<String>.from(qMap['options']) : null,
                correctAnswer: (qMap['correctAnswer'] ?? qMap['correct_answer'] ?? '').toString(),
                explanation: qMap['explanation']?.toString(),
              ));
            }
          }
        }
        _quizzes.add(QuizModel(
          id: doc.id,
          title: data['title'] ?? '',
          courseName: data['courseName'] ?? '',
          durationMinutes: data['durationMinutes'] ?? 10,
          questions: questions,
        ));
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _listenToFlashcards() {
    _flashcardsSub?.cancel();
    final uid = _userId;
    if (uid == null) {
      _flashcards.clear();
      notifyListeners();
      return;
    }

    _flashcardsSub = _firestore
        .collection('flashcards')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      _flashcards.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _flashcards.add(FlashcardModel(
          id: doc.id,
          front: data['front'] ?? '',
          back: data['back'] ?? '',
        ));
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _listenToReminders() {
    _remindersSub?.cancel();
    final uid = _userId;
    if (uid == null) {
      _reminders.clear();
      notifyListeners();
      return;
    }

    _remindersSub = _firestore
        .collection('reminders')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      _reminders.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _reminders.add(ReminderModel(
          id: doc.id,
          title: data['title'] ?? '',
          deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
          courseName: data['courseName'] ?? '',
          isCompleted: data['isCompleted'] ?? false,
        ));
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _listenToLectures() {
    _lecturesSub?.cancel();
    _lecturesSub = _firestore.collection('lectures').snapshots().listen((snapshot) {
      _lectures.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _lectures.add(LectureModel(
          id: doc.id,
          title: data['title'] ?? '',
          courseName: data['courseName'] ?? '',
          type: LectureType.values.firstWhere(
            (e) => e.name == data['type'],
            orElse: () => LectureType.pdf,
          ),
          fileUrl: data['fileUrl'] ?? '',
          description: data['description'] ?? '',
          uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          fileSize: data['fileSize'] ?? '1.5 MB',
        ));
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _listenToAnnouncements() {
    _announcementsSub?.cancel();
    _announcementsSub = _firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _announcements.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _announcements.add(AnnouncementModel(
          id: doc.id,
          title: data['title'] ?? '',
          content: data['content'] ?? '',
          courseName: data['courseName'] ?? '',
          teacherName: data['teacherName'] ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          priority: AnnouncementPriority.values.firstWhere(
            (e) => e.name == data['priority'],
            orElse: () => AnnouncementPriority.normal,
          ),
        ));
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _listenToEnrollmentRequests() {
    _enrollmentsSub?.cancel();
    _enrollmentsSub = _firestore.collection('enrollments').snapshots().listen((snapshot) {
      _enrollmentRequests.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _enrollmentRequests.add({
          'id': doc.id,
          'studentName': data['studentName'] ?? '',
          'studentEmail': data['studentEmail'] ?? '',
          'courseName': data['courseName'] ?? '',
          'teacherName': data['teacherName'] ?? '',
          'status': data['status'] ?? 'pending',
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        });
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _listenToDepartments() {
    _departmentsSub?.cancel();
    _departmentsSub = _firestore.collection('departments').snapshots().listen((snapshot) {
      _departments.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _departments.add({
          'id': doc.id,
          'name': data['name'] ?? '',
          'faculty': data['faculty'] ?? '',
          'head': data['head'] ?? '',
        });
      }
      notifyListeners();
    }, onError: (_) {});
  }

  void _listenToCourses() {
    _coursesSub?.cancel();
    _coursesSub = _firestore.collection('courses').snapshots().listen((snapshot) {
      _courses.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _courses.add({
          'id': doc.id,
          'title': data['title'] ?? '',
          'code': data['code'] ?? '',
          'department': data['department'] ?? '',
          'semester': data['semester'] ?? '',
          'credits': data['credits'] ?? 3,
        });
      }
      notifyListeners();
    }, onError: (_) {});
  }

  // Write operations
  @override
  Future<void> addNote(NoteModel note) async {
    await _firestore.collection('notes').doc(note.id).set({
      'title': note.title,
      'content': note.content,
      'courseName': note.courseName,
      'isAiFormatted': note.isAiFormatted,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': _userId,
    });
  }

  @override
  Future<void> updateNote(NoteModel note) async {
    await _firestore.collection('notes').doc(note.id).update({
      'title': note.title,
      'content': note.content,
      'courseName': note.courseName,
      'isAiFormatted': note.isAiFormatted,
    });
  }

  @override
  Future<void> deleteNote(String noteId) async {
    await _firestore.collection('notes').doc(noteId).delete();
  }

  @override
  Future<void> addScheduleItem(ScheduleModel item) async {
    await _firestore.collection('schedule').doc(item.id).set({
      'courseName': item.courseName,
      'time': item.time,
      'location': item.location,
      'dayName': item.dayName,
      'teacherName': item.teacherName,
      'userId': _userId,
    });
  }

  @override
  Future<void> deleteScheduleItem(String itemId) async {
    await _firestore.collection('schedule').doc(itemId).delete();
  }

  @override
  Future<void> addQuiz(QuizModel quiz) async {
    final questionsData = quiz.questions.map((q) => {
      'id': q.id,
      'questionText': q.questionText,
      'type': q.type.name,
      'options': q.options,
      'correctAnswer': q.correctAnswer,
      'explanation': q.explanation,
    }).toList();

    await _firestore.collection('quizzes').doc(quiz.id).set({
      'title': quiz.title,
      'courseName': quiz.courseName,
      'durationMinutes': quiz.durationMinutes,
      'userId': _userId,
      'createdAt': FieldValue.serverTimestamp(),
      'questions': questionsData,
    });
    _quizzesTaken++;
    notifyListeners();
  }

  @override
  Future<void> addFlashcard(FlashcardModel card) async {
    await _firestore.collection('flashcards').doc(card.id).set({
      'front': card.front,
      'back': card.back,
      'userId': _userId,
    });
    _flashcardsFlipped++;
    notifyListeners();
  }

  @override
  Future<void> clearFlashcards() async {
    final uid = _userId;
    if (uid == null) return;
    final batch = _firestore.batch();
    final snapshot = await _firestore.collection('flashcards').where('userId', isEqualTo: uid).get();
    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  @override
  Future<void> addReminder(ReminderModel reminder) async {
    await _firestore.collection('reminders').doc(reminder.id).set({
      'title': reminder.title,
      'deadline': reminder.deadline,
      'courseName': reminder.courseName,
      'isCompleted': reminder.isCompleted,
      'userId': _userId,
    });
  }

  @override
  Future<void> toggleReminder(String id) async {
    final doc = await _firestore.collection('reminders').doc(id).get();
    if (doc.exists) {
      final current = doc.data()?['isCompleted'] ?? false;
      await _firestore.collection('reminders').doc(id).update({'isCompleted': !current});
    }
  }

  @override
  Future<void> deleteReminder(String id) async {
    await _firestore.collection('reminders').doc(id).delete();
  }

  @override
  Future<void> addLecture(LectureModel lecture) async {
    await _firestore.collection('lectures').doc(lecture.id).set({
      'title': lecture.title,
      'courseName': lecture.courseName,
      'type': lecture.type.name,
      'fileUrl': lecture.fileUrl,
      'description': lecture.description,
      'uploadedAt': FieldValue.serverTimestamp(),
      'fileSize': lecture.fileSize,
      'userId': _userId,
    });
  }

  @override
  Future<void> deleteLecture(String id) async {
    await _firestore.collection('lectures').doc(id).delete();
  }

  @override
  Future<void> addAnnouncement(AnnouncementModel announcement) async {
    await _firestore.collection('announcements').doc(announcement.id).set({
      'title': announcement.title,
      'content': announcement.content,
      'courseName': announcement.courseName,
      'teacherName': announcement.teacherName,
      'priority': announcement.priority.name,
      'createdAt': FieldValue.serverTimestamp(),
      'userId': _userId,
    });
  }

  @override
  Future<void> deleteAnnouncement(String id) async {
    await _firestore.collection('announcements').doc(id).delete();
  }

  @override
  Future<void> requestEnrollment(String studentName, String studentEmail, String courseName, String teacherName) async {
    await _firestore.collection('enrollments').add({
      'studentName': studentName,
      'studentEmail': studentEmail,
      'courseName': courseName,
      'teacherName': teacherName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'userId': _userId,
    });
  }

  @override
  Future<void> approveEnrollment(String requestId) async {
    await _firestore.collection('enrollments').doc(requestId).update({'status': 'approved'});
  }

  @override
  Future<void> rejectEnrollment(String requestId) async {
    await _firestore.collection('enrollments').doc(requestId).update({'status': 'rejected'});
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
