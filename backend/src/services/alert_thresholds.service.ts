import { ProductionMetricsReport } from './metrics.service.js';

export type AlertSeverity = 'info' | 'warning' | 'critical';

export interface ActiveAlert {
  id: string;
  severity: AlertSeverity;
  metric: string;
  currentValue: string | number;
  threshold: string | number;
  message: string;
  timestamp: string;
}

export interface SystemHealthAssessment {
  status: 'healthy' | 'warning' | 'critical';
  activeAlerts: ActiveAlert[];
  healthyChecks: string[];
  evaluatedAt: string;
}

export class AlertThresholdsService {
  // Configurable Production Thresholds
  static readonly THRESHOLDS = {
    CPU_WARNING_PCT: 80,
    CPU_CRITICAL_PCT: 90,
    RAM_WARNING_PCT: 85,
    RAM_CRITICAL_PCT: 92,
    DISK_WARNING_PCT: 85,
    DISK_CRITICAL_PCT: 95,
    HTTP_5XX_ERROR_RATE_WARN_PCT: 2.0,
    HTTP_5XX_ERROR_RATE_CRIT_PCT: 5.0,
    API_P95_LATENCY_WARN_MS: 1500,
    API_P95_LATENCY_CRIT_MS: 3000,
    QUEUE_LENGTH_WARN: 100,
    QUEUE_LENGTH_CRIT: 500,
    FAILED_JOBS_WARN: 10,
    FAILED_JOBS_CRIT: 50,
    PAYMENT_ERRORS_WARN: 2,
    PAYMENT_ERRORS_CRIT: 5,
    AI_ERRORS_WARN: 10,
    AI_ERRORS_CRIT: 30,
    DB_LATENCY_WARN_MS: 500,
    REDIS_LATENCY_WARN_MS: 100,
  };

  /**
   * Evaluates current system metrics against configured alert thresholds
   */
  static evaluate(report: ProductionMetricsReport): SystemHealthAssessment {
    const alerts: ActiveAlert[] = [];
    const healthyChecks: string[] = [];
    const now = new Date().toISOString();

    // 1. CPU Checks
    if (report.cpu.estimatedCpuPercent >= this.THRESHOLDS.CPU_CRITICAL_PCT) {
      alerts.push({
        id: 'CPU_CRITICAL',
        severity: 'critical',
        metric: 'cpu',
        currentValue: `${report.cpu.estimatedCpuPercent}%`,
        threshold: `${this.THRESHOLDS.CPU_CRITICAL_PCT}%`,
        message: `CPU load (${report.cpu.estimatedCpuPercent}%) exceeds critical threshold (${this.THRESHOLDS.CPU_CRITICAL_PCT}%)`,
        timestamp: now,
      });
    } else if (report.cpu.estimatedCpuPercent >= this.THRESHOLDS.CPU_WARNING_PCT) {
      alerts.push({
        id: 'CPU_WARNING',
        severity: 'warning',
        metric: 'cpu',
        currentValue: `${report.cpu.estimatedCpuPercent}%`,
        threshold: `${this.THRESHOLDS.CPU_WARNING_PCT}%`,
        message: `CPU load (${report.cpu.estimatedCpuPercent}%) exceeds warning threshold (${this.THRESHOLDS.CPU_WARNING_PCT}%)`,
        timestamp: now,
      });
    } else {
      healthyChecks.push('cpu');
    }

    // 2. RAM Checks
    if (report.ram.usedPercent >= this.THRESHOLDS.RAM_CRITICAL_PCT) {
      alerts.push({
        id: 'RAM_CRITICAL',
        severity: 'critical',
        metric: 'ram',
        currentValue: `${report.ram.usedPercent}%`,
        threshold: `${this.THRESHOLDS.RAM_CRITICAL_PCT}%`,
        message: `RAM consumption (${report.ram.usedPercent}%) exceeds critical limit (${this.THRESHOLDS.RAM_CRITICAL_PCT}%)`,
        timestamp: now,
      });
    } else if (report.ram.usedPercent >= this.THRESHOLDS.RAM_WARNING_PCT) {
      alerts.push({
        id: 'RAM_WARNING',
        severity: 'warning',
        metric: 'ram',
        currentValue: `${report.ram.usedPercent}%`,
        threshold: `${this.THRESHOLDS.RAM_WARNING_PCT}%`,
        message: `RAM consumption (${report.ram.usedPercent}%) exceeds warning limit (${this.THRESHOLDS.RAM_WARNING_PCT}%)`,
        timestamp: now,
      });
    } else {
      healthyChecks.push('ram');
    }

    // 3. Disk Storage Checks
    if (report.disk.usedPercent >= this.THRESHOLDS.DISK_CRITICAL_PCT) {
      alerts.push({
        id: 'DISK_CRITICAL',
        severity: 'critical',
        metric: 'disk',
        currentValue: `${report.disk.usedPercent}%`,
        threshold: `${this.THRESHOLDS.DISK_CRITICAL_PCT}%`,
        message: `Disk storage usage (${report.disk.usedPercent}%) exceeds critical capacity (${this.THRESHOLDS.DISK_CRITICAL_PCT}%)`,
        timestamp: now,
      });
    } else if (report.disk.usedPercent >= this.THRESHOLDS.DISK_WARNING_PCT) {
      alerts.push({
        id: 'DISK_WARNING',
        severity: 'warning',
        metric: 'disk',
        currentValue: `${report.disk.usedPercent}%`,
        threshold: `${this.THRESHOLDS.DISK_WARNING_PCT}%`,
        message: `Disk storage usage (${report.disk.usedPercent}%) exceeds warning threshold (${this.THRESHOLDS.DISK_WARNING_PCT}%)`,
        timestamp: now,
      });
    } else {
      healthyChecks.push('disk');
    }

    // 4. Redis Checks
    if (!report.redis.connected) {
      alerts.push({
        id: 'REDIS_DOWN',
        severity: 'critical',
        metric: 'redis',
        currentValue: 'disconnected',
        threshold: 'connected',
        message: 'Redis server is unreachable or offline',
        timestamp: now,
      });
    } else if (report.redis.latencyMs > this.THRESHOLDS.REDIS_LATENCY_WARN_MS) {
      alerts.push({
        id: 'REDIS_HIGH_LATENCY',
        severity: 'warning',
        metric: 'redis',
        currentValue: `${report.redis.latencyMs}ms`,
        threshold: `${this.THRESHOLDS.REDIS_LATENCY_WARN_MS}ms`,
        message: `Redis ping latency (${report.redis.latencyMs}ms) is elevated`,
        timestamp: now,
      });
    } else {
      healthyChecks.push('redis');
    }

    // 5. Database Checks
    if (!report.database.connected) {
      alerts.push({
        id: 'DATABASE_DOWN',
        severity: 'critical',
        metric: 'database',
        currentValue: 'disconnected',
        threshold: 'connected',
        message: 'Supabase PostgreSQL database is unreachable or offline',
        timestamp: now,
      });
    } else if (report.database.latencyMs > this.THRESHOLDS.DB_LATENCY_WARN_MS) {
      alerts.push({
        id: 'DATABASE_HIGH_LATENCY',
        severity: 'warning',
        metric: 'database',
        currentValue: `${report.database.latencyMs}ms`,
        threshold: `${this.THRESHOLDS.DB_LATENCY_WARN_MS}ms`,
        message: `Database query latency (${report.database.latencyMs}ms) is elevated`,
        timestamp: now,
      });
    } else {
      healthyChecks.push('database');
    }

    // 6. HTTP Error Rate Checks
    const error5xxRate = report.httpErrors.totalRequests > 0
      ? Math.round((report.httpErrors.status5xx / report.httpErrors.totalRequests) * 10000) / 100
      : 0;

    if (error5xxRate >= this.THRESHOLDS.HTTP_5XX_ERROR_RATE_CRIT_PCT) {
      alerts.push({
        id: 'HTTP_5XX_CRITICAL',
        severity: 'critical',
        metric: 'httpErrors',
        currentValue: `${error5xxRate}%`,
        threshold: `${this.THRESHOLDS.HTTP_5XX_ERROR_RATE_CRIT_PCT}%`,
        message: `5xx server error rate (${error5xxRate}%) exceeds critical threshold (${this.THRESHOLDS.HTTP_5XX_ERROR_RATE_CRIT_PCT}%)`,
        timestamp: now,
      });
    } else if (error5xxRate >= this.THRESHOLDS.HTTP_5XX_ERROR_RATE_WARN_PCT) {
      alerts.push({
        id: 'HTTP_5XX_WARNING',
        severity: 'warning',
        metric: 'httpErrors',
        currentValue: `${error5xxRate}%`,
        threshold: `${this.THRESHOLDS.HTTP_5XX_ERROR_RATE_WARN_PCT}%`,
        message: `5xx server error rate (${error5xxRate}%) exceeds warning threshold (${this.THRESHOLDS.HTTP_5XX_ERROR_RATE_WARN_PCT}%)`,
        timestamp: now,
      });
    } else {
      healthyChecks.push('httpErrors');
    }

    // 7. API Latency Checks
    if (report.apiLatency.p95Ms >= this.THRESHOLDS.API_P95_LATENCY_CRIT_MS) {
      alerts.push({
        id: 'API_LATENCY_CRITICAL',
        severity: 'critical',
        metric: 'apiLatency',
        currentValue: `${report.apiLatency.p95Ms}ms`,
        threshold: `${this.THRESHOLDS.API_P95_LATENCY_CRIT_MS}ms`,
        message: `p95 API response time (${report.apiLatency.p95Ms}ms) exceeds critical threshold (${this.THRESHOLDS.API_P95_LATENCY_CRIT_MS}ms)`,
        timestamp: now,
      });
    } else if (report.apiLatency.p95Ms >= this.THRESHOLDS.API_P95_LATENCY_WARN_MS) {
      alerts.push({
        id: 'API_LATENCY_WARNING',
        severity: 'warning',
        metric: 'apiLatency',
        currentValue: `${report.apiLatency.p95Ms}ms`,
        threshold: `${this.THRESHOLDS.API_P95_LATENCY_WARN_MS}ms`,
        message: `p95 API response time (${report.apiLatency.p95Ms}ms) exceeds warning threshold (${this.THRESHOLDS.API_P95_LATENCY_WARN_MS}ms)`,
        timestamp: now,
      });
    } else {
      healthyChecks.push('apiLatency');
    }

    // 8. Worker Queue Length Checks
    if (report.worker.queueLength >= this.THRESHOLDS.QUEUE_LENGTH_CRIT) {
      alerts.push({
        id: 'QUEUE_CONGESTION_CRITICAL',
        severity: 'critical',
        metric: 'queueLength',
        currentValue: report.worker.queueLength,
        threshold: this.THRESHOLDS.QUEUE_LENGTH_CRIT,
        message: `Worker queue backlog (${report.worker.queueLength}) indicates severe worker starvation`,
        timestamp: now,
      });
    } else if (report.worker.queueLength >= this.THRESHOLDS.QUEUE_LENGTH_WARN) {
      alerts.push({
        id: 'QUEUE_CONGESTION_WARNING',
        severity: 'warning',
        metric: 'queueLength',
        currentValue: report.worker.queueLength,
        threshold: this.THRESHOLDS.QUEUE_LENGTH_WARN,
        message: `Worker queue backlog (${report.worker.queueLength}) is elevated`,
        timestamp: now,
      });
    } else {
      healthyChecks.push('queueLength');
    }

    // 9. Payment Failures (High Business Impact)
    if (report.incidentCounters.paymentErrors >= this.THRESHOLDS.PAYMENT_ERRORS_CRIT) {
      alerts.push({
        id: 'PAYMENT_FAILURES_CRITICAL',
        severity: 'critical',
        metric: 'paymentErrors',
        currentValue: report.incidentCounters.paymentErrors,
        threshold: this.THRESHOLDS.PAYMENT_ERRORS_CRIT,
        message: `Payment gateway error count (${report.incidentCounters.paymentErrors}) requires immediate attention`,
        timestamp: now,
      });
    } else if (report.incidentCounters.paymentErrors >= this.THRESHOLDS.PAYMENT_ERRORS_WARN) {
      alerts.push({
        id: 'PAYMENT_FAILURES_WARNING',
        severity: 'warning',
        metric: 'paymentErrors',
        currentValue: report.incidentCounters.paymentErrors,
        threshold: this.THRESHOLDS.PAYMENT_ERRORS_WARN,
        message: `Payment errors detected (${report.incidentCounters.paymentErrors})`,
        timestamp: now,
      });
    } else {
      healthyChecks.push('paymentErrors');
    }

    // Determine Overall Status
    let overallStatus: 'healthy' | 'warning' | 'critical' = 'healthy';
    if (alerts.some((a) => a.severity === 'critical')) {
      overallStatus = 'critical';
    } else if (alerts.some((a) => a.severity === 'warning')) {
      overallStatus = 'warning';
    }

    return {
      status: overallStatus,
      activeAlerts: alerts,
      healthyChecks,
      evaluatedAt: now,
    };
  }
}
