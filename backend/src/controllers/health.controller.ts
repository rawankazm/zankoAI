import { Request, Response } from 'express';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { checkSupabaseHealth } from '../config/supabase.js';
import { checkRedisHealth } from '../config/redis.js';
import { env } from '../config/env.js';
import { WorkerHealthService } from '../services/worker_health.service.js';
import { MetricsService } from '../services/metrics.service.js';
import { AlertThresholdsService } from '../services/alert_thresholds.service.js';

export class HealthController {
  /**
   * Liveness probe: returns 200 if the process is up and receiving requests
   * Endpoints: GET /api/health and GET /health
   */
  static getHealth(req: Request, res: Response): Response {
    const uptimeSec = Math.floor(process.uptime());
    return ResponseFormatter.success(
      res,
      {
        status: 'ok',
        service: 'zanko-backend',
        environment: env.NODE_ENV,
        uptime_seconds: uptimeSec,
        uptimeFormatted: `${Math.floor(uptimeSec / 60)}m ${uptimeSec % 60}s`,
        timestamp: new Date().toISOString(),
      },
      'ZankoAI service is live'
    );
  }

  /**
   * Readiness probe: checks dependencies (Supabase DB + Redis + Disk + Memory)
   * Endpoints: GET /api/ready and GET /ready
   */
  static async getReady(req: Request, res: Response): Promise<Response> {
    const [supabaseReady, redisReady, diskMetrics] = await Promise.all([
      checkSupabaseHealth(),
      checkRedisHealth(),
      MetricsService.getDiskMetrics(),
    ]);

    const memUsage = process.memoryUsage();
    const memoryHealthy = memUsage.heapUsed < memUsage.heapTotal * 0.98;
    const diskHealthy = diskMetrics.usedPercent < 95;

    const isReady = supabaseReady && redisReady && diskHealthy && memoryHealthy;
    const statusCode = isReady ? 200 : 503;

    return res.status(statusCode).json({
      success: isReady,
      status: isReady ? 'ready' : 'degraded',
      dependencies: {
        database: supabaseReady ? 'healthy' : 'unreachable',
        supabaseDatabase: supabaseReady ? 'healthy' : 'unreachable',
        redis: redisReady ? 'healthy' : 'unreachable',
        redisCache: redisReady ? 'healthy' : 'unreachable',
        disk: diskHealthy ? 'healthy' : 'critical',
        memory: memoryHealthy ? 'healthy' : 'critical',
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

  /**
   * Comprehensive Production Metrics & Alert Thresholds Dashboard
   * Endpoints: GET /api/metrics and GET /api/health/metrics
   */
  static async getMetrics(req: Request, res: Response): Promise<Response> {
    const metricsReport = await MetricsService.getFullReport();
    const healthAssessment = AlertThresholdsService.evaluate(metricsReport);

    return res.status(200).json({
      success: true,
      data: {
        ...metricsReport,
        assessment: healthAssessment,
      },
      timestamp: new Date().toISOString(),
    });
  }
}
