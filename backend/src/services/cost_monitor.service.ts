import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';

export interface CostThreshold {
  id: string;
  metric_name: string;
  threshold_value: number;
  severity: 'info' | 'warning' | 'critical';
  is_triggered: boolean;
  last_triggered_at: string | null;
  description: string | null;
}

export interface SystemCostAlert {
  id: string;
  metric_name: string;
  current_value: number;
  threshold_value: number;
  severity: string;
  message: string;
  acknowledged: boolean;
  acknowledged_by?: string;
  acknowledged_at?: string;
  created_at: string;
}

export class CostMonitorService {
  /**
   * Run cost & usage evaluation RPC against all active thresholds.
   * Creates alerts in system_cost_alerts without auto-upgrading plans.
   */
  static async evaluateThresholds(): Promise<any[]> {
    try {
      const { data, error } = await supabaseAdmin.rpc('check_cost_and_usage_thresholds');
      if (error) {
        logger.error(`[CostMonitor] Failed to evaluate thresholds: ${error.message}`);
        return [];
      }
      return data || [];
    } catch (err: any) {
      logger.error(`[CostMonitor] Threshold evaluation error: ${err.message}`);
      return [];
    }
  }

  /**
   * List all configured cost thresholds
   */
  static async listThresholds(): Promise<CostThreshold[]> {
    const { data, error } = await supabaseAdmin
      .from('supabase_cost_thresholds')
      .select('*')
      .order('metric_name', { ascending: true })
      .order('threshold_value', { ascending: true });

    if (error) {
      logger.error(`[CostMonitor] Failed to list thresholds: ${error.message}`);
      throw error;
    }

    return (data || []) as CostThreshold[];
  }

  /**
   * Update an existing cost threshold (e.g. adjust 50k MAU to 60k MAU)
   */
  static async updateThreshold(
    id: string,
    updates: { threshold_value?: number; severity?: 'info' | 'warning' | 'critical'; description?: string }
  ): Promise<CostThreshold> {
    const { data, error } = await supabaseAdmin
      .from('supabase_cost_thresholds')
      .update({
        ...updates,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select('*')
      .single();

    if (error) {
      logger.error(`[CostMonitor] Failed to update threshold ${id}: ${error.message}`);
      throw error;
    }

    return data as CostThreshold;
  }

  /**
   * List active/unacknowledged system cost alerts
   */
  static async listAlerts(unacknowledgedOnly = true): Promise<SystemCostAlert[]> {
    let query = supabaseAdmin
      .from('system_cost_alerts')
      .select('*')
      .order('created_at', { ascending: false });

    if (unacknowledgedOnly) {
      query = query.eq('acknowledged', false);
    }

    const { data, error } = await query;
    if (error) {
      logger.error(`[CostMonitor] Failed to fetch alerts: ${error.message}`);
      throw error;
    }

    return (data || []) as SystemCostAlert[];
  }

  /**
   * Acknowledge an alert
   */
  static async acknowledgeAlert(alertId: string, adminUserId?: string): Promise<boolean> {
    const { error } = await supabaseAdmin
      .from('system_cost_alerts')
      .update({
        acknowledged: true,
        acknowledged_by: adminUserId || null,
        acknowledged_at: new Date().toISOString(),
      })
      .eq('id', alertId);

    if (error) {
      logger.error(`[CostMonitor] Failed to acknowledge alert ${alertId}: ${error.message}`);
      return false;
    }

    return true;
  }
}
