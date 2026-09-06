import { ProfileRepository } from '../repositories/profile.repository.js';
import { UserProfile } from '../types/user.types.js';
import { NotFoundError } from '../utils/apiError.js';

export class AuthService {
  static async getCurrentProfile(userId: string): Promise<UserProfile> {
    const profile = await ProfileRepository.findById(userId);
    if (!profile) {
      throw new NotFoundError('User profile not found');
    }
    return profile;
  }

  static async updateProfile(userId: string, updates: Partial<UserProfile>): Promise<UserProfile> {
    // Zero-trust: Disallow modifying privileged fields via normal user update
    const {
      role,
      plan,
      status,
      id,
      is_vip,
      vip_status,
      vip_expires_at,
      score,
      rank_title,
      created_at,
      ...safeUpdates
    } = updates as any;

    const updated = await ProfileRepository.update(userId, safeUpdates);
    if (!updated) {
      throw new NotFoundError('Failed to update profile');
    }
    return updated;
  }
}
