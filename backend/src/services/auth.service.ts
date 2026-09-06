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
    // Disallow modifying privileged fields via normal update
    const { role, plan, status, id, ...safeUpdates } = updates as any;

    const updated = await ProfileRepository.update(userId, safeUpdates);
    if (!updated) {
      throw new NotFoundError('Failed to update profile');
    }
    return updated;
  }
}
