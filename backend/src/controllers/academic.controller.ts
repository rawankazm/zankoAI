import { Request, Response } from 'express';
import { AcademicService } from '../services/academic.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { QueryHelper } from '../utils/queryBuilder.js';

export class AcademicController {
  // ─── Universities ───
  static async listUniversities(req: Request, res: Response): Promise<Response> {
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['name', 'city', 'created_at'],
      defaultSortField: 'name',
      defaultSortAsc: true,
    });
    const result = await AcademicService.getUniversities(query);
    return ResponseFormatter.success(res, result);
  }

  static async getUniversity(req: Request, res: Response): Promise<Response> {
    const uni = await AcademicService.getUniversity(req.params.id);
    return ResponseFormatter.success(res, uni);
  }

  static async createUniversity(req: Request, res: Response): Promise<Response> {
    const uni = await AcademicService.createUniversity(req.body);
    return ResponseFormatter.created(res, uni, 'University created successfully');
  }

  static async updateUniversity(req: Request, res: Response): Promise<Response> {
    const uni = await AcademicService.updateUniversity(req.params.id, req.body);
    return ResponseFormatter.success(res, uni, 'University updated successfully');
  }

  static async deleteUniversity(req: Request, res: Response): Promise<Response> {
    await AcademicService.deleteUniversity(req.params.id);
    return ResponseFormatter.success(res, null, 'University deleted successfully');
  }

  // ─── Faculties ───
  static async listFaculties(req: Request, res: Response): Promise<Response> {
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['name', 'created_at'],
      defaultSortField: 'name',
      defaultSortAsc: true,
    });
    const result = await AcademicService.getFaculties(query);
    return ResponseFormatter.success(res, result);
  }

  static async getFaculty(req: Request, res: Response): Promise<Response> {
    const fac = await AcademicService.getFaculty(req.params.id);
    return ResponseFormatter.success(res, fac);
  }

  static async createFaculty(req: Request, res: Response): Promise<Response> {
    const fac = await AcademicService.createFaculty(req.body);
    return ResponseFormatter.created(res, fac, 'Faculty created successfully');
  }

  static async updateFaculty(req: Request, res: Response): Promise<Response> {
    const fac = await AcademicService.updateFaculty(req.params.id, req.body);
    return ResponseFormatter.success(res, fac, 'Faculty updated successfully');
  }

  static async deleteFaculty(req: Request, res: Response): Promise<Response> {
    await AcademicService.deleteFaculty(req.params.id);
    return ResponseFormatter.success(res, null, 'Faculty deleted successfully');
  }

  // ─── Departments ───
  static async listDepartments(req: Request, res: Response): Promise<Response> {
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['name', 'created_at'],
      defaultSortField: 'name',
      defaultSortAsc: true,
    });
    const result = await AcademicService.getDepartments(query);
    return ResponseFormatter.success(res, result);
  }

  static async getDepartment(req: Request, res: Response): Promise<Response> {
    const dept = await AcademicService.getDepartment(req.params.id);
    return ResponseFormatter.success(res, dept);
  }

  static async createDepartment(req: Request, res: Response): Promise<Response> {
    const dept = await AcademicService.createDepartment(req.body);
    return ResponseFormatter.created(res, dept, 'Department created successfully');
  }

  static async updateDepartment(req: Request, res: Response): Promise<Response> {
    const dept = await AcademicService.updateDepartment(req.params.id, req.body);
    return ResponseFormatter.success(res, dept, 'Department updated successfully');
  }

  static async deleteDepartment(req: Request, res: Response): Promise<Response> {
    await AcademicService.deleteDepartment(req.params.id);
    return ResponseFormatter.success(res, null, 'Department deleted successfully');
  }

  // ─── Courses ───
  static async listCourses(req: Request, res: Response): Promise<Response> {
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['title', 'code', 'stage', 'semester', 'created_at'],
      defaultSortField: 'created_at',
      defaultSortAsc: false,
    });
    const result = await AcademicService.getCourses(query);
    return ResponseFormatter.success(res, result);
  }

  static async getCourse(req: Request, res: Response): Promise<Response> {
    const course = await AcademicService.getCourse(req.params.id);
    return ResponseFormatter.success(res, course);
  }

  static async createCourse(req: Request, res: Response): Promise<Response> {
    const course = await AcademicService.createCourse(req.user!.id, req.profile!.role, req.body);
    return ResponseFormatter.created(res, course, 'Course created successfully');
  }

  static async updateCourse(req: Request, res: Response): Promise<Response> {
    const course = await AcademicService.updateCourse(req.params.id, req.user!.id, req.profile!.role, req.body);
    return ResponseFormatter.success(res, course, 'Course updated successfully');
  }

  static async deleteCourse(req: Request, res: Response): Promise<Response> {
    await AcademicService.deleteCourse(req.params.id);
    return ResponseFormatter.success(res, null, 'Course deleted successfully');
  }

  // ─── Enrollment ───
  static async enroll(req: Request, res: Response): Promise<Response> {
    const courseId = req.params.courseId || req.body.course_id;
    const role = req.body.role || 'student';
    const member = await AcademicService.enrollSelf(courseId, req.user!.id, role);
    return ResponseFormatter.created(res, member, 'Successfully enrolled in course');
  }

  static async unenroll(req: Request, res: Response): Promise<Response> {
    const courseId = req.params.courseId;
    await AcademicService.unenrollSelf(courseId, req.user!.id);
    return ResponseFormatter.success(res, null, 'Successfully unenrolled from course');
  }

  static async getMembers(req: Request, res: Response): Promise<Response> {
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['joined_at', 'role'],
      defaultSortField: 'joined_at',
      defaultSortAsc: false,
    });
    const members = await AcademicService.getCourseMembers(req.params.courseId, query);
    return ResponseFormatter.success(res, members);
  }
}
