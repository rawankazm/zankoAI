// ==============================================================================
// ZankoAI Production Monitoring and Logging — Automated Test Suite
// ==============================================================================

import assert from 'node:assert';
import { metricsService } from '../src/services/metrics.service.js';
import { alertThresholdsService } from '../src/services/alert_thresholds.service.js';
import { maskSensitiveFields } from '../src/config/logger.js';

console.log('📈 Starting Production Monitoring & Logging Suite...\n');

let passedTests = 0;
let totalTests = 0;

const runTest = async (name: string, fn: () => Promise<void> | void) => {
  totalTests++;
  try {
    await fn();
    console.log(`  ✅ PASSED: ${name}`);
    passedTests++;
  } catch (error: any) {
    console.error(`  ❌ FAILED: ${name}`);
    console.error(`     Error: ${error.message}`);
    throw error;
  }
};

export const runProductionMonitoringTests = async () => {
  // ─── 1. Metrics Service Metric Dimensions Collection ──────────────────────────
  await runTest('MetricsService: collects all 14 required monitoring dimensions', async () => {
    const report = await metricsService.getProductionMetricsReport();

    // 1. API uptime
    assert.ok(typeof report.apiUptime.seconds === 'number');
    assert.ok(report.apiUptime.seconds >= 0);
    assert.ok(typeof report.apiUptime.formatted === 'string');

    // 2. CPU
    assert.ok(typeof report.cpu.cores === 'number');
    assert.ok(report.cpu.cores > 0);
    assert.ok(typeof report.cpu.loadAvg1m === 'number');
    assert.ok(typeof report.cpu.processCpuPercent === 'number');

    // 3. RAM
    assert.ok(report.ram.totalBytes > 0);
    assert.ok(report.ram.usedPercent >= 0 && report.ram.usedPercent <= 100);
    assert.ok(report.ram.heapUsed > 0);

    // 4. Disk
    assert.ok(report.disk.totalMb > 0);
    assert.ok(['ok', 'warning', 'critical'].includes(report.disk.status));

    // 5. Redis
    assert.ok(['connected', 'disconnected', 'error'].includes(report.redis.status));

    // 6. Database
    assert.ok(['connected', 'disconnected', 'error'].includes(report.database.status));

    // 7. Workers
    assert.ok(typeof report.workers.activeWorkers === 'number');
    assert.ok(typeof report.workers.deadLetters === 'number');
    assert.ok('pdf' in report.workers.queues);
    assert.ok('ocr' in report.workers.queues);
    assert.ok('audio' in report.workers.queues);
    assert.ok('ai' in report.workers.queues);
    assert.ok('notifications' in report.workers.queues);

    // 8. API latency
    assert.ok(typeof report.apiLatency.avgMs === 'number');
    assert.ok(typeof report.apiLatency.p50Ms === 'number');
    assert.ok(typeof report.apiLatency.p95Ms === 'number');
    assert.ok(typeof report.apiLatency.p99Ms === 'number');

    // 9. HTTP errors
    assert.ok(typeof report.httpErrors.totalRequests === 'number');
    assert.ok(typeof report.httpErrors.errorRatePercent === 'number');

    // 10. AI errors
    assert.ok(typeof report.incidents.aiErrors === 'number');

    // 11. Payment errors
    assert.ok(typeof report.incidents.paymentErrors === 'number');

    // 12. Failed jobs
    assert.ok(typeof report.incidents.failedJobs === 'number');

    // 13. Queue length
    assert.ok(typeof report.workers.queues.pdf.waiting === 'number');

    // 14. Subscription failures
    assert.ok(typeof report.incidents.subscriptionFailures === 'number');
  });

  // ─── 2. Request Recording & Statistical Latency ─────────────────────────────
  await runTest('MetricsService: records request latencies and calculates accurate p95 / error rates', () => {
    // Record deterministic test samples
    metricsService.recordRequest(20, 200);
    metricsService.recordRequest(50, 200);
    metricsService.recordRequest(100, 201);
    metricsService.recordRequest(3500, 500);

    const stats = metricsService.getLatencyStats();
    assert.ok(stats.sampleCount >= 4);
    assert.ok(stats.p95Ms >= 100);
    assert.ok(stats.maxMs >= 3500);

    const httpStats = metricsService.getHttpStats();
    assert.ok(httpStats.totalRequests >= 4);
    assert.ok(httpStats.count5xx >= 1);
    assert.ok(httpStats.errorRatePercent > 0);
  });

  // ─── 3. Incident Counters Tracking ──────────────────────────────────────────
  await runTest('MetricsService: increments domain incident counters correctly', () => {
    const initialReport = metricsService.getIncidentStats();
    const initialAi = initialReport.aiErrors;
    const initialPay = initialReport.paymentErrors;
    const initialSub = initialReport.subscriptionFailures;
    const initialJobs = initialReport.failedJobs;

    metricsService.recordAiError();
    metricsService.recordPaymentError();
    metricsService.recordSubscriptionFailure();
    metricsService.recordFailedJob();

    const updated = metricsService.getIncidentStats();
    assert.strictEqual(updated.aiErrors, initialAi + 1);
    assert.strictEqual(updated.paymentErrors, initialPay + 1);
    assert.strictEqual(updated.subscriptionFailures, initialSub + 1);
    assert.strictEqual(updated.failedJobs, initialJobs + 1);
  });

  // ─── 4. Alert Thresholds Evaluation ─────────────────────────────────────────
  await runTest('AlertThresholdsService: triggers warnings and critical alerts when limits breached', async () => {
    // A: Healthy Baseline
    const mockHealthyReport: any = {
      cpu: { processCpuPercent: 20 },
      ram: { usedPercent: 45 },
      disk: { usedPercent: 50 },
      httpErrors: { errorRatePercent: 0.1 },
      apiLatency: { p95Ms: 120 },
      workers: { totalQueueLength: 5, deadLetters: 0 },
      database: { status: 'connected' },
      redis: { status: 'connected' },
      incidents: { paymentErrors: 0, failedJobs: 0 },
    };

    const healthyResult = alertThresholdsService.evaluate(mockHealthyReport);
    assert.strictEqual(healthyResult.status, 'healthy');
    assert.strictEqual(healthyResult.alerts.length, 0);

    // B: Breached Latency & CPU -> Warning
    const mockWarningReport: any = {
      ...mockHealthyReport,
      cpu: { processCpuPercent: 82 },
      apiLatency: { p95Ms: 1600 },
    };
    const warningResult = alertThresholdsService.evaluate(mockWarningReport);
    assert.strictEqual(warningResult.status, 'warning');
    assert.ok(warningResult.alerts.some((a) => a.metric === 'cpu'));
    assert.ok(warningResult.alerts.some((a) => a.metric === 'api_latency_p95'));

    // C: Critical Database Down & High Error Rate -> Critical
    const mockCriticalReport: any = {
      ...mockHealthyReport,
      database: { status: 'disconnected' },
      httpErrors: { errorRatePercent: 8.5 },
    };
    const criticalResult = alertThresholdsService.evaluate(mockCriticalReport);
    assert.strictEqual(criticalResult.status, 'critical');
    assert.ok(criticalResult.alerts.some((a) => a.metric === 'database'));
    assert.ok(criticalResult.alerts.some((a) => a.metric === 'http_5xx_rate'));
  });

  // ─── 5. Zero-Leakage Sensitive Masking ───────────────────────────────────────
  await runTest('Masking Policy: rigorously sanitizes passwords, card data, CVV, tokens, and AI keys', () => {
    const rawPayload = {
      request_id: 'req_123',
      user_id: 'usr_abc',
      password: 'super_secret_password',
      new_password: 'another_password',
      card_number: '4111 2222 3333 4444',
      cvv: '999',
      cvc: '123',
      gemini_api_key: 'AIzaSyA_sample_google_api_key_12345',
      openai_api_key: 'sk-proj-sample_openai_key_abcdef1234567890',
      nested: {
        access_token: 'jwt.token.here',
        auth_secret: 'topsecret_hmac_hash',
      },
    };

    const sanitized: any = maskSensitiveFields(rawPayload);

    // Passwords & Secrets
    assert.strictEqual(sanitized.password, '[REDACTED]');
    assert.strictEqual(sanitized.new_password, '[REDACTED]');
    assert.strictEqual(sanitized.nested.access_token, '[REDACTED]');
    assert.strictEqual(sanitized.nested.auth_secret, '[REDACTED]');

    // Card & CVV
    assert.strictEqual(sanitized.card_number, '[REDACTED]');
    assert.strictEqual(sanitized.cvv, '[REDACTED]');
    assert.strictEqual(sanitized.cvc, '[REDACTED]');

    // AI API Keys
    assert.strictEqual(sanitized.gemini_api_key, '[REDACTED]');
    assert.strictEqual(sanitized.openai_api_key, '[REDACTED]');

    // Non-sensitive fields preserved intact
    assert.strictEqual(sanitized.request_id, 'req_123');
    assert.strictEqual(sanitized.user_id, 'usr_abc');
  });

  console.log(`\n🎉 Production Monitoring Suite Complete: ${passedTests}/${totalTests} Passed.\n`);
};

// Run directly if invoked as script
if (process.argv[1]?.endsWith('production_monitoring.test.ts')) {
  runProductionMonitoringTests().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
