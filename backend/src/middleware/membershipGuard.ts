import { Request, Response, NextFunction } from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { ForbiddenError, UnauthorizedError, NotFoundError } from '../utils/apiError.js';

/**
 * Enforces that the calling user is an active member of the course,
 * the assigned course instructor, or a platform administrator.
 */
export const enforceCourseMember = (courseIdParamName = 'courseId') => {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user || !req.profile) {
        return next(new UnauthorizedError('Authentication required'));
      }

      const userId = req.user.id;
      const userRole = req.profile.role;

      // Admins have universal platform access
      if (userRole === 'admin') {
        return next();
      }

      const courseId = req.params[courseIdParamName] || req.body?.course_id || (req.query?.course_id as string);

      if (!courseId) {
        return next(new ForbiddenError('Course ID must be specified for membership verification'));
      }

      // 1. Check if user is the assigned course instructor
      const { data: course, error: courseErr } = await supabaseAdmin
        .from('courses')
        .select('id, instructor_id')
        .eq('id', courseId)
        .maybeSingle();

      if (courseErr || !course) {
        return next(new NotFoundError('Course not found'));
      }

      if (course.instructor_id === userId) {
        return next();
      }

      // 2. Check course enrollment in course_members
      const { data: membership, error: memErr } = await supabaseAdmin
        .from('course_members')
        .select('id, is_active, role')
        .eq('course_id', courseId)
        .eq('user_id', userId)
        .maybeSingle();

      if (memErr || !membership || !membership.is_active) {
        return next(
          new ForbiddenError('Access denied: You are not enrolled as an active member of this course')
        );
      }

      next();
    } catch (error) {
      next(error);
    }
  };
};

/**
 * Validates that the resource being accessed or manipulated is owned by the calling user,
 * or the calling user is an admin.
 */
export const checkResourceOwner = (
  resourceOwnerId: string,
  callerUserId: string,
  callerRole?: string
): void => {
  if (callerRole === 'admin') return;
  if (resourceOwnerId !== callerUserId) {
    throw new ForbiddenError('Access denied: You do not own this resource');
  }
};
