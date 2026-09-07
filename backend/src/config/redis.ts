import { Redis } from 'ioredis';
import { env } from './env.js';
import { logger } from './logger.js';

export const redisConnectionOptions = {
  host: env.REDIS_HOST,
  port: env.REDIS_PORT,
  password: env.REDIS_PASSWORD || undefined,
  tls: env.REDIS_TLS ? {} : undefined,
  lazyConnect: true,
  maxRetriesPerRequest: null, // Required by BullMQ for reliable blocking operations
  retryStrategy(times: number) {
    const delay = Math.min(times * 100, 3000);
    return delay;
  },
};

export const redis = new Redis(redisConnectionOptions);

redis.on('connect', () => {
  logger.info(' Connected to Redis server successfully');
});

redis.on('error', (err) => {
  logger.error(' Redis connection error:', err);
});

export const checkRedisHealth = async (): Promise<boolean> => {
  try {
    const res = await redis.ping();
    return res === 'PONG';
  } catch (error) {
    logger.warn(' Redis health check failed:', error);
    return false;
  }
};
