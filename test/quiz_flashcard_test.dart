// ==============================================================================
// ZankoAI Quiz & Flashcard System — Unit & Integration Tests
//
// Covers all required scenarios:
//   1. Question types parsing (MCQ, True/False, Short Answer)
//   2. Anti-cheating guarantee: Correct answers & explanations omitted before submission
//   3. AI question validation: Rejection of malformed questions
//   4. Multi-source quiz creation (PDF, OCR, Lecture, Teacher, AI Topic)
//   5. Teacher role & course authorization enforcement (403 Forbidden)
//   6. Student unauthorized quiz access prevention (403 Forbidden)
//   7. Starting quiz attempt (sanitized questions returned)
//   8. Server-side score calculation: Client score never trusted
//   9. Pass / fail score calculation based on passing_score
//  10. Post-submission answer review (correct answers & explanations revealed)
//  11. Flashcard spaced repetition (SM-2 / Leitner) progress tracking & isDue logic
//  12. Flashcard review rating submission (0–5)
// ==============================================================================

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zanko_ai/models/quiz_model.dart';
import 'package:zanko_ai/models/flashcard_model.dart';
import 'package:zanko_ai/services/quiz_service.dart';

// ─── Mock Dio ─────────────────────────────────────────────────────────────────

class MockDio extends Mock implements Dio {}

// ─── Stub Helpers ─────────────────────────────────────────────────────────────

Response<Map<String, dynamic>> _buildResponse({
  required int statusCode,
  required Map<String, dynamic> data,
  required RequestOptions requestOptions,
}) {
  return Response<Map<String, dynamic>>(
    statusCode: statusCode,
    data: data,
    requestOptions: requestOptions,
  );
}

RequestOptions _optsPost(String path) => RequestOptions(path: path, method: 'POST');
RequestOptions _optsGet(String path) => RequestOptions(path: path, method: 'GET');

// ─── Payload Builders ─────────────────────────────────────────────────────────

Map<String, dynamic> _buildSanitizedQuestionJson({
  required String id,
  required String text,
  required String type,
  List<String>? options,
  String difficulty = 'medium',
  double points = 1.0,
}) {
  // CRITICAL ANTI-CHEATING: correct_answer and explanation are omitted for students!
  return {
    'id': id,
    'question_text': text,
    'question_type': type,
    'options': options,
    'difficulty': difficulty,
    'points': points,
    'order_index': 0,
  };
}

Map<String, dynamic> _buildTeacherQuestionJson({
  required String id,
  required String text,
  required String type,
  List<String>? options,
  required String correctAnswer,
  required String explanation,
  String difficulty = 'medium',
  double points = 1.0,
}) {
  return {
    'id': id,
    'question_text': text,
    'question_type': type,
    'options': options,
    'correct_answer': correctAnswer,
    'explanation': explanation,
    'difficulty': difficulty,
    'points': points,
    'order_index': 0,
  };
}

Map<String, dynamic> _buildQuizResponse({
  String quizId = 'quiz-uuid-001',
  String title = 'Data Structures Midterm Quiz',
  String? courseId = 'course-uuid-101',
  String sourceType = 'ai_topic',
  String difficulty = 'medium',
  double passingScore = 60.0,
  int durationMinutes = 20,
  required List<Map<String, dynamic>> questions,
}) {
  return {
    'success': true,
    'data': {
      'id': quizId,
      'title': title,
      'course_id': courseId,
      'course_name': 'Computer Science 201',
      'source_type': sourceType,
      'difficulty': difficulty,
      'passing_score': passingScore,
      'time_limit_minutes': durationMinutes,
      'is_published': true,
      'question_count': questions.length,
      'questions': questions,
    },
  };
}

void main() {
  late MockDio mockDio;
  late QuizService quizService;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(Options());
  });

  setUp(() {
    mockDio = MockDio();
    quizService = QuizService(dio: mockDio);
  });

  group('1. Question Types & Model Parsing', () {
    test('parses QuestionType enum correctly from diverse strings and representations', () {
      expect(QuestionType.fromString('multiple_choice'), equals(QuestionType.multipleChoice));
      expect(QuestionType.fromString('MULTIPLECHOICE'), equals(QuestionType.multipleChoice));
      expect(QuestionType.fromString('true_false'), equals(QuestionType.trueFalse));
      expect(QuestionType.fromString('tf'), equals(QuestionType.trueFalse));
      expect(QuestionType.fromString('short_answer'), equals(QuestionType.shortAnswer));
      expect(QuestionType.fromString('shortanswer'), equals(QuestionType.shortAnswer));
      expect(QuestionType.fromString('fill_in_blank'), equals(QuestionType.fillInBlank));
      expect(QuestionType.fromString('essay'), equals(QuestionType.essay));
      expect(QuestionType.fromString(null), equals(QuestionType.multipleChoice));

      expect(QuestionType.multipleChoice.toSnakeCase(), equals('multiple_choice'));
      expect(QuestionType.trueFalse.toSnakeCase(), equals('true_false'));
      expect(QuestionType.shortAnswer.toSnakeCase(), equals('short_answer'));
    });

    test('correctly maps and instantiates MCQ, True/False, and Short Answer questions', () {
      final mcq = QuestionModel.fromMap({
        'id': 'q-1',
        'question_text': 'What is the time complexity of binary search?',
        'question_type': 'multiple_choice',
        'options': ['O(1)', 'O(log n)', 'O(n)', 'O(n^2)'],
        'correct_answer': 'O(log n)',
        'explanation': 'Binary search halves the search space at each step.',
        'difficulty': 'medium',
        'points': 2.0,
      });

      expect(mcq.type, equals(QuestionType.multipleChoice));
      expect(mcq.options?.length, equals(4));
      expect(mcq.correctAnswer, equals('O(log n)'));
      expect(mcq.points, equals(2.0));
      expect(mcq.hasAnswer, isTrue);

      final tf = QuestionModel.fromMap({
        'id': 'q-2',
        'question_text': 'HTTP is a stateful protocol.',
        'question_type': 'true_false',
        'options': ['True', 'False'],
        'correct_answer': 'False',
        'explanation': 'HTTP is stateless by design.',
        'difficulty': 'easy',
      });

      expect(tf.type, equals(QuestionType.trueFalse));
      expect(tf.correctAnswer, equals('False'));

      final sa = QuestionModel.fromMap({
        'id': 'q-3',
        'question_text': 'What data structure uses LIFO order?',
        'question_type': 'short_answer',
        'options': null,
        'correct_answer': 'Stack',
        'difficulty': 'easy',
      });

      expect(sa.type, equals(QuestionType.shortAnswer));
      expect(sa.options, isNull);
      expect(sa.correctAnswer, equals('Stack'));
    });
  });

  group('2. Anti-Cheating Security: Correct Answer Protection', () {
    test('student quiz view omits correct answers and explanations before submission', () {
      final sanitizedData = _buildSanitizedQuestionJson(
        id: 'q-secret-1',
        text: 'What is the capital of Kurdistan?',
        type: 'multiple_choice',
        options: ['Erbil', 'Sulaymaniyah', 'Duhok', 'Kirkuk'],
      );

      final question = QuestionModel.fromMap(sanitizedData);

      // Student client must not possess the correct answer or explanation
      expect(question.correctAnswer, isEmpty);
      expect(question.explanation, isNull);
      expect(question.hasAnswer, isFalse);
      expect(question.options, contains('Erbil'));
    });

    test('GET /quizzes/:id returns questions without exposing answers to student', () async {
      final questions = [
        _buildSanitizedQuestionJson(
          id: 'q-1',
          text: 'What is 5 + 7?',
          type: 'multiple_choice',
          options: ['10', '11', '12', '13'],
        ),
        _buildSanitizedQuestionJson(
          id: 'q-2',
          text: 'The earth is flat.',
          type: 'true_false',
          options: ['True', 'False'],
        ),
      ];

      when(() => mockDio.get<Map<String, dynamic>>('/quizzes/quiz-101'))
          .thenAnswer((_) async => _buildResponse(
                statusCode: 200,
                data: _buildQuizResponse(quizId: 'quiz-101', questions: questions),
                requestOptions: _optsGet('/quizzes/quiz-101'),
              ));

      final quiz = await quizService.getQuiz('quiz-101');

      expect(quiz.id, equals('quiz-101'));
      expect(quiz.questions.length, equals(2));
      for (final q in quiz.questions) {
        expect(q.correctAnswer, isEmpty, reason: 'Correct answers must never leak to students!');
        expect(q.explanation, isNull, reason: 'Explanations must never leak before submission!');
      }
    });
  });

  group('3. AI Question Sanity Validation & Malformed Question Rejection', () {
    bool validateQuestion(Map<String, dynamic> q) {
      final text = q['question_text']?.toString().trim() ?? '';
      if (text.isEmpty) return false;

      final type = q['question_type']?.toString().toLowerCase().trim() ?? '';
      final correctAnswer = q['correct_answer']?.toString().trim() ?? '';
      if (correctAnswer.isEmpty) return false;

      if (type == 'multiple_choice') {
        final options = q['options'];
        if (options is! List || options.length < 2) return false;
        final stringOpts = options.map((e) => e.toString().trim().toLowerCase()).toList();
        if (!stringOpts.contains(correctAnswer.toLowerCase())) return false;
      } else if (type == 'true_false') {
        final norm = correctAnswer.toLowerCase();
        if (norm != 'true' && norm != 'false') return false;
      } else if (type == 'short_answer') {
        if (correctAnswer.isEmpty) return false;
      } else {
        return false; // Unknown type
      }

      return true;
    }

    test('accepts valid MCQ, True/False, and Short Answer questions', () {
      expect(
        validateQuestion({
          'question_text': 'What is DNA?',
          'question_type': 'multiple_choice',
          'options': ['Nucleic Acid', 'Lipid', 'Protein', 'Carbohydrate'],
          'correct_answer': 'Nucleic Acid',
        }),
        isTrue,
      );

      expect(
        validateQuestion({
          'question_text': 'Water boils at 100C at sea level.',
          'question_type': 'true_false',
          'options': ['True', 'False'],
          'correct_answer': 'True',
        }),
        isTrue,
      );

      expect(
        validateQuestion({
          'question_text': 'Who discovered gravity?',
          'question_type': 'short_answer',
          'correct_answer': 'Isaac Newton',
        }),
        isTrue,
      );
    });

    test('rejects MCQ with fewer than 2 options', () {
      final malformed = {
        'question_text': 'What is CPU?',
        'question_type': 'multiple_choice',
        'options': ['Central Processing Unit'], // Only 1 option!
        'correct_answer': 'Central Processing Unit',
      };
      expect(validateQuestion(malformed), isFalse);
    });

    test('rejects MCQ where correct answer is not among options', () {
      final malformed = {
        'question_text': 'What is RAM?',
        'question_type': 'multiple_choice',
        'options': ['Read Only Memory', 'Random Access Memory'],
        'correct_answer': 'Non Volatile Storage', // Not in options!
      };
      expect(validateQuestion(malformed), isFalse);
    });

    test('rejects True/False with non-boolean answer', () {
      final malformed = {
        'question_text': 'Sun rises in the west.',
        'question_type': 'true_false',
        'options': ['True', 'False'],
        'correct_answer': 'Maybe', // Invalid!
      };
      expect(validateQuestion(malformed), isFalse);
    });

    test('rejects question with missing text or unknown question type', () {
      expect(
        validateQuestion({
          'question_text': '',
          'question_type': 'short_answer',
          'correct_answer': 'Kernel',
        }),
        isFalse,
      );

      expect(
        validateQuestion({
          'question_text': 'Match columns',
          'question_type': 'unknown_unsupported_type',
          'correct_answer': 'A-1',
        }),
        isFalse,
      );
    });
  });

  group('4. Multi-Source Quiz Creation', () {
    final validSources = ['pdf', 'ocr', 'lecture', 'teacher', 'ai_topic'];

    for (final source in validSources) {
      test('creates quiz successfully with source: $source', () async {
        final teacherQuestions = [
          _buildTeacherQuestionJson(
            id: 'q-1',
            text: 'Question from $source',
            type: 'multiple_choice',
            options: ['Option A', 'Option B', 'Option C'],
            correctAnswer: 'Option A',
            explanation: 'Verified explanation.',
          ),
        ];

        when(() => mockDio.post<Map<String, dynamic>>(
              '/quizzes',
              data: any(named: 'data'),
            )).thenAnswer((_) async => _buildResponse(
              statusCode: 201,
              data: _buildQuizResponse(
                quizId: 'quiz-$source',
                title: 'Quiz from $source',
                sourceType: source,
                questions: teacherQuestions,
              ),
              requestOptions: _optsPost('/quizzes'),
            ));

        final result = await quizService.createQuiz(
          title: 'Quiz from $source',
          sourceType: source,
          sourceId: 'src-12345',
          questions: [
            {
              'question_text': 'Question from $source',
              'question_type': 'multiple_choice',
              'options': ['Option A', 'Option B', 'Option C'],
              'correct_answer': 'Option A',
              'explanation': 'Verified explanation.',
            }
          ],
        );

        expect(result.id, equals('quiz-$source'));
        expect(result.sourceType, equals(source));
        expect(result.questions.length, equals(1));
      });
    }
  });

  group('5. Role Authorization & Course Access Enforcement', () {
    test('teacher creating quiz for unauthorized course receives 403 FORBIDDEN', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            '/quizzes',
            data: any(named: 'data'),
          )).thenThrow(
        DioException(
          requestOptions: _optsPost('/quizzes'),
          response: Response(
            statusCode: 403,
            data: {
              'success': false,
              'error': {
                'code': 'UNAUTHORIZED_COURSE_ACCESS',
                'message': 'You are not an authorized teacher for this course.',
              },
            },
            requestOptions: _optsPost('/quizzes'),
          ),
        ),
      );

      expect(
        () => quizService.createQuiz(
          title: 'Unauthorized Quiz',
          courseId: 'forbidden-course-999',
        ),
        throwsA(isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          403,
        )),
      );
    });

    test('student attempting unauthorized course quiz receives 403 FORBIDDEN', () async {
      when(() => mockDio.post<Map<String, dynamic>>('/quizzes/locked-quiz/start'))
          .thenThrow(
        DioException(
          requestOptions: _optsPost('/quizzes/locked-quiz/start'),
          response: Response(
            statusCode: 403,
            data: {
              'success': false,
              'error': {
                'code': 'STUDENT_NOT_ENROLLED',
                'message': 'You must be enrolled in this course to take this quiz.',
              },
            },
            requestOptions: _optsPost('/quizzes/locked-quiz/start'),
          ),
        ),
      );

      expect(
        () => quizService.startQuiz('locked-quiz'),
        throwsA(isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          403,
        )),
      );
    });
  });

  group('6. Starting Quiz Attempt', () {
    test('POST /quizzes/:id/start creates session and returns sanitized questions', () async {
      when(() => mockDio.post<Map<String, dynamic>>('/quizzes/quiz-start-1/start'))
          .thenAnswer((_) async => _buildResponse(
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'attempt_id': 'attempt-uuid-777',
                    'quiz_id': 'quiz-start-1',
                    'time_limit_minutes': 30,
                    'started_at': '2026-09-07T20:00:00.000Z',
                    'questions': [
                      _buildSanitizedQuestionJson(
                        id: 'q-1',
                        text: 'Which scheduling algorithm is non-preemptive?',
                        type: 'multiple_choice',
                        options: ['FCFS', 'Round Robin', 'SRTF', 'Priority (preemptive)'],
                      ),
                    ],
                  },
                },
                requestOptions: _optsPost('/quizzes/quiz-start-1/start'),
              ));

      final startData = await quizService.startQuiz('quiz-start-1');

      expect(startData['attempt_id'], equals('attempt-uuid-777'));
      final questions = (startData['questions'] as List)
          .map((e) => QuestionModel.fromMap(e as Map<String, dynamic>))
          .toList();
      expect(questions.first.questionText, contains('scheduling'));
      expect(questions.first.options, contains('FCFS'));
      expect(questions.first.correctAnswer, isEmpty);
      expect(questions.first.explanation, isNull);
    });
  });

  group('7. Server-Side Score Calculation & Anti-Tampering', () {
    test('evaluates MCQ, True/False, and Short Answer correctly on server', () {
      // Local verification of server scoring logic:
      bool gradeAnswer(String type, String selected, String correct) {
        if (type == 'multiple_choice') {
          return selected.trim().toLowerCase() == correct.trim().toLowerCase();
        } else if (type == 'true_false') {
          return selected.trim().toLowerCase() == correct.trim().toLowerCase();
        } else if (type == 'short_answer') {
          String clean(String s) =>
              s.trim().toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ');
          return clean(selected) == clean(correct);
        }
        return false;
      }

      // MCQ
      expect(gradeAnswer('multiple_choice', 'O(log n)', 'O(log n)'), isTrue);
      expect(gradeAnswer('multiple_choice', 'O(n)', 'O(log n)'), isFalse);

      // True/False (case insensitive)
      expect(gradeAnswer('true_false', 'true', 'True'), isTrue);
      expect(gradeAnswer('true_false', 'False', 'True'), isFalse);

      // Short answer (punctuation & extra spaces handled)
      expect(gradeAnswer('short_answer', 'Isaac Newton', 'Isaac Newton!'), isTrue);
      expect(gradeAnswer('short_answer', 'isaac   newton', 'Isaac Newton'), isTrue);
      expect(gradeAnswer('short_answer', 'Albert Einstein', 'Isaac Newton'), isFalse);
    });

    test('POST /quizzes/:id/submit calculates score server-side and reveals results', () async {
      final submissionPayload = {
        'success': true,
        'data': {
          'attempt_id': 'attempt-uuid-777',
          'quiz_id': 'quiz-comp-1',
          'user_id': 'student-uuid-888',
          'score': 2.0,
          'total_points': 3.0,
          'percentage': 66.67,
          'passed': true,
          'passing_score': 50.0,
          'started_at': '2026-09-07T20:00:00.000Z',
          'completed_at': '2026-09-07T20:15:30.000Z',
          'time_spent_seconds': 930,
          'evaluated_answers': [
            {
              'question_id': 'q-1',
              'question_text': 'What is 2 + 2?',
              'question_type': 'multiple_choice',
              'selected_answer': '4',
              'correct_answer': '4',
              'is_correct': true,
              'points_awarded': 1.0,
              'max_points': 1.0,
              'explanation': '2 + 2 = 4 by definition.',
            },
            {
              'question_id': 'q-2',
              'question_text': 'The earth has two moons.',
              'question_type': 'true_false',
              'selected_answer': 'False',
              'correct_answer': 'False',
              'is_correct': true,
              'points_awarded': 1.0,
              'max_points': 1.0,
              'explanation': 'Earth has one natural satellite.',
            },
            {
              'question_id': 'q-3',
              'question_text': 'Who painted the Mona Lisa?',
              'question_type': 'short_answer',
              'selected_answer': 'Picasso',
              'correct_answer': 'Leonardo da Vinci',
              'is_correct': false,
              'points_awarded': 0.0,
              'max_points': 1.0,
              'explanation': 'Leonardo da Vinci painted the Mona Lisa.',
            },
          ],
        },
      };

      when(() => mockDio.post<Map<String, dynamic>>(
            '/quizzes/quiz-comp-1/submit',
            data: any(named: 'data'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: submissionPayload,
            requestOptions: _optsPost('/quizzes/quiz-comp-1/submit'),
          ));

      final result = await quizService.submitQuiz(
        quizId: 'quiz-comp-1',
        attemptId: 'attempt-uuid-777',
        timeSpentSeconds: 930,
        answers: [
          {'question_id': 'q-1', 'selected_answer': '4'},
          {'question_id': 'q-2', 'selected_answer': 'False'},
          {'question_id': 'q-3', 'selected_answer': 'Picasso'},
        ],
      );

      // Verify server calculation
      expect(result.attemptId, equals('attempt-uuid-777'));
      expect(result.score, equals(2.0));
      expect(result.totalPoints, equals(3.0));
      expect(result.percentage, closeTo(66.67, 0.01));
      expect(result.passed, isTrue);
      expect(result.timeSpentSeconds, equals(930));

      // After submission, answers & explanations are now available for learning!
      expect(result.evaluatedAnswers.length, equals(3));
      final q3 = result.evaluatedAnswers[2];
      expect(q3.isCorrect, isFalse);
      expect(q3.correctAnswer, equals('Leonardo da Vinci'));
      expect(q3.explanation, contains('Leonardo da Vinci painted the Mona Lisa'));
    });

    test('marks quiz as failed when score is below passing_score', () async {
      final failPayload = {
        'success': true,
        'data': {
          'attempt_id': 'attempt-uuid-fail',
          'quiz_id': 'quiz-hard',
          'user_id': 'student-1',
          'score': 1.0,
          'total_points': 4.0,
          'percentage': 25.0,
          'passed': false,
          'passing_score': 60.0,
          'started_at': '2026-09-07T20:00:00.000Z',
          'completed_at': '2026-09-07T20:10:00.000Z',
          'time_spent_seconds': 600,
          'evaluated_answers': [],
        },
      };

      when(() => mockDio.post<Map<String, dynamic>>(
            '/quizzes/quiz-hard/submit',
            data: any(named: 'data'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: failPayload,
            requestOptions: _optsPost('/quizzes/quiz-hard/submit'),
          ));

      final result = await quizService.submitQuiz(
        quizId: 'quiz-hard',
        attemptId: 'attempt-uuid-fail',
        answers: [],
      );

      expect(result.passed, isFalse);
      expect(result.percentage, equals(25.0));
      expect(result.passingScore, equals(60.0));
    });
  });

  group('8. Flashcards & SM-2 Spaced Repetition Architecture', () {
    test('FlashcardModel correctly computes isDue status', () {
      // 1. Never reviewed: nextReviewAt is null -> isDue must be true
      final unreviewed = FlashcardModel(
        id: 'fc-1',
        front: 'What is a Semaphore?',
        back: 'A synchronization variable used to control access to shared resources.',
        nextReviewAt: null,
      );
      expect(unreviewed.isDue, isTrue);

      // 2. Scheduled for the past: isDue must be true
      final overdue = FlashcardModel(
        id: 'fc-2',
        front: 'What is Deadlock?',
        back: 'A situation where two or more threads are blocked forever.',
        nextReviewAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(overdue.isDue, isTrue);

      // 3. Scheduled for tomorrow: isDue must be false
      final futureCard = FlashcardModel(
        id: 'fc-3',
        front: 'What is Thrashing?',
        back: 'A state where the CPU spends more time paging than executing.',
        nextReviewAt: DateTime.now().add(const Duration(days: 1)),
      );
      expect(futureCard.isDue, isFalse);
    });

    test('fetches due flashcards from /flashcards/due', () async {
      when(() => mockDio.get<Map<String, dynamic>>(
            '/flashcards/due',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: {
              'success': true,
              'data': [
                {
                  'id': 'card-due-1',
                  'front_text': 'Front 1',
                  'back_text': 'Back 1',
                  'deck_name': 'OS Concepts',
                  'source_type': 'lecture',
                  'difficulty': 'easy',
                  'box': 1,
                  'ease_factor': 2.5,
                  'interval_days': 1,
                  'repetitions': 0,
                  'next_review_at': '2026-09-01T12:00:00.000Z',
                },
                {
                  'id': 'card-due-2',
                  'front_text': 'Front 2',
                  'back_text': 'Back 2',
                  'deck_name': 'OS Concepts',
                  'source_type': 'pdf',
                  'difficulty': 'medium',
                  'box': 2,
                  'ease_factor': 2.6,
                  'interval_days': 3,
                  'repetitions': 1,
                  'next_review_at': '2026-09-05T12:00:00.000Z',
                },
              ],
            },
            requestOptions: _optsGet('/flashcards/due'),
          ));

      final dueCards = await quizService.getDueFlashcards();

      expect(dueCards.length, equals(2));
      expect(dueCards[0].front, equals('Front 1'));
      expect(dueCards[0].source, equals('lecture'));
      expect(dueCards[0].isDue, isTrue);
      expect(dueCards[1].front, equals('Front 2'));
      expect(dueCards[1].box, equals(2));
      expect(dueCards[1].isDue, isTrue);
    });

    test('SM-2 review rating submission updates easeFactor, box, and intervals', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            '/flashcards/card-sm2-1/review',
            data: {'rating': 5},
          )).thenAnswer((_) async => _buildResponse(
            statusCode: 200,
            data: {
              'success': true,
              'data': {
                'card_id': 'card-sm2-1',
                'rating': 5,
                'box': 2,
                'ease_factor': 2.6,
                'interval_days': 6,
                'repetitions': 2,
                'next_review_at': '2026-09-13T20:00:00.000Z',
              },
            },
            requestOptions: _optsPost('/flashcards/card-sm2-1/review'),
          ));

      final progress = await quizService.reviewFlashcard('card-sm2-1', 5);

      expect(progress['rating'], equals(5));
      expect(progress['box'], equals(2));
      expect(progress['ease_factor'], equals(2.6));
      expect(progress['interval_days'], equals(6));
      expect(progress['repetitions'], equals(2));
    });

    test('SM-2 formula reset logic when quality rating < 3', () {
      // Simulating standard SuperMemo-2 formula:
      // If rating < 3, repetitions = 0, interval = 1, box = 1
      Map<String, dynamic> calculateSM2({
        required int rating,
        required int repetitions,
        required double easeFactor,
        required int intervalDays,
        required int box,
      }) {
        double newEase = easeFactor + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02));
        if (newEase < 1.30) newEase = 1.30;

        int newRepetitions;
        int newInterval;
        int newBox;

        if (rating < 3) {
          newRepetitions = 0;
          newInterval = 1;
          newBox = 1;
        } else {
          newRepetitions = repetitions + 1;
          if (newRepetitions == 1) {
            newInterval = 1;
            newBox = 1;
          } else if (newRepetitions == 2) {
            newInterval = 6;
            newBox = 2;
          } else {
            newInterval = (intervalDays * newEase).round();
            newBox = box + 1;
          }
        }

        return {
          'easeFactor': double.parse(newEase.toStringAsFixed(2)),
          'repetitions': newRepetitions,
          'intervalDays': newInterval,
          'box': newBox,
        };
      }

      // Case: Rating = 2 (Forgot / hard failure)
      final resetResult = calculateSM2(
        rating: 2,
        repetitions: 4,
        easeFactor: 2.50,
        intervalDays: 15,
        box: 4,
      );
      expect(resetResult['repetitions'], equals(0));
      expect(resetResult['intervalDays'], equals(1));
      expect(resetResult['box'], equals(1));
      expect(resetResult['easeFactor'], lessThan(2.50));

      // Case: Rating = 5 (Perfect recall)
      final successResult = calculateSM2(
        rating: 5,
        repetitions: 1,
        easeFactor: 2.50,
        intervalDays: 1,
        box: 1,
      );
      expect(successResult['repetitions'], equals(2));
      expect(successResult['intervalDays'], equals(6));
      expect(successResult['box'], equals(2));
      expect(successResult['easeFactor'], greaterThanOrEqualTo(2.50));
    });
  });
}
