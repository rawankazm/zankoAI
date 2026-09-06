import { Worker } from 'bullmq';
import { redis } from './config/redis.js';
import { logger } from './config/logger.js';
import { processPdfJob } from './jobs/pdf_processor.js';

logger.info('🚀 Starting ZankoAI Background Worker Process...');

// 1. PDF Processor Worker
const pdfWorker = new Worker(
  'pdf-processing',
  async (job) => {
    logger.info(`Processing Job [${job.name}] ID: ${job.id}`);
    if (job.name === 'EXTRACT_PDF_TEXT') {
      await processPdfJob(job.data);
    }
  },
  { connection: redis, concurrency: 3 }
);

pdfWorker.on('completed', (job) => {
  logger.info(`Job [${job.id}] completed successfully.`);
});

pdfWorker.on('failed', (job, err) => {
  logger.error(`Job [${job?.id}] failed with error:`, err);
});

// Graceful Shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received. Shutting down worker...');
  await pdfWorker.close();
  process.exit(0);
});
