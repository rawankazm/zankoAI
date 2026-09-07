import { ProfileRepository } from '../repositories/profile.repository.js';
import { UserRole, UserStatus } from '../types/user.types.js';
import { supabaseAdmin } from '../config/supabase.js';

export class AdminService {
  static async listAllUsers(page = 1, limit = 50) {
    const offset = (page - 1) * limit;
    const { users, total } = await ProfileRepository.listUsers(limit, offset);
    return {
      users,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
    };
  }

  static async changeUserRole(userId: string, newRole: UserRole): Promise<boolean> {
    return ProfileRepository.updateRole(userId, newRole);
  }

  static async changeUserStatus(userId: string, newStatus: UserStatus): Promise<boolean> {
    return ProfileRepository.updateStatus(userId, newStatus);
  }

  static async setUserVip(userId: string, isVip: boolean, days = 30): Promise<boolean> {
    const expiry = isVip ? new Date(Date.now() + days * 86400000).toISOString() : null;
    const { error } = await supabaseAdmin
      .from('profiles')
      .update({
        is_vip: isVip,
        plan: isVip ? 'premium' : 'free',
        vip_status: isVip ? 'active' : 'none',
        vip_expiry: expiry,
        updated_at: new Date().toISOString(),
      })
      .eq('id', userId);

    if (error) return false;

    // Sync with production subscriptions table
    if (isVip && expiry) {
      await supabaseAdmin.from('subscriptions').upsert(
        {
          user_id: userId,
          plan: days >= 365 ? 'PREMIUM_YEARLY' : 'PREMIUM_MONTHLY',
          status: 'active',
          provider: 'admin',
          current_period_start: new Date().toISOString(),
          current_period_end: expiry,
          cancel_at_period_end: false,
          updated_at: new Date().toISOString(),
        },
        { onConflict: 'user_id' }
      );
    } else {
      await supabaseAdmin
        .from('subscriptions')
        .update({
          status: 'canceled',
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', userId);
    }

    return true;
  }

  static async getSystemStats() {
    const [profilesRes, coursesRes, aiRequestsRes, paymentsRes] = await Promise.all([
      supabaseAdmin.from('profiles').select('id, role', { count: 'exact' }),
      supabaseAdmin.from('courses').select('id', { count: 'exact' }),
      supabaseAdmin.from('ai_requests').select('id', { count: 'exact' }),
      supabaseAdmin.from('payments').select('id, amount', { count: 'exact' }),
    ]);

    return {
      totalUsers: profilesRes.count || 0,
      totalCourses: coursesRes.count || 0,
      totalAiRequests: aiRequestsRes.count || 0,
      totalPaymentsCount: paymentsRes.count || 0,
      timestamp: new Date().toISOString(),
    };
  }
}
