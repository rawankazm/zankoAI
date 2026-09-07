import { Queue, JobsOptions } from 'bullmq';
import { redisConnectionOptions } from '../config/redis.js';
import { logger } from '../config/logger.js';
import { QueueName, UnifiedJobOptions, JobMetadata } from '../types/worker.types.js';
import { IdempotencyService } from '../services/idempotency.service.js';
import { JobMetadataService } from '../services/job_metadata.service.js';

// Default exponential backoff configuration:
// Attempt 1: immediate
// Attempt 2: 2,000 ms (2s)
// Attempt 3: 4,000 ms (4s)
// Attempt 4: 8,000 ms (8s)
// Attempt 5: 16,000 ms (16s)
const DEFAULT_EXPONENTIAL_BACKOFF = {
  type: 'exponential',
  delay: 2000,
};

// ── 1. PDF Queue ─────────────────────────────────────────────────────────────
export const pdfQueue = new Queue('pdf', {
  connection: redisConnectionOptions,
  defaultJobOptions: {
    attempts: 3,
    backoff: DEFAULT_EXPONENTIAL_BACKOFF,
    removeOnComplete: { count: 500, age: 86400 },
    removeOnFail: { count: 1000, age: 604800 },
  },
});

// ── 2. OCR Queue ─────────────────────────────────────────────────────────────
export const ocrQueue = new Queue('ocr', {
  connection: redisConnectionOptions,
  defaultJobOptions: {
    attempts: 3,
    backoff: DEFAULT_EXPONENTIAL_BACKOFF,
    removeOnComplete: { count: 500, age: 86400 },
    removeOnFail: { count: 1000, age: 604800 },
  },
});

// ── 3. Audio Queue ───────────────────────────────────────────────────────────
export const audioQueue = new Queue('audio', {
  connection: redisConnectionOptions,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 3000,
    },
    removeOnComplete: { count: 500, age: 86400 },
    removeOnFail: { count: 1000, age: 604800 },
  },
});

// ── 4. AI Generation Queue ───────────────────────────────────────────────────
export const aiQueue = new Queue('ai', {
  connection: redisConnectionOptions,
  defaultJobOptions: {
    attempts: 3,
    backoff: DEFAULT_EXPONENTIAL_BACKOFF,
    removeOnComplete: { count: 500, age: 86400 },
    removeOnFail: { count: 1000, age: 604800 },
  },
});

// ── 5. Notifications Queue ───────────────────────────────────────────────────
export const notificationQueue = new Queue('notifications', {
  connection: redisConnectionOptions,
  defaultJobOptions: {
    attempts: 5,
    backoff: {
      type: 'exponential',
      delay: 1000,
    },
    removeOnComplete: { count: 1000, age: 86400 },
    removeOnFail: { count: 1000, age: 604800 },
  },
});

// Registry of all 5 queues
export const allQueues: Record<QueueName, Queue> = {
  pdf: pdfQueue,
  ocr: ocrQueue,
  audio: audioQueue,
  ai: aiQueue,
  notifications: notificationQueue,
};

/**
 * Adds a background job with idempotency, duplicate prevention, retry, exponential backoff,
 * timeout configuration, and lifecycle metadata tracking.
 */
export async function addUnifiedJob<T = any>(
  queueName: QueueName,
  jobName: string,
  data: T,
  options: UnifiedJobOptions = {}
): Promise<{ jobId: string; deduplicated: boolean; metadata: JobMetadata; result?: any }> {
  const queue = allQueues[queueName];
  if (!queue) {
    throw new Error('Unknown queue name: ' + queueName);
  }

  // Duplicate prevention and idempotency check
  if (options.idempotencyKey) {
    const existing = await IdempotencyService.getCompletedResult(options.idempotencyKey);
    if (existing.isCompleted) {
      logger.info(
        'Idempotent job already completed. Returning cached result for key: ' + options.idempotencyKey
      );
      return {
        jobId: options.idempotencyKey,
        deduplicated: true,
        metadata: {
          job_id: options.idempotencyKey,
          queue_name: queueName,
          job_name: jobName,
          state: 'completed',
          created_at: new Date().toISOString(),
          completed_at: new Date().toISOString(),
          attempts: 1,
          max_attempts: options.attempts || 3,
          idempotency_key: options.idempotencyKey,
          result: existing.result,
        },
        result: existing.result,
      };
    }
  }

  const jobOpts: JobsOptions = {
    attempts: options.attempts || 3,
    backoff: options.backoffDelayMs
      ? { type: 'exponential', delay: options.backoffDelayMs }
      : DEFAULT_EXPONENTIAL_BACKOFF,
    jobId: options.idempotencyKey || undefined, // BullMQ deduplication key
    delay: options.delay || undefined,
    priority: options.priority || undefined,
  };

  const job = await queue.add(jobName, data, jobOpts);
  const finalJobId = job.id || 'job_' + Date.now();

  const metadata = await JobMetadataService.recordQueued({
    jobId: finalJobId,
    queueName,
    jobName,
    maxAttempts: jobOpts.attempts || 3,
    idempotencyKey: options.idempotencyKey,
    data,
  });

  logger.info('Queued background job [' + queueName + '] ' + jobName + ' (ID: ' + finalJobId + ')');

  return {
    jobId: finalJobId,
    deduplicated: false,
    metadata,
  };
}

// ── Legacy Aliases for Backward Compatibility ────────────────────────────────
export const pdfAiQueue = pdfQueue;
export const ocrAiQueue = ocrQueue;
export const audioTranscriptionQueue = audioQueue;
export const fileProcessingQueue = pdfQueue;
