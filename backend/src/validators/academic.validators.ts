import { z } from 'zod';

// ─── Universities ───
export const createUniversitySchema = z.object({
  name: z.string().min(2).max(150),
  name_ku: z.string().max(150).optional(),
  name_ar: z.string().max(150).optional(),
  city: z.string().min(2).max(100),
  website_url: z.string().url().optional().or(z.literal('')),
  logo_url: z.string().url().optional().or(z.literal('')),
});

export const updateUniversitySchema = createUniversitySchema.partial();

// ─── Faculties ───
export const createFacultySchema = z.object({
  university_id: z.string().uuid(),
  name: z.string().min(2).max(150),
  name_ku: z.string().max(150).optional(),
  name_ar: z.string().max(150).optional(),
});

export const updateFacultySchema = createFacultySchema.partial();

// ─── Departments ───
export const createDepartmentSchema = z.object({
  faculty_id: z.string().uuid(),
  name: z.string().min(2).max(150),
  name_ku: z.string().max(150).optional(),
  name_ar: z.string().max(150).optional(),
});

export const updateDepartmentSchema = createDepartmentSchema.partial();

// ─── Courses ───
export const createCourseSchema = z.object({
  department_id: z.string().uuid(),
  instructor_id: z.string().uuid().optional(),
  title: z.string().min(3).max(200),
  title_ku: z.string().max(200).optional(),
  code: z.string().min(2).max(20),
  description: z.string().max(1000).optional(),
  stage: z.number().int().min(1).max(6).default(1),
  semester: z.number().int().min(1).max(12).default(1),
  credits: z.number().int().positive().default(3),
  cover_image_url: z.string().url().optional().or(z.literal('')),
  is_published: z.boolean().default(true),
});

export const updateCourseSchema = createCourseSchema.partial();

// ─── Course Enrollment ───
export const enrollStudentSchema = z.object({
  course_id: z.string().uuid(),
  role: z.enum(['student', 'ta']).default('student'),
});
