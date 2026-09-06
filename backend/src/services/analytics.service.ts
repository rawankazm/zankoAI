import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';

export interface UserAnalyticsData {
  total_registered_users: number;
  daily_active_users: number;
  monthly_active_users: number;
  new_users: number;
  new_users_this_month?: number;
  active_students: number;
  active_teachers: number;
  premium_users: number;
  free_users: number;
  period: string;
  alerts: any[];
  generated_at?: string;
}

export class AnalyticsService {
  /**
   * Fetch comprehensive user analytics for Admin Dashboard
   * Accurately distinguishes registered accounts from actual Monthly Active Users (MAU).
   */
  static async getUserAnalytics(): Promise<UserAnalyticsData> {
    try {
      // 1. Primary path: Call the high-performance PostgreSQL RPC
      const { data, error } = await supabaseAdmin.rpc('get_admin_user_analytics');

      if (!error && data) {
        return data as UserAnalyticsData;
      }

      if (error) {
        logger.warn(`[AnalyticsService] RPC get_admin_user_analytics returned error: ${error.message}, executing query fallback...`);
      }
    } catch (rpcErr: any) {
      logger.warn(`[AnalyticsService] RPC execution failed: ${rpcErr.message}, falling back to query aggregates...`);
    }

    // 2. Query fallback (if migration RPC was not yet applied or in test environment)
    return this.calculateUserAnalyticsFallback();
  }

  /**
   * Fallback query aggregator for testing and resilience
   */
  private static async calculateUserAnalyticsFallback(): Promise<UserAnalyticsData> {
    const today = new Date().toISOString().substring(0, 10);
    const currentMonthStart = `${today.substring(0, 7)}-01`;

    const [
      totalRegisteredRes,
      newUsersTodayRes,
      dauRes,
      mauRes,
      studentsRes,
      teachersRes,
      premiumRes,
      freeRes,
      alertsRes,
    ] = await Promise.all([
      // Total registered
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }),
      // New users today
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).gte('created_at', today),
      // DAU
      supabaseAdmin.from('user_daily_activity').select('user_id', { count: 'exact', head: true }).eq('activity_date', today),
      // MAU (all distinct active in month)
      supabaseAdmin.from('user_daily_activity').select('user_id').gte('activity_date', currentMonthStart),
      // Active students in month
      supabaseAdmin.from('user_daily_activity').select('user_id').gte('activity_date', currentMonthStart).eq('role', 'student'),
      // Active teachers in month
      supabaseAdmin.from('user_daily_activity').select('user_id').gte('activity_date', currentMonthStart).eq('role', 'teacher'),
      // Active premium in month
      supabaseAdmin.from('user_daily_activity').select('user_id').gte('activity_date', currentMonthStart).eq('plan', 'premium'),
      // Active free in month
      supabaseAdmin.from('user_daily_activity').select('user_id').gte('activity_date', currentMonthStart).eq('plan', 'free'),
      // Active unacknowledged alerts
      supabaseAdmin.from('system_cost_alerts').select('*').eq('acknowledged', false).limit(10),
    ]);

    // In JavaScript, deduplicate user_id arrays to guarantee 0 double-counting
    const uniqueMauSet = new Set((mauRes.data || []).map((r: any) => r.user_id));
    const uniqueStudentsSet = new Set((studentsRes.data || []).map((r: any) => r.user_id));
    const uniqueTeachersSet = new Set((teachersRes.data || []).map((r: any) => r.user_id));
    const uniquePremiumSet = new Set((premiumRes.data || []).map((r: any) => r.user_id));
    const uniqueFreeSet = new Set((freeRes.data || []).map((r: any) => r.user_id));

    return {
      total_registered_users: totalRegisteredRes.count || 0,
      daily_active_users: dauRes.count || 0,
      monthly_active_users: uniqueMauSet.size,
      new_users: newUsersTodayRes.count || 0,
      active_students: uniqueStudentsSet.size,
      active_teachers: uniqueTeachersSet.size,
      premium_users: uniquePremiumSet.size,
      free_users: uniqueFreeSet.size,
      period: today.substring(0, 7),
      alerts: alertsRes.data || [],
      generated_at: new Date().toISOString(),
    };
  }
}
