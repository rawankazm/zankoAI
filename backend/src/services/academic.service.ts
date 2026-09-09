import { AcademicRepository } from '../repositories/academic.repository.js';
import { ParsedQuery, QueryHelper } from '../utils/queryBuilder.js';
import { NotFoundError, ForbiddenError } from '../utils/apiError.js';
import { CacheService } from './cache.service.js';

const ACADEMIC_CACHE_TTL = 600; // 10 minutes
const COURSE_CACHE_TTL = 300;   // 5 minutes

export class AcademicService {
  // ─── Universities ───
  static async getUniversities(query: ParsedQuery) {
    const cacheKey = 'cache:academic:universities:' + JSON.stringify(query);
    return CacheService.getOrSet(cacheKey, ACADEMIC_CACHE_TTL, async () => {
      const { items, total } = await AcademicRepository.listUniversities(query);
      return QueryHelper.formatResult(items, total, query.page, query.limit);
    });
  }

  static async getUniversity(id: string) {
    const cacheKey = 'cache:academic:university:' + id;
    return CacheService.getOrSet(cacheKey, ACADEMIC_CACHE_TTL, async () => {
      const uni = await AcademicRepository.getUniversityById(id);
      if (!uni) throw new NotFoundError('University not found');
      return uni;
    });
  }

  static async createUniversity(data: any) {
    const result = await AcademicRepository.createUniversity(data);
    await CacheService.deletePattern('cache:academic:universities*');
    return result;
  }

  static async updateUniversity(id: string, data: any) {
    const updated = await AcademicRepository.updateUniversity(id, data);
    if (!updated) throw new NotFoundError('University not found');
    await CacheService.deletePattern('cache:academic:universit*');
    return updated;
  }

  static async deleteUniversity(id: string) {
    const result = await AcademicRepository.deleteUniversity(id);
    await CacheService.deletePattern('cache:academic:universit*');
    return result;
  }

  // ─── Faculties ───
  static async getFaculties(query: ParsedQuery) {
    const cacheKey = 'cache:academic:faculties:' + JSON.stringify(query);
    return CacheService.getOrSet(cacheKey, ACADEMIC_CACHE_TTL, async () => {
      const { items, total } = await AcademicRepository.listFaculties(query);
      return QueryHelper.formatResult(items, total, query.page, query.limit);
    });
  }

  static async getFaculty(id: string) {
    const cacheKey = 'cache:academic:faculty:' + id;
    return CacheService.getOrSet(cacheKey, ACADEMIC_CACHE_TTL, async () => {
      const fac = await AcademicRepository.getFacultyById(id);
      if (!fac) throw new NotFoundError('Faculty not found');
      return fac;
    });
  }

  static async createFaculty(data: any) {
    const result = await AcademicRepository.createFaculty(data);
    await CacheService.deletePattern('cache:academic:facult*');
    return result;
  }

  static async updateFaculty(id: string, data: any) {
    const updated = await AcademicRepository.updateFaculty(id, data);
    if (!updated) throw new NotFoundError('Faculty not found');
    await CacheService.deletePattern('cache:academic:facult*');
    return updated;
  }

  static async deleteFaculty(id: string) {
    const result = await AcademicRepository.deleteFaculty(id);
    await CacheService.deletePattern('cache:academic:facult*');
    return result;
  }

  // ─── Departments ───
  static async getDepartments(query: ParsedQuery) {
    const cacheKey = 'cache:academic:departments:' + JSON.stringify(query);
    return CacheService.getOrSet(cacheKey, ACADEMIC_CACHE_TTL, async () => {
      const { items, total } = await AcademicRepository.listDepartments(query);
      return QueryHelper.formatResult(items, total, query.page, query.limit);
    });
  }

  static async getDepartment(id: string) {
    const cacheKey = 'cache:academic:department:' + id;
    return CacheService.getOrSet(cacheKey, ACADEMIC_CACHE_TTL, async () => {
      const dept = await AcademicRepository.getDepartmentById(id);
      if (!dept) throw new NotFoundError('Department not found');
      return dept;
    });
  }

  static async createDepartment(data: any) {
    const result = await AcademicRepository.createDepartment(data);
    await CacheService.deletePattern('cache:academic:department*');
    return result;
  }

  static async updateDepartment(id: string, data: any) {
    const updated = await AcademicRepository.updateDepartment(id, data);
    if (!updated) throw new NotFoundError('Department not found');
    await CacheService.deletePattern('cache:academic:department*');
    return updated;
  }

  static async deleteDepartment(id: string) {
    const result = await AcademicRepository.deleteDepartment(id);
    await CacheService.deletePattern('cache:academic:department*');
    return result;
  }

  // ─── Courses ───
  static async getCourses(query: ParsedQuery) {
    const cacheKey = 'cache:academic:courses:' + JSON.stringify(query);
    return CacheService.getOrSet(cacheKey, COURSE_CACHE_TTL, async () => {
      const { items, total } = await AcademicRepository.listCourses(query);
      return QueryHelper.formatResult(items, total, query.page, query.limit);
    });
  }

  static async getCourse(id: string) {
    const cacheKey = 'cache:academic:course:' + id;
    return CacheService.getOrSet(cacheKey, COURSE_CACHE_TTL, async () => {
      const course = await AcademicRepository.getCourseById(id);
      if (!course) throw new NotFoundError('Course not found');
      return course;
    });
  }

  static async createCourse(callerId: string, callerRole: string, data: any) {
    const instructorId = callerRole === 'admin' ? (data.instructor_id || callerId) : callerId;
    const result = await AcademicRepository.createCourse({
      ...data,
      instructor_id: instructorId,
    });
    await CacheService.deletePattern('cache:academic:course*');
    return result;
  }

  static async updateCourse(id: string, callerId: string, callerRole: string, data: any) {
    const existing = await AcademicRepository.getCourseById(id);
    if (!existing) throw new NotFoundError('Course not found');

    if (callerRole !== 'admin' && existing.instructor_id !== callerId) {
      throw new ForbiddenError('Only the assigned instructor or admin can modify this course');
    }

    const updated = await AcademicRepository.updateCourse(id, data);
    await CacheService.deletePattern('cache:academic:course*');
    return updated;
  }

  static async deleteCourse(id: string) {
    const result = await AcademicRepository.deleteCourse(id);
    await CacheService.deletePattern('cache:academic:course*');
    return result;
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
