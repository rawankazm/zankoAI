import { Worker, Job } from 'bullmq';
import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';
import { env } from '../config/env.js';
import { processPdfAiJob } from '../jobs/pdf_processor.js';
import { PdfAiJobData } from '../types/pdf.types.js';

logger.info(`👷 Starting ZankoAI Background Worker in ${env.NODE_ENV} mode...`);

// ── 1. File Processing Worker (legacy: lecture slides, etc.) ──────────────────
export const fileWorker = new Worker(
  'file-processing',
  async (job: Job) => {
    logger.info(`[Worker:file-processing] Processing job ${job.id} (${job.name})`, { data: job.data });

    if (job.name === 'process-pdf') {
      const { fileUrl, userId } = job.data;
      logger.info(`Processing PDF document for user ${userId} from ${fileUrl}`);
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

// ── 2. Notifications Worker ────────────────────────────────────────────────────
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

// ── 3. PDF AI Processing Worker ────────────────────────────────────────────────
export const pdfAiWorker = new Worker(
  'pdf-ai-processing',
  async (job: Job<PdfAiJobData>) => {
    logger.info(
      `[Worker:pdf-ai] Processing job ${job.id} for user ${job.data.userId} (${job.data.originalFilename})`
    );
    await processPdfAiJob(job.data);
    return { processed: true };
  },
  {
    connection: redis,
    concurrency: 2, // CPU-bound PDF parsing — keep concurrency low
    limiter: {
      max: 10,
      duration: 60_000, // max 10 PDF jobs per minute across all workers
    },
  }
);

pdfAiWorker.on('completed', (job: Job) => {
  logger.info(`[Worker:pdf-ai] Job ${job.id} completed successfully`);
});

pdfAiWorker.on('failed', (job: Job | undefined, err: Error) => {
  const attempt = job?.attemptsMade ?? 0;
  const maxAttempts = job?.opts?.attempts ?? 3;
  logger.error(
    `[Worker:pdf-ai] Job ${job?.id} failed (attempt ${attempt}/${maxAttempts}): ${err.message}`
  );
});

pdfAiWorker.on('stalled', (jobId: string) => {
  logger.warn(`[Worker:pdf-ai] Job ${jobId} stalled — will be re-queued automatically`);
});

// ── Graceful Shutdown ─────────────────────────────────────────────────────────
const shutdownWorkers = async () => {
  logger.info('🛑 Shutting down queue workers gracefully...');
  await Promise.all([
    fileWorker.close(),
    notificationWorker.close(),
    pdfAiWorker.close(),
  ]);
  await redis.quit();
  logger.info('Queue workers closed. Exiting process.');
  process.exit(0);
};

process.on('SIGTERM', shutdownWorkers);
process.on('SIGINT', shutdownWorkers);
