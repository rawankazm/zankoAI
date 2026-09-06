import { supabaseAdmin } from '../config/supabase.js';
import { CostMonitorService } from '../services/cost_monitor.service.js';
import { logger } from '../config/logger.js';

export class MauAggregationJob {
  /**
   * Run nightly aggregation routine:
   * 1. Aggregate yesterday's and today's DAU
   * 2. Aggregate current month's MAU
   * 3. Evaluate cost thresholds and alert triggers
   * 4. Prune daily activity records older than 90 days
   */
  static async executeNightlyJob(): Promise<{
    dauSuccess: boolean;
    mauSuccess: boolean;
    alertsTriggered: number;
    prunedRecords: number;
  }> {
    logger.info('[MauAggregationJob] Starting scheduled MAU & DAU aggregation...');

    let dauSuccess = false;
    let mauSuccess = false;
    let alertsTriggered = 0;
    let prunedRecords = 0;

    // 1. Aggregate DAU
    try {
      const today = new Date().toISOString().substring(0, 10);
      const { error: dauErr } = await supabaseAdmin.rpc('aggregate_daily_active_users', {
        p_date: today,
      });

      if (dauErr) {
        logger.error(`[MauAggregationJob] DAU aggregation failed: ${dauErr.message}`);
      } else {
        dauSuccess = true;
        logger.info(`[MauAggregationJob] DAU aggregation completed for ${today}`);
      }
    } catch (e: any) {
      logger.error(`[MauAggregationJob] DAU exception: ${e.message}`);
    }

    // 2. Aggregate MAU (Deduplicated across the current month)
    try {
      const currentMonthStart = `${new Date().toISOString().substring(0, 7)}-01`;
      const { error: mauErr } = await supabaseAdmin.rpc('aggregate_monthly_active_users', {
        p_month: currentMonthStart,
      });

      if (mauErr) {
        logger.error(`[MauAggregationJob] MAU aggregation failed: ${mauErr.message}`);
      } else {
        mauSuccess = true;
        logger.info(`[MauAggregationJob] MAU aggregation completed for ${currentMonthStart}`);
      }
    } catch (e: any) {
      logger.error(`[MauAggregationJob] MAU exception: ${e.message}`);
    }

    // 3. Evaluate Cost & Usage Thresholds (50k, 75k, 90k, 100k MAU, DB size, etc.)
    try {
      const alerts = await CostMonitorService.evaluateThresholds();
      alertsTriggered = alerts.length;
      if (alertsTriggered > 0) {
        logger.warn(`[MauAggregationJob] ${alertsTriggered} cost/MAU threshold alerts triggered!`, { alerts });
      }
    } catch (e: any) {
      logger.error(`[MauAggregationJob] Threshold evaluation exception: ${e.message}`);
    }

    // 4. Prune raw daily records older than 90 days to prevent unbounded database growth
    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - 90);
      const cutoffStr = cutoffDate.toISOString().substring(0, 10);

      const { data: deleteRes, error: deleteErr } = await supabaseAdmin
        .from('user_daily_activity')
        .delete()
        .lt('activity_date', cutoffStr)
        .select('user_id');

      if (!deleteErr && deleteRes) {
        prunedRecords = deleteRes.length;
        if (prunedRecords > 0) {
          logger.info(`[MauAggregationJob] Pruned ${prunedRecords} historical daily activity rows older than ${cutoffStr}`);
        }
      }
    } catch (e: any) {
      logger.warn(`[MauAggregationJob] Pruning exception: ${e.message}`);
    }

    logger.info('[MauAggregationJob] Nightly MAU aggregation routine finished.', {
      dauSuccess,
      mauSuccess,
      alertsTriggered,
      prunedRecords,
    });

    return { dauSuccess, mauSuccess, alertsTriggered, prunedRecords };
  }
}
