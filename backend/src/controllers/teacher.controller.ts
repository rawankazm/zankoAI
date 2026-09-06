import { Request, Response } from 'express';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { TeacherService } from '../services/teacher.service.js';

export class TeacherController {
  static async getCourses(req: Request, res: Response): Promise<Response> {
    const courses = await TeacherService.getTeacherCourses(req.user!.id);
    return ResponseFormatter.success(res, courses);
  }

  static async createCourse(req: Request, res: Response): Promise<Response> {
    const course = await TeacherService.createCourse(req.user!.id, req.body);
    return ResponseFormatter.created(res, course, 'Course created successfully');
  }

  static async getCourseStudents(req: Request, res: Response): Promise<Response> {
    const courseId = req.params.courseId;
    const students = await TeacherService.getCourseStudents(courseId);
    return ResponseFormatter.success(res, students);
  }

  static async gradeStudent(req: Request, res: Response): Promise<Response> {
    const { course_id, student_id, grade, feedback } = req.body;
    const result = await TeacherService.updateStudentGrade(course_id, student_id, grade, feedback);
    return ResponseFormatter.success(res, result, 'Student graded successfully');
  }
}
