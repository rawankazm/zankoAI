import { Request, Response } from 'express';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { checkSupabaseHealth } from '../config/supabase.js';
import { checkRedisHealth } from '../config/redis.js';
import { env } from '../config/env.js';

import { WorkerHealthService } from '../services/worker_health.service.js';

export class HealthController {
  /**
   * Liveness probe: returns 200 if the process is up and receiving requests
   * Endpoint: GET /api/health
   */
  static getHealth(req: Request, res: Response): Response {
    return ResponseFormatter.success(
      res,
      {
        status: 'ok',
        service: 'zanko-backend',
        environment: env.NODE_ENV,
        uptimeSeconds: Math.floor(process.uptime()),
        memoryUsageMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
      },
      'ZankoAI service is live'
    );
  }

  /**
   * Readiness probe: checks dependencies (Supabase DB + Redis)
   * Endpoint: GET /api/ready
   */
  static async getReady(req: Request, res: Response): Promise<Response> {
    const [supabaseReady, redisReady] = await Promise.all([
      checkSupabaseHealth(),
      checkRedisHealth(),
    ]);

    const isReady = supabaseReady && redisReady;
    const statusCode = isReady ? 200 : 503;

    return res.status(statusCode).json({
      success: isReady,
      status: isReady ? 'ready' : 'degraded',
      dependencies: {
        supabaseDatabase: supabaseReady ? 'healthy' : 'unreachable',
        redisCache: redisReady ? 'healthy' : 'unreachable',
      },
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Worker health check: reports status of background workers, queues, and dead letters
   * Endpoint: GET /api/health/worker
   */
  static async getWorkerHealth(req: Request, res: Response): Promise<Response> {
    const report = await WorkerHealthService.getHealthReport();
    const statusCode = report.status === 'down' ? 503 : 200;

    return res.status(statusCode).json({
      success: report.status !== 'down',
      data: report,
      message: 'Background worker status: ' + report.status,
    });
  }
}
