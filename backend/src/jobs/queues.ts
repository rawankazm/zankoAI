import { Queue } from 'bullmq';
import { redis } from '../config/redis.js';
import { logger } from '../config/logger.js';

// Queue for asynchronous file processing (lecture slides, book PDFs, thesis OCR)
export const fileProcessingQueue = new Queue('file-processing', {
  connection: redis,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 2000,
    },
    removeOnComplete: 100,
    removeOnFail: 500,
  },
});

// Queue for user notifications (push, telegram, email alerts)
export const notificationQueue = new Queue('notifications', {
  connection: redis,
  defaultJobOptions: {
    attempts: 5,
    backoff: {
      type: 'exponential',
      delay: 1000,
    },
    removeOnComplete: true,
  },
});

// Queue for PDF AI processing (extraction + summarize + quiz + flashcards + questions)
export const pdfAiQueue = new Queue('pdf-ai-processing', {
  connection: redis,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 3000,
    },
    removeOnComplete: 100,
    removeOnFail: 200,
  },
});

logger.info('📦 BullMQ queues initialized (file-processing, notifications, pdf-ai-processing)');
