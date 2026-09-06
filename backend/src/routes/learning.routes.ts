import { Router } from 'express';
import { LearningController } from '../controllers/learning.controller.js';
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
  createQuizSchema,
  updateQuizSchema,
  createQuizQuestionSchema,
  submitQuizAttemptSchema,
  createFlashcardSchema,
  updateFlashcardSchema,
} from '../validators/learning.validators.js';
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
router.get('/quizzes/:id', asyncWrapper(LearningController.getQuiz));
router.post(
  '/quizzes',
  requireRole(['teacher', 'admin']),
  validateRequest({ body: createQuizSchema }),
  asyncWrapper(LearningController.createQuiz)
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
router.post(
  '/quizzes/:id/attempt',
  validateRequest({ body: submitQuizAttemptSchema }),
  asyncWrapper(LearningController.submitQuizAttempt)
);

// ─── Flashcards ───
router.get('/flashcards', asyncWrapper(LearningController.listFlashcards));
router.post(
  '/flashcards',
  validateRequest({ body: createFlashcardSchema }),
  asyncWrapper(LearningController.createFlashcard)
);
router.patch(
  '/flashcards/:id',
  validateRequest({ body: updateFlashcardSchema }),
  asyncWrapper(LearningController.updateFlashcard)
);
router.delete('/flashcards/:id', asyncWrapper(LearningController.deleteFlashcard));

export const learningRoutes = router;
