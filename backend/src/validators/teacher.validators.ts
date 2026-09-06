import { z } from 'zod';

export const createCourseSchema = z.object({
  title: z.string().min(3).max(200),
  title_ku: z.string().max(200).optional(),
  code: z.string().min(2).max(20),
  description: z.string().max(1000).optional(),
  stage: z.number().int().min(1).max(6).default(1),
  semester: z.number().int().min(1).max(12).default(1),
  credits: z.number().int().positive().default(3),
  department_id: z.string().uuid(),
});

export const updateGradeSchema = z.object({
  student_id: z.string().uuid(),
  course_id: z.string().uuid(),
  grade: z.number().min(0).max(100),
  feedback: z.string().max(500).optional(),
});
