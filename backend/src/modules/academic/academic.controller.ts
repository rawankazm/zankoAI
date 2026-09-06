import { Request, Response, NextFunction } from 'express';
import { academicService } from './academic.service.js';
import { z } from 'zod';

const createLectureSchema = z.object({
  courseId: z.string().uuid(),
  title: z.string().min(2),
  fileUrl: z.string().url(),
  fileType: z.string(),
  fileSizeBytes: z.number().int().nonnegative(),
});

export const getUniversitiesHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await academicService.getUniversities();
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
};

export const getCoursesHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const departmentId = req.query.departmentId as string;
    const stage = req.query.stage ? parseInt(req.query.stage as string, 10) : undefined;

    if (!departmentId) {
      return res.status(400).json({ success: false, error: 'departmentId query parameter required' });
    }

    const data = await academicService.getCoursesByDepartment(departmentId, stage);
    res.json({ success: true, data });
  } catch (err) {
    next(err);
  }
};

export const createLectureHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { courseId, title, fileUrl, fileType, fileSizeBytes } = createLectureSchema.parse(req.body);
    const userId = req.user!.id;

    const lecture = await academicService.createLecture(
      courseId,
      userId,
      title,
      fileUrl,
      fileType,
      fileSizeBytes
    );

    res.status(201).json({ success: true, data: lecture });
  } catch (err) {
    next(err);
  }
};
