import { allQueues } from '../queues/unified_queues.js';
import { checkRedisHealth } from '../config/redis.js';
import { JobMetadataService } from './job_metadata.service.js';
import { QueueName, QueueHealthMetrics, WorkerHealthReport } from '../types/worker.types.js';
import { logger } from '../config/logger.js';

export class WorkerHealthService {
  private static readonly QUEUE_NAMES: QueueName[] = ['pdf', 'ocr', 'audio', 'ai', 'notifications'];

  /**
   * Generates a complete health report for all background workers and queues.
   */
  static async getHealthReport(): Promise<WorkerHealthReport> {
    const redisConnected = await checkRedisHealth();

    const queuesReport: Record<QueueName, QueueHealthMetrics> = {
      pdf: { waiting: 0, active: 0, completed: 0, failed: 0, delayed: 0, paused: false },
      ocr: { waiting: 0, active: 0, completed: 0, failed: 0, delayed: 0, paused: false },
      audio: { waiting: 0, active: 0, completed: 0, failed: 0, delayed: 0, paused: false },
      ai: { waiting: 0, active: 0, completed: 0, failed: 0, delayed: 0, paused: false },
      notifications: { waiting: 0, active: 0, completed: 0, failed: 0, delayed: 0, paused: false },
    };

    let deadLetterCount = 0;
    let anyQueueError = false;

    if (redisConnected) {
      try {
        deadLetterCount = await JobMetadataService.getDeadLetterCount();

        await Promise.all(
          this.QUEUE_NAMES.map(async (name) => {
            const queue = allQueues[name];
            if (!queue) return;

            try {
              const counts = await queue.getJobCounts('waiting', 'active', 'completed', 'failed', 'delayed');
              const isPaused = await queue.isPaused();

              queuesReport[name] = {
                waiting: counts.waiting || 0,
                active: counts.active || 0,
                completed: counts.completed || 0,
                failed: counts.failed || 0,
                delayed: counts.delayed || 0,
                paused: isPaused,
              };
            } catch (err) {
              logger.warn('Failed to query job counts for queue ' + name + ':', err);
              anyQueueError = true;
            }
          })
        );
      } catch (err) {
        logger.error('WorkerHealthService error querying queues:', err);
        anyQueueError = true;
      }
    }

    let status: 'healthy' | 'degraded' | 'down' = 'healthy';
    if (!redisConnected) {
      status = 'down';
    } else if (anyQueueError || deadLetterCount > 50) {
      status = 'degraded';
    }

    return {
      status,
      redis_connected: redisConnected,
      uptime_seconds: Math.floor(process.uptime()),
      active_workers: 5, // All 5 queues have dedicated active worker listeners
      queues: queuesReport,
      dead_letter_count: deadLetterCount,
      timestamp: new Date().toISOString(),
    };
  }
}
