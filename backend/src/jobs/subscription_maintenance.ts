// ==============================================================================
// ZankoAI Background Job: Subscription Maintenance Processor
// ==============================================================================

import { logger } from '../config/logger.js';
import { SubscriptionService } from '../services/subscription.service.js';
import { SubscriptionMaintenanceResult } from '../types/subscription.types.js';

export interface SubscriptionMaintenanceJobData {
  triggeredBy?: string;
  timestamp?: string;
}

/**
 * Executes the scheduled subscription maintenance routine:
 * - Detects expired subscriptions and revokes VIP privileges
 * - Transitions active subscriptions past current_period_end into grace periods
 * - Dispatches renewal reminders 3 days and 1 day prior to expiration
 * - Reconciles and cleans up stale pending checkout sessions
 */
export async function processSubscriptionMaintenanceJob(
  data?: SubscriptionMaintenanceJobData
): Promise<SubscriptionMaintenanceResult> {
  logger.info('[SubscriptionMaintenanceJob] Starting scheduled maintenance job...');
  const startTime = Date.now();

  try {
    const result = await SubscriptionService.runMaintenance();
    const duration = Date.now() - startTime;

    logger.info(
      '[SubscriptionMaintenanceJob] Completed in ' + duration + 'ms: ' +
      result.expiredCount + ' expired, ' +
      result.pastDueCount + ' past due, ' +
      result.remindersSentCount + ' reminders sent, ' +
      result.stalePendingProcessed + ' stale checkouts cleaned.'
    );

    return result;
  } catch (error: any) {
    logger.error('[SubscriptionMaintenanceJob] Error during subscription maintenance: ' + error.message, error);
    throw error;
  }
}
