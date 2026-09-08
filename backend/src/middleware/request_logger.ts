import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import { logger, redactSensitiveData } from '../config/logger.js';
import { MetricsService } from '../services/metrics.service.js';

export interface StructuredRequestLog {
  request_id: string;
  user_id: string | null;
  route: string;
  method: string;
  status: number;
  duration: string;
  duration_ms: number;
  ip?: string;
  user_agent?: string;
  timestamp: string;
}

/**
 * Enterprise Structured JSON Request Logger Middleware
 * Guarantees zero sensitive data leakage and records production latency metrics.
 */
export const requestLogger = (req: Request, res: Response, next: NextFunction): void => {
  // 1. Assign or propagate tracing request_id
  const requestId = (req.headers['x-request-id'] as string) || crypto.randomUUID();
  (req as any).requestId = requestId;
  res.setHeader('X-Request-Id', requestId);

  const startNs = process.hrtime.bigint();

  // 2. Intercept response completion
  res.on('finish', () => {
    const endNs = process.hrtime.bigint();
    const durationMs = Math.round((Number(endNs - startNs) / 1e6) * 100) / 100;

    // Record request into production metrics collector
    MetricsService.recordRequest(durationMs, res.statusCode);

    // Extract authenticated user ID where available
    const userId = (req as any).user?.id || (req as any).profile?.id || null;

    // Sanitize and redact route and query parameters
    const safeRoute = req.baseUrl ? `${req.baseUrl}${req.path}` : (req.path || req.originalUrl.split('?')[0]);

    const logPayload: StructuredRequestLog = {
      request_id: requestId,
      user_id: userId,
      route: safeRoute,
      method: req.method,
      status: res.statusCode,
      duration: `${durationMs}ms`,
      duration_ms: durationMs,
      timestamp: new Date().toISOString(),
    };

    // Include sanitized client metadata for non-health endpoints
    if (!safeRoute.startsWith('/health') && !safeRoute.startsWith('/ready') && !safeRoute.startsWith('/api/health') && !safeRoute.startsWith('/api/ready')) {
      logPayload.ip = (req.headers['x-forwarded-for'] as string)?.split(',')[0]?.trim() || req.socket.remoteAddress;
      logPayload.user_agent = req.headers['user-agent']?.substring(0, 150);
    }

    // Determine log level by HTTP status
    if (res.statusCode >= 500) {
      logger.error('HTTP Request Completed with Server Error', redactSensitiveData(logPayload));
    } else if (res.statusCode >= 400) {
      logger.warn('HTTP Request Completed with Client Warning', redactSensitiveData(logPayload));
    } else {
      logger.info('HTTP Request Completed', redactSensitiveData(logPayload));
    }
  });

  next();
};
