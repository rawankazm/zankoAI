import { Worker, Job } from 'bullmq';
import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';
import { env } from '../config/env.js';

logger.info(`👷 Starting ZankoAI Background Worker in ${env.NODE_ENV} mode...`);

// 1. File Processing Worker
export const fileWorker = new Worker(
  'file-processing',
  async (job: Job) => {
    logger.info(`[Worker:file-processing] Processing job ${job.id} (${job.name})`, { data: job.data });

    // Job handler placeholder
    if (job.name === 'process-pdf') {
      const { fileUrl, userId } = job.data;
      logger.info(`Processing PDF document for user ${userId} from ${fileUrl}`);
      // Extraction logic placeholder for AI indexing
      await new Promise((res) => setTimeout(res, 500));
      return { processed: true, pages: 1 };
    }

    return { status: 'completed' };
  },
  { connection: redis, concurrency: 4 }
);

fileWorker.on('completed', (job: Job) => {
  logger.info(`[Worker:file-processing] Job ${job.id} completed successfully`);
});

fileWorker.on('failed', (job: Job | undefined, err: Error) => {
  logger.error(`[Worker:file-processing] Job ${job?.id} failed:`, err);
});

// 2. Notifications Worker
export const notificationWorker = new Worker(
  'notifications',
  async (job: Job) => {
    logger.info(`[Worker:notifications] Dispatching notification job ${job.id}`, { data: job.data });
    await new Promise((res) => setTimeout(res, 200));
    return { delivered: true };
  },
  { connection: redis, concurrency: 8 }
);

notificationWorker.on('completed', (job: Job) => {
  logger.info(`[Worker:notifications] Notification job ${job.id} sent`);
});

notificationWorker.on('failed', (job: Job | undefined, err: Error) => {
  logger.error(`[Worker:notifications] Notification job ${job?.id} failed:`, err);
});

// Graceful Worker Shutdown
const shutdownWorkers = async () => {
  logger.info('🛑 Shutting down queue workers gracefully...');
  await Promise.all([fileWorker.close(), notificationWorker.close()]);
  await redis.quit();
  logger.info('Queue workers closed. Exiting process.');
  process.exit(0);
};

process.on('SIGTERM', shutdownWorkers);
process.on('SIGINT', shutdownWorkers);
