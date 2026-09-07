import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';
import { QueueName, JobState, JobMetadata, DeadLetterJob } from '../types/worker.types.js';

export class JobMetadataService {
  private static readonly META_PREFIX = 'zanko:meta:';
  private static readonly DEAD_LETTER_PREFIX = 'zanko:dead_letter:';
  private static readonly METADATA_TTL_SECONDS = 7 * 86400; // 7 days retention

  private static buildMetaKey(queueName: QueueName, jobId: string): string {
    return this.META_PREFIX + queueName + ':' + jobId;
  }

  private static buildDeadLetterKey(queueName: QueueName): string {
    return this.DEAD_LETTER_PREFIX + queueName;
  }

  /**
   * Records a new job in queued state.
   */
  static async recordQueued(params: {
    jobId: string;
    queueName: QueueName;
    jobName: string;
    maxAttempts: number;
    idempotencyKey?: string;
    data?: any;
  }): Promise<JobMetadata> {
    const meta: JobMetadata = {
      job_id: params.jobId,
      queue_name: params.queueName,
      job_name: params.jobName,
      state: 'queued',
      created_at: new Date().toISOString(),
      attempts: 0,
      max_attempts: params.maxAttempts,
      idempotency_key: params.idempotencyKey,
      data: params.data,
    };

    try {
      const key = this.buildMetaKey(params.queueName, params.jobId);
      await redis.set(key, JSON.stringify(meta), 'EX', this.METADATA_TTL_SECONDS);
    } catch (error) {
      logger.error('JobMetadataService recordQueued error:', error);
    }

    return meta;
  }

  /**
   * Records that a job has transitioned to processing state.
   */
  static async recordStarted(queueName: QueueName, jobId: string): Promise<JobMetadata | null> {
    try {
      const key = this.buildMetaKey(queueName, jobId);
      const raw = await redis.get(key);
      const now = new Date().toISOString();

      let meta: JobMetadata;
      if (raw) {
        meta = JSON.parse(raw);
        meta.state = 'processing';
        meta.started_at = now;
        meta.attempts = (meta.attempts || 0) + 1;
      } else {
        meta = {
          job_id: jobId,
          queue_name: queueName,
          job_name: 'unknown',
          state: 'processing',
          created_at: now,
          started_at: now,
          attempts: 1,
          max_attempts: 3,
        };
      }

      await redis.set(key, JSON.stringify(meta), 'EX', this.METADATA_TTL_SECONDS);
      return meta;
    } catch (error) {
      logger.error('JobMetadataService recordStarted error:', error);
      return null;
    }
  }

  /**
   * Records that a job has completed successfully.
   */
  static async recordCompleted(queueName: QueueName, jobId: string, result?: any): Promise<JobMetadata | null> {
    try {
      const key = this.buildMetaKey(queueName, jobId);
      const raw = await redis.get(key);
      const now = new Date().toISOString();

      if (!raw) {
        return null;
      }

      const meta: JobMetadata = JSON.parse(raw);
      meta.state = 'completed';
      meta.completed_at = now;
      meta.result = result;

      if (meta.started_at) {
        const start = new Date(meta.started_at).getTime();
        const end = new Date(now).getTime();
        meta.execution_duration_ms = Math.max(0, end - start);
      }

      await redis.set(key, JSON.stringify(meta), 'EX', this.METADATA_TTL_SECONDS);
      return meta;
    } catch (error) {
      logger.error('JobMetadataService recordCompleted error:', error);
      return null;
    }
  }

  /**
   * Records that a job has failed.
   * If willRetry is false, moves job to dead-letter storage.
   */
  static async recordFailed(
    queueName: QueueName,
    jobId: string,
    error: Error | string,
    willRetry: boolean
  ): Promise<JobMetadata | null> {
    try {
      const key = this.buildMetaKey(queueName, jobId);
      const raw = await redis.get(key);
      const now = new Date().toISOString();
      const errorMessage = typeof error === 'string' ? error : error.message;
      const errorStack = typeof error === 'string' ? undefined : error.stack;

      let meta: JobMetadata;
      if (raw) {
        meta = JSON.parse(raw);
        meta.state = willRetry ? 'queued' : 'failed';
        meta.failed_at = now;
        meta.error_message = errorMessage;
        meta.error_stack = errorStack;
      } else {
        meta = {
          job_id: jobId,
          queue_name: queueName,
          job_name: 'unknown',
          state: willRetry ? 'queued' : 'failed',
          created_at: now,
          failed_at: now,
          attempts: 1,
          max_attempts: 3,
          error_message: errorMessage,
          error_stack: errorStack,
        };
      }

      await redis.set(key, JSON.stringify(meta), 'EX', this.METADATA_TTL_SECONDS);

      // Dead-letter queue tracking if attempts are exhausted
      if (!willRetry) {
        const dlqKey = this.buildDeadLetterKey(queueName);
        const deadLetterEntry: DeadLetterJob = {
          job_id: jobId,
          queue_name: queueName,
          job_name: meta.job_name,
          attempts: meta.attempts,
          max_attempts: meta.max_attempts,
          failed_at: now,
          error_message: errorMessage,
          data: meta.data,
          idempotency_key: meta.idempotency_key,
        };
        await redis.lpush(dlqKey, JSON.stringify(deadLetterEntry));
        // Keep dead letter list capped at 1000 items per queue
        await redis.ltrim(dlqKey, 0, 999);
      }

      return meta;
    } catch (err) {
      logger.error('JobMetadataService recordFailed error:', err);
      return null;
    }
  }

  /**
   * Retrieves full job metadata.
   */
  static async getJobMetadata(queueName: QueueName, jobId: string): Promise<JobMetadata | null> {
    try {
      const key = this.buildMetaKey(queueName, jobId);
      const raw = await redis.get(key);
      return raw ? JSON.parse(raw) : null;
    } catch (error) {
      logger.error('JobMetadataService getJobMetadata error:', error);
      return null;
    }
  }

  /**
   * Retrieves dead-letter jobs for inspection or admin monitoring.
   */
  static async getDeadLetterJobs(queueName?: QueueName, limit = 50): Promise<DeadLetterJob[]> {
    try {
      const queues: QueueName[] = queueName ? [queueName] : ['pdf', 'ocr', 'audio', 'ai', 'notifications'];
      const results: DeadLetterJob[] = [];

      for (const q of queues) {
        const dlqKey = this.buildDeadLetterKey(q);
        const entries = await redis.lrange(dlqKey, 0, limit - 1);
        for (const raw of entries) {
          try {
            results.push(JSON.parse(raw));
          } catch {
            // Ignore malformed entries
          }
        }
      }

      return results.slice(0, limit);
    } catch (error) {
      logger.error('JobMetadataService getDeadLetterJobs error:', error);
      return [];
    }
  }

  /**
   * Returns total count of dead-letter jobs across all queues.
   */
  static async getDeadLetterCount(): Promise<number> {
    try {
      const queues: QueueName[] = ['pdf', 'ocr', 'audio', 'ai', 'notifications'];
      let total = 0;
      for (const q of queues) {
        const dlqKey = this.buildDeadLetterKey(q);
        total += await redis.llen(dlqKey);
      }
      return total;
    } catch (error) {
      logger.error('JobMetadataService getDeadLetterCount error:', error);
      return 0;
    }
  }
}
