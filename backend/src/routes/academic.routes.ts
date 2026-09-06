import { Router } from 'express';
import { AcademicController } from '../controllers/academic.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { requireRole } from '../middleware/requireRole.js';
import { validateRequest } from '../middleware/validateRequest.js';
import {
  createUniversitySchema,
  updateUniversitySchema,
  createFacultySchema,
  updateFacultySchema,
  createDepartmentSchema,
  updateDepartmentSchema,
  createCourseSchema,
  updateCourseSchema,
  enrollStudentSchema,
} from '../validators/academic.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// ─── Universities (Public List/Get, Admin Manage) ───
router.get('/universities', asyncWrapper(AcademicController.listUniversities));
router.get('/universities/:id', asyncWrapper(AcademicController.getUniversity));
router.post(
  '/universities',
  authenticateUser,
  requireRole(['admin']),
  validateRequest({ body: createUniversitySchema }),
  asyncWrapper(AcademicController.createUniversity)
);
router.patch(
  '/universities/:id',
  authenticateUser,
  requireRole(['admin']),
  validateRequest({ body: updateUniversitySchema }),
  asyncWrapper(AcademicController.updateUniversity)
);
router.delete(
  '/universities/:id',
  authenticateUser,
  requireRole(['admin']),
  asyncWrapper(AcademicController.deleteUniversity)
);

// ─── Faculties (Public List/Get, Admin Manage) ───
router.get('/faculties', asyncWrapper(AcademicController.listFaculties));
router.get('/faculties/:id', asyncWrapper(AcademicController.getFaculty));
router.post(
  '/faculties',
  authenticateUser,
  requireRole(['admin']),
  validateRequest({ body: createFacultySchema }),
  asyncWrapper(AcademicController.createFaculty)
);
router.patch(
  '/faculties/:id',
  authenticateUser,
  requireRole(['admin']),
  validateRequest({ body: updateFacultySchema }),
  asyncWrapper(AcademicController.updateFaculty)
);
router.delete(
  '/faculties/:id',
  authenticateUser,
  requireRole(['admin']),
  asyncWrapper(AcademicController.deleteFaculty)
);

// ─── Departments (Public List/Get, Admin Manage) ───
router.get('/departments', asyncWrapper(AcademicController.listDepartments));
router.get('/departments/:id', asyncWrapper(AcademicController.getDepartment));
router.post(
  '/departments',
  authenticateUser,
  requireRole(['admin']),
  validateRequest({ body: createDepartmentSchema }),
  asyncWrapper(AcademicController.createDepartment)
);
router.patch(
  '/departments/:id',
  authenticateUser,
  requireRole(['admin']),
  validateRequest({ body: updateDepartmentSchema }),
  asyncWrapper(AcademicController.updateDepartment)
);
router.delete(
  '/departments/:id',
  authenticateUser,
  requireRole(['admin']),
  asyncWrapper(AcademicController.deleteDepartment)
);

// ─── Courses (Authenticated List, Teacher/Admin Create/Update, Admin Delete) ───
router.get('/courses', asyncWrapper(AcademicController.listCourses));
router.get('/courses/:id', asyncWrapper(AcademicController.getCourse));
router.post(
  '/courses',
  authenticateUser,
  requireRole(['teacher', 'admin']),
  validateRequest({ body: createCourseSchema }),
  asyncWrapper(AcademicController.createCourse)
);
router.patch(
  '/courses/:id',
  authenticateUser,
  requireRole(['teacher', 'admin']),
  validateRequest({ body: updateCourseSchema }),
  asyncWrapper(AcademicController.updateCourse)
);
router.delete(
  '/courses/:id',
  authenticateUser,
  requireRole(['admin']),
  asyncWrapper(AcademicController.deleteCourse)
);

// ─── Enrollment / Course Members ───
router.get(
  '/courses/:courseId/members',
  authenticateUser,
  asyncWrapper(AcademicController.getMembers)
);
router.post(
  '/courses/:courseId/enroll',
  authenticateUser,
  validateRequest({ body: enrollStudentSchema.partial() }),
  asyncWrapper(AcademicController.enroll)
);
router.delete(
  '/courses/:courseId/enroll',
  authenticateUser,
  asyncWrapper(AcademicController.unenroll)
);

export const academicRoutes = router;
