import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/apiError.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { logger } from '../config/logger.js';
import { env } from '../config/env.js';

export const errorHandler = (
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error(`[AppError ${err.statusCode}] ${err.message}`, {
        url: req.originalUrl,
        method: req.method,
        stack: err.stack,
      });
    } else {
      logger.warn(`[AppError ${err.statusCode}] ${err.message}`, {
        url: req.originalUrl,
        method: req.method,
        details: err.details,
      });
    }

    ResponseFormatter.error(res, err.message, err.statusCode, err.code, err.details);
    return;
  }

  // Handle unexpected system errors
  logger.error(`[UnhandledError] ${err.message}`, {
    url: req.originalUrl,
    method: req.method,
    stack: err.stack,
  });

  const message = env.NODE_ENV === 'production' ? 'Internal server error' : err.message;
  const details = env.NODE_ENV === 'production' ? undefined : err.stack;

  ResponseFormatter.error(res, message, 500, 'INTERNAL_SERVER_ERROR', details);
};
