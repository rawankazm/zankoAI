import assert from 'node:assert';
import { AiCostGuardService } from '../src/services/ai_cost_guard.service.js';
import { redis } from '../src/config/redis.js';
import { AppError } from '../src/utils/apiError.js';
import { AiPlanTier } from '../src/types/ai_cost.types.js';

export async function runAiCostProtectionTests() {
  console.log('\n🛡️ Running ZankoAI AI Cost Control & Abuse Protection Test Suite...\n');

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

  try {
    // ─── 1. Telemetry Verification: All 10 Required Fields Tracked ───
    await test('AiCostGuardService records AI request with all 10 mandatory fields', async () => {
      const mockUserId = '00000000-0000-0000-0000-000000000001';
      const now = new Date().toISOString();

      const logRecord = await AiCostGuardService.recordAiRequest({
        user_id: mockUserId,
        feature: 'ai_chat',
        provider: 'google',
        model: 'gemini-2.5-flash',
        input_tokens: 150,
        output_tokens: 300,
        estimated_cost: 0.000101,
        duration: 420,
        status: 'success',
        created_at: now,
      });

      assert.strictEqual(logRecord.user_id, mockUserId);
      assert.strictEqual(logRecord.feature, 'ai_chat');
      assert.strictEqual(logRecord.provider, 'google');
      assert.strictEqual(logRecord.model, 'gemini-2.5-flash');
      assert.strictEqual(logRecord.input_tokens, 150);
      assert.strictEqual(logRecord.output_tokens, 300);
      assert.strictEqual(logRecord.estimated_cost, 0.000101);
      assert.strictEqual(logRecord.duration, 420);
      assert.strictEqual(logRecord.status, 'success');
      assert.strictEqual(logRecord.created_at, now);
    });

    // ─── 2. Configurable Limits for Free vs Premium ───
    await test('Free and Premium tiers have different configurable limits', async () => {
      const freeLimits = await AiCostGuardService.getLimits('free');
      const premiumLimits = await AiCostGuardService.getLimits('premium');

      assert.strictEqual(freeLimits.plan, 'free');
      assert.strictEqual(premiumLimits.plan, 'premium');

      // Request size limits
      assert.ok(freeLimits.max_request_chars < premiumLimits.max_request_chars);
      assert.strictEqual(freeLimits.max_request_chars, 4000);
      assert.strictEqual(premiumLimits.max_request_chars, 32000);

      // Token limits
      assert.ok(freeLimits.max_tokens < premiumLimits.max_tokens);
      assert.strictEqual(freeLimits.max_tokens, 2048);
      assert.strictEqual(premiumLimits.max_tokens, 8192);

      // Daily and monthly budgets
      assert.ok(freeLimits.max_daily_cost_usd < premiumLimits.max_daily_cost_usd);
      assert.ok(freeLimits.max_monthly_cost_usd < premiumLimits.max_monthly_cost_usd);

      // Concurrency limits
      assert.strictEqual(freeLimits.max_concurrent_jobs, 1);
      assert.strictEqual(premiumLimits.max_concurrent_jobs, 5);
    });

    // ─── 3. Abuse Test: Request Payload Size Caps ───
    await test('Abuse: Free tier rejects oversized request payloads (>4,000 chars)', async () => {
      const oversizedChars = 4500;
      let rejected = false;

      try {
        await AiCostGuardService.validateRequestSize(oversizedChars, 'free');
      } catch (err: any) {
        rejected = true;
        assert.strictEqual(err.statusCode, 413);
        assert.strictEqual(err.code, 'AI_PAYLOAD_TOO_LARGE');
        assert.ok(err.message.includes('exceeds maximum allowed length'));
      }

      assert.strictEqual(rejected, true, 'Oversized request for free tier must be rejected');
    });

    await test('Abuse: Premium tier allows up to 32,000 chars but rejects >32,000', async () => {
      // 5,000 chars should succeed for premium
      await AiCostGuardService.validateRequestSize(5000, 'premium');

      // 35,000 chars should fail even for premium
      let rejected = false;
      try {
        await AiCostGuardService.validateRequestSize(35000, 'premium');
      } catch (err: any) {
        rejected = true;
        assert.strictEqual(err.statusCode, 413);
        assert.strictEqual(err.code, 'AI_PAYLOAD_TOO_LARGE');
      }
      assert.strictEqual(rejected, true, 'Payload > 32,000 chars must be rejected');
    });

    // ─── 4. Abuse Test: Token Caps Clamping ───
    await test('Token limits clamp requests to tier-configured ceilings', async () => {
      const clampedFree = await AiCostGuardService.clampTokenLimit(10000, 'free');
      assert.strictEqual(clampedFree, 2048, 'Free tier tokens must be clamped to 2048');

      const clampedPremium = await AiCostGuardService.clampTokenLimit(10000, 'premium');
      assert.strictEqual(clampedPremium, 8192, 'Premium tier tokens must be clamped to 8192');

      const normalFree = await AiCostGuardService.clampTokenLimit(500, 'free');
      assert.strictEqual(normalFree, 500, 'Normal tokens within limit remain untouched');
    });

    // ─── 5. Concurrency Test: Lock Acquisition, Enforcement, and Release ───
    await test('Concurrency: Free user cannot run more than 1 concurrent AI job', async () => {
      const concurrentUserId = 'user-concurrency-test-01';

      // Ensure clean slate
      await AiCostGuardService.releaseConcurrencySlot(concurrentUserId);

      // 1st slot should acquire cleanly
      const firstSlot = await AiCostGuardService.acquireConcurrencySlot(concurrentUserId, 'free');
      assert.strictEqual(firstSlot, 1);

      // 2nd parallel slot should fail with 429
      let blocked = false;
      try {
        await AiCostGuardService.acquireConcurrencySlot(concurrentUserId, 'free');
      } catch (err: any) {
        blocked = true;
        assert.strictEqual(err.statusCode, 429);
        assert.strictEqual(err.code, 'AI_CONCURRENCY_LIMIT_EXCEEDED');
      }
      assert.strictEqual(blocked, true, 'Second concurrent request must be rejected');

      // Release slot
      await AiCostGuardService.releaseConcurrencySlot(concurrentUserId);

      // Re-acquisition should now succeed
      const reacquiredSlot = await AiCostGuardService.acquireConcurrencySlot(concurrentUserId, 'free');
      assert.strictEqual(reacquiredSlot, 1);
      await AiCostGuardService.releaseConcurrencySlot(concurrentUserId);
    });

    await test('Concurrency: Premium user can run up to 5 concurrent jobs', async () => {
      const premUserId = 'prem-concurrency-test-01';

      // Clean slate
      await redis.del(`ai:concurrency:${premUserId}`);

      // Acquire 5 slots
      for (let i = 1; i <= 5; i++) {
        const slot = await AiCostGuardService.acquireConcurrencySlot(premUserId, 'premium');
        assert.strictEqual(slot, i);
      }

      // 6th concurrent slot must be rejected
      let blocked = false;
      try {
        await AiCostGuardService.acquireConcurrencySlot(premUserId, 'premium');
      } catch (err: any) {
        blocked = true;
        assert.strictEqual(err.statusCode, 429);
        assert.strictEqual(err.code, 'AI_CONCURRENCY_LIMIT_EXCEEDED');
      }
      assert.strictEqual(blocked, true, '6th concurrent job for premium must be rejected');

      // Clean up
      await redis.del(`ai:concurrency:${premUserId}`);
    });

    // ─── 6. Abuse Test: Budget Enforcement and Uncontrolled Cost Prevention ───
    await test('Budget: Hard daily spending cutoff prevents runaway user cost', async () => {
      const budgetUserId = 'budget-abuse-test-user-01';
      const todayKey = new Date().toISOString().slice(0, 10);
      const redisDailyCostKey = `ai:cost:user:${budgetUserId}:${todayKey}`;

      // Simulate user already having consumed $0.15 today (Free tier max is $0.10)
      await redis.set(redisDailyCostKey, '0.15', 'EX', 86400);

      let blocked = false;
      try {
        await AiCostGuardService.checkBudgets(budgetUserId, 'free');
      } catch (err: any) {
        blocked = true;
        assert.strictEqual(err.statusCode, 429);
        assert.strictEqual(err.code, 'AI_DAILY_BUDGET_EXCEEDED');
        assert.ok(err.message.includes('Daily AI expenditure budget exceeded'));
      }

      assert.strictEqual(blocked, true, 'User exceeding daily budget must be hard blocked');

      // Cleanup
      await redis.del(redisDailyCostKey);
    });

    await test('Budget: Hard monthly spending cutoff prevents runaway monthly cost', async () => {
      const budgetUserId = 'budget-abuse-test-user-02';
      const monthKey = new Date().toISOString().slice(0, 7);
      const redisMonthlyCostKey = `ai:cost:user:${budgetUserId}:month:${monthKey}`;

      // Simulate user having consumed $1.60 in month (Free tier max is $1.50)
      await redis.set(redisMonthlyCostKey, '1.60', 'EX', 86400 * 32);

      let blocked = false;
      try {
        await AiCostGuardService.checkBudgets(budgetUserId, 'free');
      } catch (err: any) {
        blocked = true;
        assert.strictEqual(err.statusCode, 429);
        assert.strictEqual(err.code, 'AI_MONTHLY_BUDGET_EXCEEDED');
        assert.ok(err.message.includes('Monthly AI expenditure budget exceeded'));
      }

      assert.strictEqual(blocked, true, 'User exceeding monthly budget must be hard blocked');

      // Cleanup
      await redis.del(redisMonthlyCostKey);
    });

    // ─── 7. Security Test: Never Expose Provider API Keys ───
    await test('Security: Provider API keys are completely sanitized and redacted', () => {
      const dangerousErrors = [
        'Google Gemini Error: API_KEY_INVALID with key AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6',
        'DeepSeek HTTP 401 Unauthorized: Bearer sk-1234567890abcdef1234567890abcdef',
        'OpenAI Error: sk-proj-abc123def456ghi789jkl012mno345pqr is deactivated',
        'Anthropic API error: ant-api03-abcdef1234567890abcdef1234567890 invalid authorization header',
      ];

      for (const dangerous of dangerousErrors) {
        const sanitized = AiCostGuardService.sanitizeSecrets(dangerous);
        assert.strictEqual(sanitized.includes('AIzaSy'), false, 'Gemini API key must NOT be present');
        assert.strictEqual(sanitized.includes('sk-123456'), false, 'DeepSeek/OpenAI key must NOT be present');
        assert.strictEqual(sanitized.includes('sk-proj'), false, 'OpenAI project key must NOT be present');
        assert.strictEqual(sanitized.includes('ant-api03'), false, 'Anthropic key must NOT be present');
        assert.ok(sanitized.includes('[REDACTED_API_KEY]'), 'Redacted marker must be substituted');
      }
    });

    // ─── 8. Admin Telemetry & Cost Reporting ───
    await test('Admin monitoring: getUsageReport and getCostReport return aggregated metrics', async () => {
      const usageReport = await AiCostGuardService.getUsageReport({ period: 'today' });
      assert.ok('total_requests' in usageReport);
      assert.ok('total_input_tokens' in usageReport);
      assert.ok('total_output_tokens' in usageReport);
      assert.ok('by_feature' in usageReport);
      assert.ok('by_provider' in usageReport);
      assert.ok('by_model' in usageReport);
      assert.ok(Array.isArray(usageReport.recent_requests));

      const costReport = await AiCostGuardService.getCostReport({ period: 'today' });
      assert.ok('total_cost_usd' in costReport);
      assert.ok('period_cost_usd' in costReport);
      assert.ok('by_feature' in costReport);
      assert.ok('by_provider' in costReport);
      assert.ok('by_model' in costReport);
      assert.ok(Array.isArray(costReport.top_spenders));
    });
  } catch (globalErr: any) {
    console.error('Fatal test error in AiCostProtectionTests:', globalErr);
  }

  console.log(`\n✨ AI Cost Protection Test Results: ${passed}/${total} passed\n`);
  if (passed !== total) {
    throw new Error(`AI Cost Protection Test Suite failed: ${total - passed} tests failed`);
  }
}

// Allow direct CLI execution: tsx tests/ai_cost_protection.test.ts
if (process.argv[1]?.includes('ai_cost_protection.test')) {
  runAiCostProtectionTests().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
