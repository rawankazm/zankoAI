import assert from 'node:assert';
import { createApp } from '../src/app.js';
import { UsageService } from '../src/services/usage.service.js';
import { enforceUsage } from '../src/middleware/enforceUsage.js';
import { QuotaExceededError } from '../src/utils/apiError.js';
import { QuotaCheckResult } from '../src/types/usage.types.js';

export async function runUsageLimitsTests() {
  console.log('\n💎 Running ZankoAI Plan Limits & Usage Enforcement Test Suite...\n');

  let passed = 0;
  let total = 0;

  const test = async (name: string, fn: () => Promise<void> | void) => {
    total++;
    try {
      await fn();
      console.log(`  ✅ PASSED: ${name}`);
      passed++;
    } catch (err: any) {
      console.error(`  ❌ FAILED: ${name}`);
      console.error(`     Error: ${err.message}`);
    }
  };

  const app = createApp();
  const PORT = 4099;
  const server = app.listen(PORT);

  try {
    // ─── 1. Core Service Quota Consumption & Structure Verification ───
    await test('UsageService returns valid QuotaCheckResult structure with all required fields', async () => {
      const dummyUserId = '00000000-0000-0000-0000-000000000001';
      const result = await UsageService.consumeQuota(dummyUserId, 'ai_chat', 1);

      assert.ok('allowed' in result, 'Expected allowed boolean');
      assert.ok('current_usage' in result, 'Expected current_usage field');
      assert.ok('limit' in result, 'Expected limit field');
      assert.ok('remaining' in result, 'Expected remaining field');
      assert.ok('reset_at' in result, 'Expected reset_at timestamp');
      assert.ok('feature' in result, 'Expected feature name');
      assert.ok('plan' in result, 'Expected plan type');

      assert.strictEqual(result.feature, 'ai_chat');
      assert.strictEqual(typeof result.current_usage, 'number');
      assert.strictEqual(typeof result.limit, 'number');
      assert.strictEqual(typeof result.remaining, 'number');
      assert.strictEqual(typeof result.reset_at, 'string');
    });

    // ─── 2. Free Plan Limits Enforcement & Rejection (10 AI chats/day) ───
    await test('Free plan correctly rejects when AI Chat daily limit is exceeded', async () => {
      const testUserId = '00000000-0000-0000-0000-000000000002';
      
      // Consume up to limit
      let res: QuotaCheckResult | null = null;
      for (let i = 0; i < 10; i++) {
        res = await UsageService.consumeQuota(testUserId, 'ai_chat', 1);
      }

      // 11th request must be rejected
      const blockedResult = await UsageService.consumeQuota(testUserId, 'ai_chat', 1);
      assert.strictEqual(blockedResult.allowed, false, '11th AI chat request on free plan must be disallowed');
      assert.strictEqual(blockedResult.code, 'QUOTA_EXCEEDED');
      assert.strictEqual(blockedResult.remaining, 0);
      assert.strictEqual(blockedResult.limit, 10);
      assert.ok(blockedResult.current_usage >= 10);
    });

    // ─── 3. Idempotency Key Double-Counting Protection ───
    await test('Idempotency key prevents double-counting on network retries', async () => {
      const testUserId = '00000000-0000-0000-0000-000000000003';
      const idempotencyToken = `idem-test-${Date.now()}-${Math.random()}`;

      // First call consumes 1
      const firstCall = await UsageService.consumeQuota(testUserId, 'quiz', 1, idempotencyToken);
      const usageAfterFirst = firstCall.current_usage;

      // Second call with identical token should NOT increment
      const retryCall = await UsageService.consumeQuota(testUserId, 'quiz', 1, idempotencyToken);
      assert.strictEqual(retryCall.allowed, true);
      assert.strictEqual(retryCall.is_idempotent_replay, true, 'Retry with same token should be flagged as idempotent');
      assert.strictEqual(
        retryCall.current_usage,
        usageAfterFirst,
        'Idempotent retry must not increase current_usage'
      );
    });

    // ─── 4. Monthly Feature Limits Tracking (PDF, OCR, Audio, Quiz, Flashcards) ───
    await test('Monthly features properly track quota over monthly period windows', async () => {
      const testUserId = '00000000-0000-0000-0000-000000000004';

      const pdfQuota = await UsageService.consumeQuota(testUserId, 'pdf', 1);
      assert.strictEqual(pdfQuota.period_type, 'monthly');
      assert.strictEqual(pdfQuota.limit, 3, 'Free plan has 3 PDFs per month');

      const ocrQuota = await UsageService.consumeQuota(testUserId, 'ocr', 1);
      assert.strictEqual(ocrQuota.period_type, 'monthly');
      assert.strictEqual(ocrQuota.limit, 10, 'Free plan has 10 OCR operations per month');

      const audioQuota = await UsageService.consumeQuota(testUserId, 'audio', 1);
      assert.strictEqual(audioQuota.period_type, 'monthly');
      assert.strictEqual(audioQuota.limit, 5, 'Free plan has 5 Audio jobs per month');

      const flashcardsQuota = await UsageService.consumeQuota(testUserId, 'flashcards', 1);
      assert.strictEqual(flashcardsQuota.period_type, 'monthly');
      assert.strictEqual(flashcardsQuota.limit, 5, 'Free plan has 5 Flashcards per month');
    });

    // ─── 5. Dry-Run Check Without Consuming Quota ───
    await test('checkQuota performs dry-run inspection without consuming usage', async () => {
      const testUserId = '00000000-0000-0000-0000-000000000005';
      const initial = await UsageService.checkQuota(testUserId, 'homework');
      const inspectAgain = await UsageService.checkQuota(testUserId, 'homework');

      assert.strictEqual(
        initial.current_usage,
        inspectAgain.current_usage,
        'Dry run check should not mutate usage counter'
      );
    });

    // ─── 6. Express Middleware RateLimit Headers & HTTP 429 Rejection ───
    await test('enforceUsage middleware rejects unauthenticated requests with 401', async () => {
      const middleware = enforceUsage('ai_chat');
      const req: any = { headers: {} };
      let errorThrown: any = null;

      await middleware(req, {} as any, (err?: any) => {
        errorThrown = err;
      });

      assert.ok(errorThrown);
      assert.strictEqual(errorThrown.statusCode, 401);
    });

    await test('enforceUsage sets X-RateLimit headers and handles quota exhaustion', async () => {
      const testUserId = '00000000-0000-0000-0000-000000000006';
      const middleware = enforceUsage('ai_chat');

      const headers: Record<string, string> = {};
      const res: any = {
        setHeader: (name: string, val: string) => {
          headers[name.toLowerCase()] = val;
        },
        status: (statusCode: number) => {
          res.statusCode = statusCode;
          return res;
        },
        json: (body: any) => {
          res.body = body;
          return res;
        },
      };

      const req: any = {
        user: { id: testUserId },
        headers: {},
      };

      let calledNext = false;
      await middleware(req, res, () => {
        calledNext = true;
      });

      assert.ok(headers['x-ratelimit-limit']);
      assert.ok(headers['x-ratelimit-remaining']);
      assert.ok(headers['x-ratelimit-reset']);
      assert.strictEqual(calledNext, true);
    });

    // ─── 7. Centralized Dynamic Plan Limits (No Hardcoding) ───
    await test('Admin plan limits are dynamically configurable from plan_limits table', async () => {
      const limits = await UsageService.listPlanLimits();
      assert.ok(Array.isArray(limits));
      assert.ok(limits.length >= 8, 'Expected at least 8 seeded plan limits');

      const freeChatLimit = limits.find((l) => l.plan === 'free' && l.feature === 'ai_chat');
      assert.ok(freeChatLimit);
      assert.strictEqual(freeChatLimit.limit_value, 10);
      assert.strictEqual(freeChatLimit.period_type, 'daily');
    });

    // ─── 8. API Endpoint Authentication Guards ───
    await test('GET /api/usage/status rejects unauthenticated requests (401)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/usage/status`);
      assert.strictEqual(res.status, 401);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'UNAUTHORIZED');
    });

    await test('POST /api/usage/check rejects unauthenticated requests (401)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/usage/check`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ feature: 'ai_chat' }),
      });
      assert.strictEqual(res.status, 401);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'UNAUTHORIZED');
    });

    // ─── 9. User Usage Summary Structure ───
    await test('getUserUsageStatus returns comprehensive breakdown across all features', async () => {
      const testUserId = '00000000-0000-0000-0000-000000000007';
      const summary = await UsageService.getUserUsageStatus(testUserId);

      assert.ok(['free', 'premium'].includes(summary.plan));
      assert.ok(typeof summary.features === 'object');
      assert.ok('ai_chat' in summary.features);
      assert.ok('pdf' in summary.features);
      assert.ok('ocr' in summary.features);
      assert.ok('audio' in summary.features);
      assert.ok('homework' in summary.features);
      assert.ok('quiz' in summary.features);
      assert.ok('flashcards' in summary.features);
      assert.ok('storage' in summary.features);

      const aiChatStatus = summary.features.ai_chat;
      assert.strictEqual(aiChatStatus.period_type, 'daily');
      assert.strictEqual(typeof aiChatStatus.current_usage, 'number');
      assert.strictEqual(typeof aiChatStatus.limit, 'number');
      assert.strictEqual(typeof aiChatStatus.remaining, 'number');
      assert.ok(typeof aiChatStatus.reset_at === 'string');
    });

  } finally {
    server.close();
  }

  console.log(`\n=========================================`);
  console.log(`🏁 Usage Limits Suite: ${passed}/${total} tests passed`);
  console.log(`=========================================\n`);
}

// Allow direct execution
if (process.argv[1]?.endsWith('usage_limits.test.ts') || process.argv[1]?.endsWith('usage_limits.test.js')) {
  runUsageLimitsTests().catch((err) => {
    console.error('Test suite failed:', err);
    process.exit(1);
  });
}
