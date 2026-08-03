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
  List<LectureModel> get lectures => _lectures;
  @override
  List<AnnouncementModel> get announcements => _announcements;

  @override
  int get completedPomodoros => _completedPomodoros;
  @override
  int get quizzesTaken => _quizzesTaken;
  @override
  int get flashcardsFlipped => _flashcardsFlipped;

  String? get _userId => _auth.currentUser?.uid;

  FirestoreDatabaseService() {
    loadData();
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
    } catch (e) {
      if (kDebugMode) print('Firestore loadData note: $e');
    }
  }

  void _listenToNotes() {
    _firestore
        .collection('notes')
        .orderBy('createdAt', descending: true)
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
      notifyListeners();
    });
  }

  void _listenToSchedule() {
    _firestore.collection('schedule').snapshots().listen((snapshot) {
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
    });
  }

  void _listenToQuizzes() {
    _firestore.collection('quizzes').snapshots().listen((snapshot) {
      _quizzes.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _quizzes.add(QuizModel(
          id: doc.id,
          title: data['title'] ?? '',
          courseName: data['courseName'] ?? '',
          durationMinutes: data['durationMinutes'] ?? 10,
          questions: [],
        ));
      }
      notifyListeners();
    });
  }

  void _listenToFlashcards() {
    _firestore.collection('flashcards').snapshots().listen((snapshot) {
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
    });
  }

  void _listenToReminders() {
    _firestore.collection('reminders').snapshots().listen((snapshot) {
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
    });
  }

  void _listenToLectures() {
    _firestore.collection('lectures').snapshots().listen((snapshot) {
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
    });
  }

  void _listenToAnnouncements() {
    _firestore
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
    });
  }

  void _listenToEnrollmentRequests() {
    _firestore.collection('enrollments').snapshots().listen((snapshot) {
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
    });
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
    await _firestore.collection('quizzes').doc(quiz.id).set({
      'title': quiz.title,
      'courseName': quiz.courseName,
      'durationMinutes': quiz.durationMinutes,
      'userId': _userId,
      'createdAt': FieldValue.serverTimestamp(),
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
    final batch = _firestore.batch();
    final snapshot = await _firestore.collection('flashcards').get();
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
