// ==============================================================================
// ZankoAI Audit Service: Immutable Security & Compliance Logging Engine
// ==============================================================================

import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';

export interface AuditLogEntry {
  actorId?: string | null;
  action: string;
  resourceType: string;
  resourceId?: string | null;
  ipAddress?: string | null;
  userAgent?: string | null;
  changes?: Record<string, any>;
}

export interface AuditLogFilters {
  page?: number;
  limit?: number;
  action?: string;
  resourceType?: string;
  actorId?: string;
  from?: string;
  to?: string;
}

export class AuditService {
  /**
   * Records an immutable audit log entry in public.audit_logs.
   * Failsafe: logs errors without breaking core business logic.
   */
  static async logAction(entry: AuditLogEntry): Promise<void> {
    try {
      const record = {
        actor_id: entry.actorId || null,
        action: entry.action,
        resource_type: entry.resourceType,
        resource_id: entry.resourceId || null,
        ip_address: entry.ipAddress || null,
        user_agent: entry.userAgent ? entry.userAgent.slice(0, 255) : null,
        changes: entry.changes || {},
        created_at: new Date().toISOString(),
      };

      const { error } = await supabaseAdmin.from('audit_logs').insert(record);

      if (error) {
        logger.error('Failed to write audit log:', { error, record });
      } else {
        logger.info(`[AUDIT] ${entry.action} on ${entry.resourceType}:${entry.resourceId || 'N/A'} by actor ${entry.actorId || 'SYSTEM'}`);
      }
    } catch (err) {
      logger.error('Unexpected error in AuditService.logAction:', err);
    }
  }

  /**
   * Retrieves paginated and filtered audit logs for admin review.
   */
  static async listAuditLogs(filters: AuditLogFilters = {}) {
    const page = Math.max(1, filters.page || 1);
    const limit = Math.min(100, Math.max(1, filters.limit || 50));
    const offset = (page - 1) * limit;

    let query = supabaseAdmin
      .from('audit_logs')
      .select('id, actor_id, action, resource_type, resource_id, ip_address, user_agent, changes, created_at, profiles:actor_id(id, full_name, email, role)', { count: 'exact' });

    if (filters.action) {
      query = query.eq('action', filters.action);
    }

    if (filters.resourceType) {
      query = query.eq('resource_type', filters.resourceType);
    }

    if (filters.actorId) {
      query = query.eq('actor_id', filters.actorId);
    }

    if (filters.from) {
      query = query.gte('created_at', filters.from);
    }

    if (filters.to) {
      query = query.lte('created_at', filters.to);
    }

    query = query.order('created_at', { ascending: false }).range(offset, offset + limit - 1);

    const { data, count, error } = await query;

    if (error) {
      logger.error('Error listing audit logs:', error);
      throw error;
    }

    const total = count || 0;
    return {
      logs: data || [],
      pagination: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
      },
    };
  }
}
