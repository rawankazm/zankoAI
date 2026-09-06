import { redis } from '../config/redis.js';
import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';

/**
 * High-performance, zero-latency Activity Tracker
 * Uses Redis O(1) deduplication cache to eliminate redundant database writes.
 * At most 1 write to PostgreSQL per user per UTC day.
 */
export class ActivityTrackerService {
  /**
   * Tracks active presence of an authenticated user.
   * Runs asynchronously without blocking the client HTTP request.
   */
  static trackUser(userId: string, role: string = 'student', plan: string = 'free'): void {
    if (!userId) return;

    // Fire-and-forget execution
    setImmediate(async () => {
      try {
        const todayUtc = new Date().toISOString().substring(0, 10);
        const redisKey = `mau:active:${todayUtc}:${userId}`;

        // 1. Try Redis Atomic Deduplication (SET ... NX)
        let isFirstActivityToday = true;
        try {
          // SET key value EX 172800 NX (expires in 48 hours, only sets if Not eXists)
          const setResult = await redis.set(redisKey, '1', 'EX', 172800, 'NX');
          isFirstActivityToday = setResult === 'OK';
        } catch (redisErr: any) {
          logger.warn(`[ActivityTracker] Redis check failed, falling back to DB upsert: ${redisErr.message}`);
          isFirstActivityToday = true;
        }

        // 2. If already seen today in Redis, skip PostgreSQL write completely
        if (!isFirstActivityToday) {
          return;
        }

        // 3. First time today: record in PostgreSQL user_daily_activity via RPC
        const { error } = await supabaseAdmin.rpc('record_user_activity', {
          p_user_id: userId,
          p_role: role,
          p_plan: plan,
        });

        if (error) {
          logger.error(`[ActivityTracker] Failed to record daily activity in DB: ${error.message}`, {
            userId,
            todayUtc,
          });
        }
      } catch (err: any) {
        logger.error(`[ActivityTracker] Unexpected tracking error: ${err.message}`);
      }
    });
  }
}
