// ==============================================================================
// ZankoAI Admin Service: Controlled Operations, Directory, Usage & Telemetry Engine
// ==============================================================================

import { supabaseAdmin } from '../config/supabase.js';
import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';
import { AuditService } from './audit.service.js';
import { UserRole, UserStatus } from '../types/user.types.js';
import { NotFoundError, ForbiddenError, BadRequestError } from '../utils/apiError.js';

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
}
