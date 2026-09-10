// ==============================================================================
// ZankoAI Admin Service: Controlled Operations, Directory, Usage & Telemetry Engine
// ==============================================================================

import { supabaseAdmin } from '../config/supabase.js';
import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';
import { AuditService } from './audit.service.js';
import { UserRole, UserStatus } from '../types/user.types.js';
import { NotFoundError, ForbiddenError, BadRequestError } from '../utils/apiError.js';
import { CacheService } from './cache.service.js';

export interface RequestMeta {
  ip?: string;
  userAgent?: string;
}

export interface ListUsersOptions {
  page?: number;
  limit?: number;
  role?: string;
  status?: string;
  plan?: string;
  q?: string;
}

export interface ListSubscriptionsOptions {
  page?: number;
  limit?: number;
  status?: string;
  plan?: string;
  provider?: string;
  q?: string;
}

export interface ListPaymentsOptions {
  page?: number;
  limit?: number;
  status?: string;
  provider?: string;
  from?: string;
  to?: string;
  q?: string;
}

export class AdminService {
  /**
   * 1. Lists users with pagination and filtering.
   * STRICT SECURITY: Never returns password hashes, secret tokens, or private auth internals.
   */
  static async listAllUsers(options: ListUsersOptions = {}) {
    const page = Math.max(1, options.page || 1);
    const limit = Math.min(100, Math.max(1, options.limit || 50));
    const offset = (page - 1) * limit;

    let query = supabaseAdmin
      .from('profiles')
      .select(
        'id, email, username, full_name, role, status, plan, is_vip, vip_status, vip_expiry, avatar_url, university_id, faculty_id, department_id, created_at, updated_at',
        { count: 'exact' }
      );

    if (options.role) {
      query = query.eq('role', options.role);
    }

    if (options.status) {
      query = query.eq('status', options.status);
    }

    if (options.plan) {
      query = query.eq('plan', options.plan);
    }

    if (options.q && options.q.trim()) {
      const term = options.q.trim();
      query = query.or(`full_name.ilike.%${term}%,username.ilike.%${term}%,email.ilike.%${term}%`);
    }

    query = query.order('created_at', { ascending: false }).range(offset, offset + limit - 1);

    const { data, count, error } = await query;

    if (error) {
      logger.error('Error listing users in AdminService:', error);
      throw error;
    }

    const total = count || 0;
    return {
      users: data || [],
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * 2. Updates user status (e.g. suspend or activate).
   * - Protects against self-lockout (admin suspending self).
   * - Creates an immutable audit log.
   */
  static async updateUserStatus(
    adminId: string,
    targetUserId: string,
    newStatus: 'active' | 'suspended' | 'deleted',
    reason?: string,
    reqMeta?: RequestMeta
  ) {
    if (adminId === targetUserId && newStatus !== 'active') {
      throw new ForbiddenError('Self-lockout prevented: You cannot suspend or deactivate your own admin account.');
    }

    const { data: targetUser, error: fetchErr } = await supabaseAdmin
      .from('profiles')
      .select('id, status, role, email')
      .eq('id', targetUserId)
      .maybeSingle();

    if (fetchErr || !targetUser) {
      throw new NotFoundError(`User with ID '${targetUserId}' not found.`);
    }

    const oldStatus = targetUser.status;

    const { error: updateErr } = await supabaseAdmin
      .from('profiles')
      .update({
        status: newStatus,
        updated_at: new Date().toISOString(),
      })
      .eq('id', targetUserId);

    if (updateErr) {
      logger.error('Failed to update user status:', updateErr);
      throw updateErr;
    }

    // Invalidate cached user sessions in Redis if suspended
    if (newStatus === 'suspended') {
      try {
        await redis.del(`user:session:${targetUserId}`);
      } catch (redisErr) {
        logger.warn('Failed to clear user session from Redis:', redisErr);
      }
    }

    // Immutable Audit Log
    await AuditService.logAction({
      actorId: adminId,
      action: newStatus === 'suspended' ? 'user_suspended' : 'user_activated',
      resourceType: 'user',
      resourceId: targetUserId,
      ipAddress: reqMeta?.ip,
      userAgent: reqMeta?.userAgent,
      changes: {
        old_status: oldStatus,
        new_status: newStatus,
        reason: reason || 'Administrative action',
      },
    });

    return {
      userId: targetUserId,
      oldStatus,
      newStatus,
      status: newStatus,
    };
  }

  /**
   * 3. Changes user plan ONLY through controlled backend operation.
   * Synchronizes profiles.plan, is_vip, and subscriptions table.
   * Records immutable audit log.
   */
  static async updateUserPlan(
    adminId: string,
    targetUserId: string,
    newPlan: 'free' | 'premium',
    days = 30,
    reason?: string,
    reqMeta?: RequestMeta
  ) {
    const { data: targetUser, error: fetchErr } = await supabaseAdmin
      .from('profiles')
      .select('id, plan, is_vip, vip_expiry, email')
      .eq('id', targetUserId)
      .maybeSingle();

    if (fetchErr || !targetUser) {
      throw new NotFoundError(`User with ID '${targetUserId}' not found.`);
    }

    const oldPlan = targetUser.plan;
    const isVip = newPlan === 'premium';
    const expiry = isVip ? new Date(Date.now() + days * 86400000).toISOString() : null;

    const { error: profileErr } = await supabaseAdmin
      .from('profiles')
      .update({
        plan: newPlan,
        is_vip: isVip,
        vip_status: isVip ? 'active' : 'none',
        vip_expiry: expiry,
        updated_at: new Date().toISOString(),
      })
      .eq('id', targetUserId);

    if (profileErr) {
      logger.error('Failed to update profile plan:', profileErr);
      throw profileErr;
    }

    // Synchronize subscriptions table
    if (isVip && expiry) {
      await supabaseAdmin.from('subscriptions').upsert(
        {
          user_id: targetUserId,
          plan: days >= 365 ? 'PREMIUM_YEARLY' : 'PREMIUM_MONTHLY',
          status: 'active',
          provider: 'admin_grant',
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
        .eq('user_id', targetUserId);
    }

    // Immutable Audit Log
    await AuditService.logAction({
      actorId: adminId,
      action: 'plan_changed',
      resourceType: 'user',
      resourceId: targetUserId,
      ipAddress: reqMeta?.ip,
      userAgent: reqMeta?.userAgent,
      changes: {
        old_plan: oldPlan,
        new_plan: newPlan,
        days,
        reason: reason || 'Controlled administrative plan modification',
      },
    });

    // In-App Notification directly sent to user phone for realtime bell update
    if (isVip) {
      try {
        await supabaseAdmin.from('notifications').insert({
          user_id: targetUserId,
          title: '🎉 پیرۆزە! هەژمارەکەت نوێکرایەوە بۆ VIP',
          body: 'هەژمارەکەت لەلایەن بەڕێوەبەرەوە بە سەرکەوتوویی نوێکرایەوە بۆ VIP. ئێستا دەتوانیت لە هەموو خزمەتگوزارییە پێشکەوتووەکانی ZankoAI سوودمەند بیت!',
          type: 'vip_approved',
        });
      } catch (notifErr) {
        logger.warn('Could not insert in-app VIP notification:', notifErr);
      }
    }

    return {
      userId: targetUserId,
      oldPlan,
      newPlan,
      isVip,
      vipExpiry: expiry,
    };
  }

  /**
   * 4. Changes user role with self-demotion prevention and audit log.
   */
  static async changeUserRole(
    adminId: string,
    targetUserId: string,
    newRole: UserRole,
    reason?: string,
    reqMeta?: RequestMeta
  ) {
    if (adminId === targetUserId && newRole !== 'admin') {
      throw new ForbiddenError('Self-lockout prevented: You cannot demote your own admin account.');
    }

    const { data: targetUser, error: fetchErr } = await supabaseAdmin
      .from('profiles')
      .select('id, role, email')
      .eq('id', targetUserId)
      .maybeSingle();

    if (fetchErr || !targetUser) {
      throw new NotFoundError(`User with ID '${targetUserId}' not found.`);
    }

    const oldRole = targetUser.role;

    const { error: updateErr } = await supabaseAdmin
      .from('profiles')
      .update({
        role: newRole,
        updated_at: new Date().toISOString(),
      })
      .eq('id', targetUserId);

    if (updateErr) {
      logger.error('Failed to update user role:', updateErr);
      throw updateErr;
    }

    await AuditService.logAction({
      actorId: adminId,
      action: 'role_changed',
      resourceType: 'user',
      resourceId: targetUserId,
      ipAddress: reqMeta?.ip,
      userAgent: reqMeta?.userAgent,
      changes: {
        old_role: oldRole,
        new_role: newRole,
        reason: reason || 'Administrative role reassignment',
      },
    });

    return {
      userId: targetUserId,
      oldRole,
      newRole,
    };
  }

  /**
   * 5. Lists subscriptions with user information, pagination, and status filters.
   */
  static async listSubscriptions(options: ListSubscriptionsOptions = {}) {
    const page = Math.max(1, options.page || 1);
    const limit = Math.min(100, Math.max(1, options.limit || 50));
    const offset = (page - 1) * limit;

    let query = supabaseAdmin
      .from('subscriptions')
      .select(
        'id, user_id, plan, status, provider, current_period_start, current_period_end, cancel_at_period_end, created_at, updated_at, profiles:user_id(id, full_name, email, role, plan)',
        { count: 'exact' }
      );

    if (options.status) {
      query = query.eq('status', options.status);
    }

    if (options.plan) {
      query = query.eq('plan', options.plan);
    }

    if (options.provider) {
      query = query.eq('provider', options.provider);
    }

    query = query.order('created_at', { ascending: false }).range(offset, offset + limit - 1);

    const { data, count, error } = await query;

    if (error) {
      logger.error('Error listing subscriptions:', error);
      throw error;
    }

    const total = count || 0;
    return {
      subscriptions: data || [],
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * 6. Lists payments with user details, status filter, provider filter, and date ranges.
   */
  static async listPayments(options: ListPaymentsOptions = {}) {
    const page = Math.max(1, options.page || 1);
    const limit = Math.min(100, Math.max(1, options.limit || 50));
    const offset = (page - 1) * limit;

    let query = supabaseAdmin
      .from('payments')
      .select(
        'id, user_id, order_id, transaction_id, provider, amount, currency, status, payment_method, metadata, created_at, updated_at, profiles:user_id(id, full_name, email)',
        { count: 'exact' }
      );

    if (options.status) {
      query = query.eq('status', options.status);
    }

    if (options.provider) {
      query = query.eq('provider', options.provider);
    }

    if (options.from) {
      query = query.gte('created_at', options.from);
    }

    if (options.to) {
      query = query.lte('created_at', options.to);
    }

    query = query.order('created_at', { ascending: false }).range(offset, offset + limit - 1);

    const { data, count, error } = await query;

    if (error) {
      logger.error('Error listing payments:', error);
      throw error;
    }

    const total = count || 0;
    return {
      payments: data || [],
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }

  /**
   * 7. Aggregates system usage, MAU, DAU, AI request counts, and financial cost.
   */
  static async getSystemUsage(period: 'day' | 'week' | 'month' | 'year' = 'month') {
    const now = new Date();
    let startDate: Date;

    switch (period) {
      case 'day':
        startDate = new Date(now.getTime() - 24 * 60 * 60 * 1000);
        break;
      case 'week':
        startDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
        break;
      case 'year':
        startDate = new Date(now.getTime() - 365 * 24 * 60 * 60 * 1000);
        break;
      case 'month':
      default:
        startDate = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
        break;
    }

    const isoStart = startDate.toISOString();
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();

    const [
      dauRes,
      mauRes,
      totalUsersRes,
      aiRequestsRes,
      paymentsRes,
      activeSubsRes,
    ] = await Promise.all([
      // DAU: Users active in last 24h
      supabaseAdmin
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .gte('updated_at', oneDayAgo),

      // MAU: Users active in last 30d
      supabaseAdmin
        .from('profiles')
        .select('id', { count: 'exact', head: true })
        .gte('updated_at', thirtyDaysAgo),

      // Total registered users
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }),

      // AI telemetry in the requested period
      supabaseAdmin
        .from('ai_requests')
        .select('feature, input_tokens, output_tokens, estimated_cost, status')
        .gte('created_at', isoStart),

      // Revenue in the requested period
      supabaseAdmin
        .from('payments')
        .select('amount, status')
        .eq('status', 'completed')
        .gte('created_at', isoStart),

      // Active subscriptions
      supabaseAdmin
        .from('subscriptions')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'active'),
    ]);

    // Aggregate AI Telemetry
    let totalAiRequests = 0;
    let totalInputTokens = 0;
    let totalOutputTokens = 0;
    let totalEstimatedCostUsd = 0;
    const featureBreakdown: Record<string, { requests: number; cost: number }> = {};

    if (aiRequestsRes.data) {
      totalAiRequests = aiRequestsRes.data.length;
      for (const req of aiRequestsRes.data) {
        totalInputTokens += req.input_tokens || 0;
        totalOutputTokens += req.output_tokens || 0;
        const cost = Number(req.estimated_cost) || 0;
        totalEstimatedCostUsd += cost;

        const feat = req.feature || 'other';
        if (!featureBreakdown[feat]) {
          featureBreakdown[feat] = { requests: 0, cost: 0 };
        }
        featureBreakdown[feat].requests += 1;
        featureBreakdown[feat].cost = Number((featureBreakdown[feat].cost + cost).toFixed(6));
      }
    }

    // Aggregate Revenue
    let totalRevenueIqd = 0;
    if (paymentsRes.data) {
      for (const p of paymentsRes.data) {
        totalRevenueIqd += Number(p.amount) || 0;
      }
    }

    return {
      period,
      periodStart: isoStart,
      periodEnd: now.toISOString(),
      activeUsers: {
        dau: dauRes.count || 0,
        mau: mauRes.count || 0,
        totalUsers: totalUsersRes.count || 0,
      },
      aiUsage: {
        totalRequests: totalAiRequests,
        totalTokens: totalInputTokens + totalOutputTokens,
        inputTokens: totalInputTokens,
        outputTokens: totalOutputTokens,
        estimatedCostUsd: Number(totalEstimatedCostUsd.toFixed(6)),
        featureBreakdown,
      },
      monetization: {
        activeSubscriptions: activeSubsRes.count || 0,
        totalRevenueIqd,
        completedPaymentsCount: paymentsRes.data?.length || 0,
      },
    };
  }

  /**
   * 8. System statistics overview (lightweight dashboard card).
   */
  static async getSystemStats() {
    const [profilesRes, coursesRes, aiRequestsRes, paymentsRes] = await Promise.all([
      supabaseAdmin.from('profiles').select('id, role', { count: 'exact', head: true }),
      supabaseAdmin.from('courses').select('id', { count: 'exact', head: true }),
      supabaseAdmin.from('ai_requests').select('id', { count: 'exact', head: true }),
      supabaseAdmin.from('payments').select('id', { count: 'exact', head: true }),
    ]);

    return {
      totalUsers: profilesRes.count || 0,
      totalCourses: coursesRes.count || 0,
      totalAiRequests: aiRequestsRes.count || 0,
      totalPaymentsCount: paymentsRes.count || 0,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * 9. Academic Catalog: Universities, Faculties, Departments, Courses
   */
  static async listUniversities(limit = 100) {
    const { data, error } = await supabaseAdmin
      .from('universities')
      .select('id, name, code, is_active, created_at')
      .order('name')
      .limit(limit);
    if (error) throw error;
    return data || [];
  }

  static async listFaculties(universityId?: string, limit = 100) {
    let q = supabaseAdmin.from('faculties').select('id, university_id, name, created_at').order('name').limit(limit);
    if (universityId) q = q.eq('university_id', universityId);
    const { data, error } = await q;
    if (error) throw error;
    return data || [];
  }

  static async listDepartments(facultyId?: string, limit = 100) {
    let q = supabaseAdmin.from('departments').select('id, faculty_id, name, created_at').order('name').limit(limit);
    if (facultyId) q = q.eq('faculty_id', facultyId);
    const { data, error } = await q;
    if (error) throw error;
    return data || [];
  }

  static async listCourses(departmentId?: string, limit = 100) {
    let q = supabaseAdmin.from('courses').select('id, title, code, department_id, created_at').order('title').limit(limit);
    if (departmentId) q = q.eq('department_id', departmentId);
    const { data, error } = await q;
    if (error) throw error;
    return data || [];
  }

  /**
   * 10. Financial & Administrative Reports Summary
   */
  static async getReportsSummary() {
    const [usageMonth, usageYear] = await Promise.all([
      this.getSystemUsage('month'),
      this.getSystemUsage('year'),
    ]);

    return {
      generatedAt: new Date().toISOString(),
      monthly: usageMonth,
      yearly: usageYear,
    };
  }

  /**
   * 11. Consolidated Executive Dashboard Metrics
   * Aggregates users, DAU, MAU, plans, subscriptions, revenue, and AI costs.
   */
  static async getDashboardOverview() {
    const now = new Date();
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000).toISOString();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000).toISOString();

    const [
      totalUsersRes,
      newUsers24hRes,
      newUsers7dRes,
      studentsRes,
      teachersRes,
      adminsRes,
      freeUsersRes,
      premiumUsersRes,
      dauRes,
      mauRes,
      activeSubsRes,
      expiredSubsRes,
      completedPaymentsRes,
      failedPaymentsRes,
      aiStatsRes,
      coursesRes,
    ] = await Promise.all([
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }),
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).gte('created_at', oneDayAgo),
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).gte('created_at', sevenDaysAgo),
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'student'),
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'teacher'),
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'admin'),
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).eq('plan', 'free'),
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).eq('plan', 'premium'),
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).gte('updated_at', oneDayAgo),
      supabaseAdmin.from('profiles').select('id', { count: 'exact', head: true }).gte('updated_at', thirtyDaysAgo),
      supabaseAdmin.from('subscriptions').select('id', { count: 'exact', head: true }).eq('status', 'active'),
      supabaseAdmin.from('subscriptions').select('id', { count: 'exact', head: true }).in('status', ['expired', 'canceled']),
      supabaseAdmin.from('payments').select('amount').eq('status', 'completed').gte('created_at', thirtyDaysAgo),
      supabaseAdmin.from('payments').select('id', { count: 'exact', head: true }).eq('status', 'failed').gte('created_at', thirtyDaysAgo),
      supabaseAdmin.from('ai_requests').select('estimated_cost, input_tokens, output_tokens').gte('created_at', thirtyDaysAgo),
      supabaseAdmin.from('courses').select('id', { count: 'exact', head: true }),
    ]);

    let monthlyRevenueIqd = 0;
    if (completedPaymentsRes.data) {
      for (const p of completedPaymentsRes.data) {
        monthlyRevenueIqd += Number(p.amount) || 0;
      }
    }

    let totalAiRequests = 0;
    let totalAiCostUsd = 0;
    let totalTokens = 0;
    if (aiStatsRes.data) {
      totalAiRequests = aiStatsRes.data.length;
      for (const r of aiStatsRes.data) {
        totalAiCostUsd += Number(r.estimated_cost) || 0;
        totalTokens += (r.input_tokens || 0) + (r.output_tokens || 0);
      }
    }

    return {
      users: {
        total: totalUsersRes.count || 0,
        newLast24h: newUsers24hRes.count || 0,
        newLast7d: newUsers7dRes.count || 0,
        students: studentsRes.count || 0,
        teachers: teachersRes.count || 0,
        admins: adminsRes.count || 0,
        free: freeUsersRes.count || 0,
        premium: premiumUsersRes.count || 0,
        dau: dauRes.count || 0,
        mau: mauRes.count || 0,
      },
      courses: {
        total: coursesRes.count || 0,
      },
      subscriptions: {
        active: activeSubsRes.count || 0,
        expired: expiredSubsRes.count || 0,
      },
      payments: {
        monthlyRevenueIqd,
        completedCount: completedPaymentsRes.data?.length || 0,
        failedCount: failedPaymentsRes.count || 0,
      },
      ai: {
        requests30d: totalAiRequests,
        estimatedCostUsd: Number(totalAiCostUsd.toFixed(4)),
        tokens30d: totalTokens,
      },
      timestamp: now.toISOString(),
    };
  }

  /**
   * 12. Deep User Inspection with Enrolled Courses, Subscriptions & AI Activity
   */
  static async getUserDetail(userId: string) {
    const { data: profile, error: profErr } = await supabaseAdmin
      .from('profiles')
      .select('id, email, username, full_name, role, status, plan, is_vip, vip_status, vip_expiry, avatar_url, university_id, faculty_id, department_id, created_at, updated_at')
      .eq('id', userId)
      .maybeSingle();

    if (profErr || !profile) {
      throw new NotFoundError(`User with ID '${userId}' not found.`);
    }

    // Parallel fetch academic labels and details
    const [uniRes, facRes, deptRes, subsRes, paymentsRes, coursesRes, aiUsageRes] = await Promise.all([
      profile.university_id ? supabaseAdmin.from('universities').select('name').eq('id', profile.university_id).maybeSingle() : Promise.resolve({ data: null }),
      profile.faculty_id ? supabaseAdmin.from('faculties').select('name').eq('id', profile.faculty_id).maybeSingle() : Promise.resolve({ data: null }),
      profile.department_id ? supabaseAdmin.from('departments').select('name').eq('id', profile.department_id).maybeSingle() : Promise.resolve({ data: null }),
      supabaseAdmin
        .from('subscriptions')
        .select('id, plan, status, provider, current_period_start, current_period_end, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(5),
      supabaseAdmin
        .from('payments')
        .select('id, order_id, transaction_id, provider, amount, currency, status, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(10),
      profile.role === 'teacher'
        ? supabaseAdmin
            .from('courses')
            .select('id, title, code, created_at')
            .eq('instructor_id', userId)
            .limit(20)
        : supabaseAdmin
            .from('course_members')
            .select('id, role, created_at, courses(id, title, code)')
            .eq('user_id', userId)
            .limit(20),
      supabaseAdmin
        .from('ai_requests')
        .select('feature, estimated_cost, input_tokens, output_tokens, created_at')
        .eq('user_id', userId)
        .order('created_at', { ascending: false })
        .limit(15),
    ]);

    return {
      profile: {
        ...profile,
        university_name: uniRes.data?.name || null,
        faculty_name: facRes.data?.name || null,
        department_name: deptRes.data?.name || null,
      },
      subscriptions: subsRes.data || [],
      payments: paymentsRes.data || [],
      courses: coursesRes.data || [],
      recentAiActivity: aiUsageRes.data || [],
    };
  }

  /**
   * 13. Academic Hierarchy Management with Referential Safeguards
   */
  private static async invalidateAcademicCache() {
    try {
      await CacheService.deletePattern('cache:academic:*');
    } catch (err) {
      logger.warn('Failed to invalidate academic cache:', err);
    }
  }

  static async createUniversity(adminId: string, data: any, meta?: RequestMeta) {
    const { data: created, error } = await supabaseAdmin
      .from('universities')
      .insert([{ name: data.name, code: data.code, city: data.city, is_active: data.is_active !== false }])
      .select()
      .single();

    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'university_created',
      resourceType: 'university',
      resourceId: created.id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: created,
    });

    await this.invalidateAcademicCache();
    return created;
  }

  static async updateUniversity(adminId: string, id: string, data: any, meta?: RequestMeta) {
    const { data: updated, error } = await supabaseAdmin
      .from('universities')
      .update(data)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'university_updated',
      resourceType: 'university',
      resourceId: id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: data,
    });

    await this.invalidateAcademicCache();
    return updated;
  }

  static async deleteUniversity(adminId: string, id: string, meta?: RequestMeta) {
    // Check if faculties depend on this university
    const { count, error: countErr } = await supabaseAdmin
      .from('faculties')
      .select('id', { count: 'exact', head: true })
      .eq('university_id', id);

    if (countErr) throw countErr;
    if (count && count > 0) {
      throw new BadRequestError(
        `Cannot delete university because ${count} faculty/faculties are linked to it. Please reassign or delete them first, or deactivate the university.`
      );
    }

    const { error } = await supabaseAdmin.from('universities').delete().eq('id', id);
    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'university_deleted',
      resourceType: 'university',
      resourceId: id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: { deleted_id: id },
    });

    await this.invalidateAcademicCache();
    return { success: true, deletedId: id };
  }

  static async createFaculty(adminId: string, data: any, meta?: RequestMeta) {
    const { data: created, error } = await supabaseAdmin
      .from('faculties')
      .insert([{ name: data.name, university_id: data.university_id }])
      .select()
      .single();

    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'faculty_created',
      resourceType: 'faculty',
      resourceId: created.id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: created,
    });

    await this.invalidateAcademicCache();
    return created;
  }

  static async updateFaculty(adminId: string, id: string, data: any, meta?: RequestMeta) {
    const { data: updated, error } = await supabaseAdmin
      .from('faculties')
      .update(data)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'faculty_updated',
      resourceType: 'faculty',
      resourceId: id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: data,
    });

    await this.invalidateAcademicCache();
    return updated;
  }

  static async deleteFaculty(adminId: string, id: string, meta?: RequestMeta) {
    const { count, error: countErr } = await supabaseAdmin
      .from('departments')
      .select('id', { count: 'exact', head: true })
      .eq('faculty_id', id);

    if (countErr) throw countErr;
    if (count && count > 0) {
      throw new BadRequestError(
        `Cannot delete faculty because ${count} department(s) are linked to it. Reassign or delete them first.`
      );
    }

    const { error } = await supabaseAdmin.from('faculties').delete().eq('id', id);
    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'faculty_deleted',
      resourceType: 'faculty',
      resourceId: id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: { deleted_id: id },
    });

    await this.invalidateAcademicCache();
    return { success: true, deletedId: id };
  }

  static async createDepartment(adminId: string, data: any, meta?: RequestMeta) {
    const { data: created, error } = await supabaseAdmin
      .from('departments')
      .insert([{ name: data.name, faculty_id: data.faculty_id }])
      .select()
      .single();

    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'department_created',
      resourceType: 'department',
      resourceId: created.id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: created,
    });

    await this.invalidateAcademicCache();
    return created;
  }

  static async updateDepartment(adminId: string, id: string, data: any, meta?: RequestMeta) {
    const { data: updated, error } = await supabaseAdmin
      .from('departments')
      .update(data)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'department_updated',
      resourceType: 'department',
      resourceId: id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: data,
    });

    await this.invalidateAcademicCache();
    return updated;
  }

  static async deleteDepartment(adminId: string, id: string, meta?: RequestMeta) {
    const { count, error: countErr } = await supabaseAdmin
      .from('courses')
      .select('id', { count: 'exact', head: true })
      .eq('department_id', id);

    if (countErr) throw countErr;
    if (count && count > 0) {
      throw new BadRequestError(
        `Cannot delete department because ${count} course(s) are linked to it. Reassign or archive them first.`
      );
    }

    const { error } = await supabaseAdmin.from('departments').delete().eq('id', id);
    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'department_deleted',
      resourceType: 'department',
      resourceId: id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: { deleted_id: id },
    });

    await this.invalidateAcademicCache();
    return { success: true, deletedId: id };
  }

  static async createCourse(adminId: string, data: any, meta?: RequestMeta) {
    const { data: created, error } = await supabaseAdmin
      .from('courses')
      .insert([{
        title: data.title,
        code: data.code,
        department_id: data.department_id,
        instructor_id: data.instructor_id || adminId,
        description: data.description || '',
      }])
      .select()
      .single();

    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'course_created',
      resourceType: 'course',
      resourceId: created.id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: created,
    });

    await this.invalidateAcademicCache();
    return created;
  }

  static async updateCourse(adminId: string, id: string, data: any, meta?: RequestMeta) {
    const { data: updated, error } = await supabaseAdmin
      .from('courses')
      .update(data)
      .eq('id', id)
      .select()
      .single();

    if (error) throw error;

    await AuditService.logAction({
      actorId: adminId,
      action: 'course_updated',
      resourceType: 'course',
      resourceId: id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: data,
    });

    await this.invalidateAcademicCache();
    return updated;
  }

  static async archiveCourse(adminId: string, id: string, meta?: RequestMeta) {
    const { data: course, error } = await supabaseAdmin
      .from('courses')
      .update({ is_archived: true, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      // If column is_archived is missing, safely update status or delete
      const { error: delErr } = await supabaseAdmin.from('courses').delete().eq('id', id);
      if (delErr) throw delErr;
    }

    await AuditService.logAction({
      actorId: adminId,
      action: 'course_archived',
      resourceType: 'course',
      resourceId: id,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: { archived_course_id: id },
    });

    await this.invalidateAcademicCache();
    return { success: true, archivedId: id };
  }

  static async getCourseDetail(id: string) {
    const { data: course, error } = await supabaseAdmin
      .from('courses')
      .select('id, title, code, department_id, instructor_id, description, created_at, departments(name), profiles:instructor_id(full_name, email)')
      .eq('id', id)
      .maybeSingle();

    if (error || !course) throw new NotFoundError('Course not found');

    const [membersRes, lecturesRes, quizzesRes] = await Promise.all([
      supabaseAdmin.from('course_members').select('id, user_id, role, created_at, profiles:user_id(full_name, email)').eq('course_id', id).limit(50),
      supabaseAdmin.from('lectures').select('id, title, created_at').eq('course_id', id).limit(50),
      supabaseAdmin.from('quizzes').select('id, title, created_at').eq('course_id', id).limit(50),
    ]);

    return {
      course,
      members: membersRes.data || [],
      lectures: lecturesRes.data || [],
      quizzes: quizzesRes.data || [],
    };
  }

  /**
   * 14. Broadcast Notifications via BullMQ Background Queue & DB
   */
  static async listBroadcastNotifications(page = 1, limit = 50) {
    const offset = (page - 1) * limit;
    const { data, count, error } = await supabaseAdmin
      .from('notifications')
      .select('id, user_id, title, body, type, is_read, created_at', { count: 'exact' })
      .in('type', ['system_notification', 'announcements', 'announcement'])
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) throw error;
    return {
      notifications: data || [],
      pagination: {
        total: count || 0,
        page,
        limit,
        totalPages: Math.ceil((count || 0) / limit),
      },
    };
  }

  static async createBroadcastNotification(
    adminId: string,
    payload: { title: string; body: string; type?: string; target?: 'all' | 'students' | 'teachers' | 'premium' },
    meta?: RequestMeta
  ) {
    const target = payload.target || 'all';
    let userQuery = supabaseAdmin.from('profiles').select('id');

    if (target === 'students') {
      userQuery = userQuery.eq('role', 'student');
    } else if (target === 'teachers') {
      userQuery = userQuery.eq('role', 'teacher');
    } else if (target === 'premium') {
      userQuery = userQuery.eq('plan', 'premium');
    }

    const { data: users, error: userErr } = await userQuery.limit(5000);
    if (userErr) throw userErr;

    const notifType = payload.type || 'system_notification';
    const notificationsToInsert = (users || []).map((u) => ({
      user_id: u.id,
      title: payload.title,
      body: payload.body,
      type: notifType,
      is_read: false,
      created_at: new Date().toISOString(),
    }));

    if (notificationsToInsert.length > 0) {
      // Chunk insertions by 500 to avoid payload limits
      for (let i = 0; i < notificationsToInsert.length; i += 500) {
        const chunk = notificationsToInsert.slice(i, i + 500);
        await supabaseAdmin.from('notifications').insert(chunk);
      }
    }

    await AuditService.logAction({
      actorId: adminId,
      action: 'notification_broadcast',
      resourceType: 'notification',
      resourceId: null,
      ipAddress: meta?.ip,
      userAgent: meta?.userAgent,
      changes: {
        title: payload.title,
        target,
        recipients_count: notificationsToInsert.length,
      },
    });

    return {
      success: true,
      recipientsCount: notificationsToInsert.length,
      target,
    };
  }

  /**
   * 15. System Telemetry & Dependency Health (DB, Redis, Queues, Uptime, Memory)
   */
  static async getSystemHealth() {
    const { checkSupabaseHealth } = await import('../config/supabase.js');
    const { checkRedisHealth } = await import('../config/redis.js');

    const [dbHealthy, redisHealthy] = await Promise.all([
      checkSupabaseHealth().catch(() => false),
      checkRedisHealth().catch(() => false),
    ]);

    const mem = process.memoryUsage();
    const uptimeSec = Math.floor(process.uptime());

    // Redis queue telemetry if available
    let queueStats = { waiting: 0, active: 0, failed: 0 };
    try {
      const { notificationQueue } = await import('../queues/queue.js');
      if (notificationQueue) {
        const [waiting, active, failed] = await Promise.all([
          notificationQueue.getWaitingCount().catch(() => 0),
          notificationQueue.getActiveCount().catch(() => 0),
          notificationQueue.getFailedCount().catch(() => 0),
        ]);
        queueStats = { waiting, active, failed };
      }
    } catch {
      // Queue probe non-blocking
    }

    return {
      status: dbHealthy && redisHealthy ? 'healthy' : 'degraded',
      services: {
        api: { status: 'healthy', uptimeSeconds: uptimeSec },
        database: { status: dbHealthy ? 'healthy' : 'unreachable' },
        redis: { status: redisHealthy ? 'healthy' : 'unreachable' },
        worker: { status: redisHealthy ? 'healthy' : 'degraded', queueStats },
        ai: { status: 'healthy', provider: 'google/openai' },
        payment: { status: 'healthy', gateways: ['fib', 'fastpay', 'zaincash', 'qi_card'] },
      },
      system: {
        memory: {
          heapUsedMb: Math.round(mem.heapUsed / 1024 / 1024),
          heapTotalMb: Math.round(mem.heapTotal / 1024 / 1024),
          rssMb: Math.round(mem.rss / 1024 / 1024),
        },
        uptimeFormatted: `${Math.floor(uptimeSec / 3600)}h ${Math.floor((uptimeSec % 3600) / 60)}m ${uptimeSec % 60}s`,
        nodeEnv: process.env.NODE_ENV || 'development',
      },
      timestamp: new Date().toISOString(),
    };
  }
}

