import { Queue } from 'bullmq';
import { redis } from '../config/redis.js';

export const pdfQueue = new Queue('pdf-processing', { connection: redis });
export const audioQueue = new Queue('audio-transcription', { connection: redis });
export const notificationQueue = new Queue('notifications', { connection: redis });
