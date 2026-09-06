import { Request, Response } from 'express';
import { ProfileRepository } from '../repositories/profile.repository.js';
import { QueryHelper } from '../utils/queryBuilder.js';
import { NotFoundError, ForbiddenError, BadRequestError } from '../utils/apiError.js';
import { UserProfile } from '../types/user.types.js';

// Strip sensitive database fields for public directories
function sanitizePublicProfile(profile: UserProfile): Partial<UserProfile> {
  return {
    id: profile.id,
    full_name: profile.full_name,
    role: profile.role,
    university_id: profile.university_id,
    university_name: profile.university_name,
    department_id: profile.department_id,
    department_name: profile.department_name,
    city_name: profile.city_name,
    avatar_url: profile.avatar_url,
    score: profile.score,
    rank_title: profile.rank_title,
    created_at: profile.created_at,
  };
}

export class UserController {
  static async listUsers(req: Request, res: Response): Promise<void> {
    const query = QueryHelper.parse(req, {
      allowedSortFields: ['created_at', 'full_name', 'role', 'status', 'score'],
      defaultSortField: 'created_at',
      defaultSortAsc: false,
      defaultLimit: 20,
    });

    const result = await ProfileRepository.listWithQuery(query);
    const isAdmin = req.profile?.role === 'admin';

    // If not admin, sanitize all returned profiles to prevent sensitive leak
    const formattedItems = isAdmin
      ? result.items
      : result.items.map(sanitizePublicProfile);

    res.json({
      success: true,
      data: QueryHelper.formatResult(formattedItems, result.total, query.page, query.limit),
      timestamp: new Date().toISOString(),
    });
  }

  static async getUser(req: Request, res: Response): Promise<void> {
    const { id } = req.params;
    const profile = await ProfileRepository.findById(id);

    if (!profile) {
      throw new NotFoundError('User profile not found');
    }

    const isSelf = req.user?.id === profile.id;
    const isAdmin = req.profile?.role === 'admin';

    const data = isSelf || isAdmin ? profile : sanitizePublicProfile(profile);

    res.json({
      success: true,
      data,
      timestamp: new Date().toISOString(),
    });
  }

  static async updateUser(req: Request, res: Response): Promise<void> {
    const { id } = req.params;
    const isSelf = req.user?.id === id;
    const isAdmin = req.profile?.role === 'admin';

    if (!isSelf && !isAdmin) {
      throw new ForbiddenError('You can only update your own profile');
    }

    const updates = { ...req.body };

    // Strict zero-trust guard: non-admin can NEVER change role, plan, status, or score
    if (!isAdmin) {
      delete updates.role;
      delete updates.plan;
      delete updates.status;
      delete updates.score;
      delete updates.rank_title;
      delete updates.id;
      delete updates.is_vip;
      delete updates.vip_status;
      delete updates.vip_expiry;
    }

    const updated = await ProfileRepository.update(id, updates);
    if (!updated) {
      throw new NotFoundError('Failed to update profile');
    }

    res.json({
      success: true,
      data: updated,
      timestamp: new Date().toISOString(),
    });
  }

  static async deleteUser(req: Request, res: Response): Promise<void> {
    const { id } = req.params;

    const success = await ProfileRepository.delete(id);
    if (!success) {
      throw new NotFoundError('User not found or failed to delete');
    }

    res.json({
      success: true,
      data: { message: 'User account deactivated successfully' },
      timestamp: new Date().toISOString(),
    });
  }
}
