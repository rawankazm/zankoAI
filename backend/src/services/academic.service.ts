import { AcademicRepository } from '../repositories/academic.repository.js';
import { ParsedQuery, QueryHelper } from '../utils/queryBuilder.js';
import { NotFoundError, ForbiddenError } from '../utils/apiError.js';

export class AcademicService {
  // ─── Universities ───
  static async getUniversities(query: ParsedQuery) {
    const { items, total } = await AcademicRepository.listUniversities(query);
    return QueryHelper.formatResult(items, total, query.page, query.limit);
  }

  static async getUniversity(id: string) {
    const uni = await AcademicRepository.getUniversityById(id);
    if (!uni) throw new NotFoundError('University not found');
    return uni;
  }

  static async createUniversity(data: any) {
    return AcademicRepository.createUniversity(data);
  }

  static async updateUniversity(id: string, data: any) {
    const updated = await AcademicRepository.updateUniversity(id, data);
    if (!updated) throw new NotFoundError('University not found');
    return updated;
  }

  static async deleteUniversity(id: string) {
    return AcademicRepository.deleteUniversity(id);
  }

  // ─── Faculties ───
  static async getFaculties(query: ParsedQuery) {
    const { items, total } = await AcademicRepository.listFaculties(query);
    return QueryHelper.formatResult(items, total, query.page, query.limit);
  }

  static async getFaculty(id: string) {
    const fac = await AcademicRepository.getFacultyById(id);
    if (!fac) throw new NotFoundError('Faculty not found');
    return fac;
  }

  static async createFaculty(data: any) {
    return AcademicRepository.createFaculty(data);
  }

  static async updateFaculty(id: string, data: any) {
    const updated = await AcademicRepository.updateFaculty(id, data);
    if (!updated) throw new NotFoundError('Faculty not found');
    return updated;
  }

  static async deleteFaculty(id: string) {
    return AcademicRepository.deleteFaculty(id);
  }

  // ─── Departments ───
  static async getDepartments(query: ParsedQuery) {
    const { items, total } = await AcademicRepository.listDepartments(query);
    return QueryHelper.formatResult(items, total, query.page, query.limit);
  }

  static async getDepartment(id: string) {
    const dept = await AcademicRepository.getDepartmentById(id);
    if (!dept) throw new NotFoundError('Department not found');
    return dept;
  }

  static async createDepartment(data: any) {
    return AcademicRepository.createDepartment(data);
  }

  static async updateDepartment(id: string, data: any) {
    const updated = await AcademicRepository.updateDepartment(id, data);
    if (!updated) throw new NotFoundError('Department not found');
    return updated;
  }

  static async deleteDepartment(id: string) {
    return AcademicRepository.deleteDepartment(id);
  }

  // ─── Courses ───
  static async getCourses(query: ParsedQuery) {
    const { items, total } = await AcademicRepository.listCourses(query);
    return QueryHelper.formatResult(items, total, query.page, query.limit);
  }

  static async getCourse(id: string) {
    const course = await AcademicRepository.getCourseById(id);
    if (!course) throw new NotFoundError('Course not found');
    return course;
  }

  static async createCourse(callerId: string, callerRole: string, data: any) {
    const instructorId = callerRole === 'admin' ? (data.instructor_id || callerId) : callerId;
    return AcademicRepository.createCourse({
      ...data,
      instructor_id: instructorId,
    });
  }

  static async updateCourse(id: string, callerId: string, callerRole: string, data: any) {
    const existing = await AcademicRepository.getCourseById(id);
    if (!existing) throw new NotFoundError('Course not found');

    if (callerRole !== 'admin' && existing.instructor_id !== callerId) {
      throw new ForbiddenError('Only the assigned instructor or admin can modify this course');
    }

    return AcademicRepository.updateCourse(id, data);
  }

  static async deleteCourse(id: string) {
    return AcademicRepository.deleteCourse(id);
  }

  // ─── Enrollment ───
  static async enrollSelf(courseId: string, userId: string, role = 'student') {
    const course = await AcademicRepository.getCourseById(courseId);
    if (!course) throw new NotFoundError('Course not found');
    return AcademicRepository.enrollMember(courseId, userId, role);
  }

  static async unenrollSelf(courseId: string, userId: string) {
    return AcademicRepository.unenrollMember(courseId, userId);
  }

  static async getCourseMembers(courseId: string, query: ParsedQuery) {
    const { items, total } = await AcademicRepository.getCourseMembers(courseId, query);
    return QueryHelper.formatResult(items, total, query.page, query.limit);
  }
}
