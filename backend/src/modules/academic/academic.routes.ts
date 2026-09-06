import { Router } from 'express';
import { authenticate } from '../../middleware/authenticate.js';
import { requireRole } from '../../middleware/require_role.js';
import {
  getUniversitiesHandler,
  getCoursesHandler,
  createLectureHandler,
} from './academic.controller.js';

const router = Router();

// Publicly view universities & departments
router.get('/universities', getUniversitiesHandler);

// Protected: View courses
router.get('/courses', authenticate, getCoursesHandler);

// Protected: Teachers & Admins can upload lectures
router.post('/lectures', authenticate, requireRole(['teacher', 'admin']), createLectureHandler);

export const academicRoutes = router;
