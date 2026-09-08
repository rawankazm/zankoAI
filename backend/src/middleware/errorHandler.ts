import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/apiError.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { logger } from '../config/logger.js';
import { env } from '../config/env.js';
import { AiCostGuardService } from '../services/ai_cost_guard.service.js';

export const errorHandler = (
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const isProduction = env.NODE_ENV === 'production';

  // Sanitize all error messages and stacks to prevent any API key or secret leakage
  const safeMessage = AiCostGuardService.sanitizeSecrets(err.message || '');
  const safeStack = err.stack ? AiCostGuardService.sanitizeSecrets(err.stack) : undefined;

  // 1. Known Operational AppErrors
  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error(`[AppError ${err.statusCode}] ${safeMessage}`, {
        url: req.originalUrl,
        method: req.method,
        code: err.code,
        stack: safeStack,
      });

      // In production, mask internal 500 messages
      const clientMessage = isProduction ? 'An unexpected server error occurred' : safeMessage;
      const clientDetails = isProduction ? undefined : err.details;
      ResponseFormatter.error(res, clientMessage, err.statusCode, err.code, clientDetails);
      return;
    }

    // 4xx Client Errors (Validation, NotFound, Unauthorized, Forbidden, etc.)
    logger.warn(`[ClientError ${err.statusCode}] ${safeMessage}`, {
      url: req.originalUrl,
      method: req.method,
      code: err.code,
      details: err.details,
    });

    ResponseFormatter.error(res, safeMessage, err.statusCode, err.code, err.details);
    return;
  }

  // 2. Syntax / JSON Parsing Errors from Express body-parser
  if (err.name === 'SyntaxError' && 'body' in err) {
    logger.warn(`[MalformedJson] Malformed JSON payload received on ${req.method} ${req.originalUrl}`);
    ResponseFormatter.error(res, 'Malformed JSON payload in request body', 400, 'BAD_REQUEST');
    return;
  }

  // 3. Payload Too Large Error (413)
  if ((err as any).type === 'entity.too.large' || (err as any).status === 413) {
    logger.warn(`[PayloadTooLarge] Request entity exceeded size limit on ${req.method} ${req.originalUrl}`);
    ResponseFormatter.error(
      res,
      'Request payload exceeds maximum allowed size (2MB limit)',
      413,
      'PAYLOAD_TOO_LARGE'
    );
    return;
  }

  // 4. CORS Policy Errors
  if (safeMessage.startsWith('CORS policy violation')) {
    logger.warn(`[CorsBlocked] ${safeMessage}`);
    ResponseFormatter.error(res, safeMessage, 403, 'CORS_FORBIDDEN');
    return;
  }

  // 5. Unexpected Internal System Errors (Never leak internal details or stacks in production)
  logger.error(`[UnhandledSystemError] ${safeMessage}`, {
    url: req.originalUrl,
    method: req.method,
    stack: safeStack,
  });

  const message = isProduction ? 'Internal server error' : safeMessage;
  const details = isProduction ? undefined : { stack: safeStack };

  ResponseFormatter.error(res, message, 500, 'INTERNAL_SERVER_ERROR', details);
};

export default errorHandler;

