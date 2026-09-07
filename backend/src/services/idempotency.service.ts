import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';

export interface IdempotencyRecord {
  state: 'processing' | 'completed' | 'failed';
  result?: any;
  error?: string;
  updated_at: string;
}

export class IdempotencyService {
  private static readonly KEY_PREFIX = 'zanko:idempotency:';
  private static readonly DEFAULT_LOCK_TTL_SECONDS = 300; // 5 minutes processing lock
  private static readonly COMPLETED_TTL_SECONDS = 86400; // 24 hours retention for completed jobs

  /**
   * Builds the Redis key for an idempotency key.
   */
  private static buildKey(idempotencyKey: string): string {
    return this.KEY_PREFIX + idempotencyKey;
  }

  /**
   * Attempts to acquire an atomic lock for an idempotent operation.
   * Returns true if lock was acquired (first time execution).
   * Returns false if already processing or completed.
   */
  static async acquireLock(idempotencyKey: string, ttlSeconds = this.DEFAULT_LOCK_TTL_SECONDS): Promise<boolean> {
    try {
      const key = this.buildKey(idempotencyKey);
      const initialPayload: IdempotencyRecord = {
        state: 'processing',
        updated_at: new Date().toISOString(),
      };

      // SET key val EX ttl NX ensures atomic mutual exclusion
      const result = await redis.set(key, JSON.stringify(initialPayload), 'EX', ttlSeconds, 'NX');
      return result === 'OK';
    } catch (error) {
      logger.error('IdempotencyService acquireLock error:', error);
      // Fail closed to prevent duplicate processing on Redis error
      return false;
    }
  }

  /**
   * Checks if an idempotent job has already completed.
   * If completed, returns the stored result.
   */
  static async getCompletedResult(idempotencyKey: string): Promise<{ isCompleted: boolean; result?: any }> {
    try {
      const key = this.buildKey(idempotencyKey);
      const raw = await redis.get(key);
      if (!raw) {
        return { isCompleted: false };
      }

      const parsed: IdempotencyRecord = JSON.parse(raw);
      if (parsed.state === 'completed') {
        return { isCompleted: true, result: parsed.result };
      }

      return { isCompleted: false };
    } catch (error) {
      logger.error('IdempotencyService getCompletedResult error:', error);
      return { isCompleted: false };
    }
  }

  /**
   * Marks an idempotent job as completed and stores the result for fast deduplication.
   */
  static async markCompleted(idempotencyKey: string, result: any, ttlSeconds = this.COMPLETED_TTL_SECONDS): Promise<void> {
    try {
      const key = this.buildKey(idempotencyKey);
      const payload: IdempotencyRecord = {
        state: 'completed',
        result,
        updated_at: new Date().toISOString(),
      };
      await redis.set(key, JSON.stringify(payload), 'EX', ttlSeconds);
    } catch (error) {
      logger.error('IdempotencyService markCompleted error:', error);
    }
  }

  /**
   * Releases an idempotency lock so that a retry attempt can acquire it again.
   */
  static async releaseLock(idempotencyKey: string): Promise<void> {
    try {
      const key = this.buildKey(idempotencyKey);
      await redis.del(key);
    } catch (error) {
      logger.error('IdempotencyService releaseLock error:', error);
    }
  }

  /**
   * Marks an idempotent job as failed after exhausting all retry attempts.
   */
  static async markFailed(idempotencyKey: string, errorMessage: string, ttlSeconds = 3600): Promise<void> {
    try {
      const key = this.buildKey(idempotencyKey);
      const payload: IdempotencyRecord = {
        state: 'failed',
        error: errorMessage,
        updated_at: new Date().toISOString(),
      };
      await redis.set(key, JSON.stringify(payload), 'EX', ttlSeconds);
    } catch (error) {
      logger.error('IdempotencyService markFailed error:', error);
    }
  }
}
