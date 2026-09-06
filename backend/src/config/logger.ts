import winston from 'winston';
import { env } from './env.js';

const { combine, timestamp, printf, colorize, json, errors } = winston.format;

const devFormat = printf(({ level, message, timestamp, stack, ...meta }) => {
  const metaString = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
  return `[${timestamp}] ${level}: ${stack || message} ${metaString}`;
});

export const logger = winston.createLogger({
  level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  format: combine(
    timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    errors({ stack: true }),
    env.NODE_ENV === 'production' ? json() : combine(colorize(), devFormat)
  ),
  defaultMeta: { service: 'zanko-backend' },
  transports: [
    new winston.transports.Console({
      silent: env.NODE_ENV === 'test',
    }),
  ],
});
