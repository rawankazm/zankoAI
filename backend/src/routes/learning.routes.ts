import { Router } from 'express';
import { LearningController } from '../controllers/learning.controller.js';
import { QuizController } from '../controllers/quiz.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { requireRole } from '../middleware/requireRole.js';
import { enforceCourseMember } from '../middleware/membershipGuard.js';
import { validateRequest } from '../middleware/validateRequest.js';
import {
  createLectureSchema,
  updateLectureSchema,
  createAssignmentSchema,
  updateAssignmentSchema,
  submitAssignmentSchema,
  gradeSubmissionSchema,
  updateQuizSchema,
  createQuizQuestionSchema,
  createFlashcardSchema,
  updateFlashcardSchema,
} from '../validators/learning.validators.js';
import {
  createQuizSchema as createQuizNewSchema,
  submitQuizAttemptSchema as submitQuizAttemptNewSchema,
  reviewFlashcardSchema,
} from '../validators/quiz.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// All learning routes require authentication
router.use(authenticateUser);

// ─── Lectures ───
router.get(
  '/courses/:courseId/lectures',
  enforceCourseMember('courseId'),
  asyncWrapper(LearningController.listLectures)
);
router.get('/lectures/:id', asyncWrapper(LearningController.getLecture));
router.post(
  '/lectures',
  requireRole(['teacher', 'admin']),
  validateRequest({ body: createLectureSchema }),
  asyncWrapper(LearningController.createLecture)
);
router.patch(
  '/lectures/:id',
  requireRole(['teacher', 'admin']),
  validateRequest({ body: updateLectureSchema }),
  asyncWrapper(LearningController.updateLecture)
);
router.delete(
  '/lectures/:id',
  requireRole(['teacher', 'admin']),
  asyncWrapper(LearningController.deleteLecture)
);

// ─── Assignments ───
router.get(
  '/courses/:courseId/assignments',
  enforceCourseMember('courseId'),
  asyncWrapper(LearningController.listAssignments)
);
router.get('/assignments/:id', asyncWrapper(LearningController.getAssignment));
router.post(
  '/assignments',
  requireRole(['teacher', 'admin']),
  validateRequest({ body: createAssignmentSchema }),
  asyncWrapper(LearningController.createAssignment)
);
router.patch(
  '/assignments/:id',
  requireRole(['teacher', 'admin']),
  validateRequest({ body: updateAssignmentSchema }),
  asyncWrapper(LearningController.updateAssignment)
);
router.delete(
  '/assignments/:id',
  requireRole(['teacher', 'admin']),
  asyncWrapper(LearningController.deleteAssignment)
);

// ─── Assignment Submissions ───
router.get(
  '/assignments/:assignmentId/submissions',
  asyncWrapper(LearningController.getSubmissions)
);
router.post(
  '/assignments/:assignmentId/submit',
  validateRequest({ body: submitAssignmentSchema }),
  asyncWrapper(LearningController.submitAssignment)
);
router.patch(
  '/submissions/:submissionId/grade',
  requireRole(['teacher', 'admin']),
  validateRequest({ body: gradeSubmissionSchema }),
  asyncWrapper(LearningController.gradeSubmission)
);

// ─── Quizzes ───
router.get(
  '/courses/:courseId/quizzes',
  enforceCourseMember('courseId'),
  asyncWrapper(LearningController.listQuizzes)
);
router.get('/quizzes/:id', asyncWrapper(QuizController.getQuiz));
router.post(
  '/quizzes',
  validateRequest({ body: createQuizNewSchema }),
  asyncWrapper(QuizController.createQuiz)
);
router.post('/quizzes/:id/start', asyncWrapper(QuizController.startAttempt));
router.post(
  '/quizzes/:id/submit',
  validateRequest({ body: submitQuizAttemptNewSchema }),
  asyncWrapper(QuizController.submitAttempt)
);
// Legacy attempt route alias
router.post(
  '/quizzes/:id/attempt',
  validateRequest({ body: submitQuizAttemptNewSchema }),
  asyncWrapper(QuizController.submitAttempt)
);
router.patch(
  '/quizzes/:id',
  requireRole(['teacher', 'admin']),
  validateRequest({ body: updateQuizSchema }),
  asyncWrapper(LearningController.updateQuiz)
);
router.post(
  '/quizzes/:id/questions',
  requireRole(['teacher', 'admin']),
  validateRequest({ body: createQuizQuestionSchema.omit({ quiz_id: true }) }),
  (req, res, next) => {
    req.body.quiz_id = req.params.id;
    next();
  },
  asyncWrapper(LearningController.addQuestion)
);

// ─── Flashcards ───
router.get('/flashcards', asyncWrapper(LearningController.listFlashcards));
router.get('/flashcards/due', asyncWrapper(QuizController.getDueFlashcards));
router.post(
  '/flashcards',
  validateRequest({ body: createFlashcardSchema }),
  asyncWrapper(LearningController.createFlashcard)
);
router.post(
  '/flashcards/:id/review',
  validateRequest({ body: reviewFlashcardSchema }),
  asyncWrapper(QuizController.reviewFlashcard)
);
router.patch(
  '/flashcards/:id',
  validateRequest({ body: updateFlashcardSchema }),
  asyncWrapper(LearningController.updateFlashcard)
);
router.delete('/flashcards/:id', asyncWrapper(LearningController.deleteFlashcard));

export const learningRoutes = router;
