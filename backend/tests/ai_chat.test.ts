import assert from 'node:assert';
import { createApp } from '../src/app.js';
import { calculateModelCost } from '../src/modules/ai/providers/ai_provider.interface.js';
import { aiOrchestrator } from '../src/modules/ai/providers/ai_orchestrator.service.js';
import {
  chatSchema,
  listConversationsSchema,
  conversationIdParamSchema,
} from '../src/modules/ai/validators/chat.validator.js';
import { aiGateway } from '../src/modules/ai/ai.service.js';

export async function runAiChatTests() {
  console.log('\n🤖 Running ZankoAI Production AI Chat & Conversations Test Suite...\n');

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
  const PORT = 4015;
  const server = app.listen(PORT);
  const baseUrl = `http://localhost:${PORT}`;

  try {
    // ─── 1. Authentication & Security Enforcement ───
    await test('POST /api/ai/chat rejects unauthenticated requests with 401', async () => {
      const res = await fetch(`${baseUrl}/api/ai/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: 'سڵاو' }),
      });
      assert.strictEqual(res.status, 401, 'Endpoint must require Bearer JWT token');
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'UNAUTHORIZED');
    });

    await test('GET /api/ai/conversations rejects unauthenticated requests with 401', async () => {
      const res = await fetch(`${baseUrl}/api/ai/conversations`);
      assert.strictEqual(res.status, 401);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'UNAUTHORIZED');
    });

    await test('GET /api/ai/conversations/:id rejects unauthenticated requests with 401', async () => {
      const res = await fetch(`${baseUrl}/api/ai/conversations/00000000-0000-0000-0000-000000000001`);
      assert.strictEqual(res.status, 401);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'UNAUTHORIZED');
    });

    await test('DELETE /api/ai/conversations/:id rejects unauthenticated requests with 401', async () => {
      const res = await fetch(`${baseUrl}/api/ai/conversations/00000000-0000-0000-0000-000000000001`, {
        method: 'DELETE',
      });
      assert.strictEqual(res.status, 401);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'UNAUTHORIZED');
    });

    // ─── 2. Input Validation & Prompt Abuse Prevention ───
    await test('chatSchema rejects empty and whitespace-only messages', () => {
      assert.throws(() => chatSchema.parse({ message: '' }));
      assert.throws(() => chatSchema.parse({ message: '   ' }));
    });

    await test('chatSchema rejects messages exceeding 4,000 characters', () => {
      const oversized = 'a'.repeat(4001);
      assert.throws(() => chatSchema.parse({ message: oversized }));
    });

    await test('chatSchema accepts valid messages within bounds', () => {
      const valid = chatSchema.parse({ message: 'پرسیارێک لەسەر داتا ستراکچەر' });
      assert.strictEqual(valid.message, 'پرسیارێک لەسەر داتا ستراکچەر');
      assert.strictEqual(valid.conversationId, undefined);
    });

    await test('chatSchema validates optional UUID conversationId format', () => {
      // Valid UUID
      const validWithId = chatSchema.parse({
        message: 'دەستپێک',
        conversationId: '123e4567-e89b-12d3-a456-426614174000',
      });
      assert.strictEqual(validWithId.conversationId, '123e4567-e89b-12d3-a456-426614174000');

      // Invalid UUID
      assert.throws(() =>
        chatSchema.parse({
          message: 'دەستپێک',
          conversationId: 'not-a-valid-uuid',
        })
      );
    });

    await test('conversationIdParamSchema enforces strict UUID parameter', () => {
      const valid = conversationIdParamSchema.parse({
        id: '123e4567-e89b-12d3-a456-426614174000',
      });
      assert.strictEqual(valid.id, '123e4567-e89b-12d3-a456-426614174000');

      assert.throws(() => conversationIdParamSchema.parse({ id: 'invalid-id' }));
    });

    await test('listConversationsSchema validates and bounds limit and offset', () => {
      const parsed = listConversationsSchema.parse({ limit: '10', offset: '5' });
      assert.strictEqual(parsed.limit, 10);
      assert.strictEqual(parsed.offset, 5);

      // Max clamp 50
      const clamped = listConversationsSchema.parse({ limit: '500' });
      assert.strictEqual(clamped.limit, 50);

      // Default values
      const defaults = listConversationsSchema.parse({});
      assert.strictEqual(defaults.limit, 20);
      assert.strictEqual(defaults.offset, 0);
    });

    // ─── 3. AI Provider Abstraction & Dynamic Configuration ───
    await test('aiOrchestrator registers multiple AI providers without hardcoding', () => {
      const providers = aiOrchestrator.getAvailableProviders();
      assert.ok(Array.isArray(providers));
      assert.ok(providers.includes('google'), 'Expected google provider registered');
      assert.ok(providers.includes('openai'), 'Expected openai provider registered');
      assert.ok(providers.includes('anthropic'), 'Expected anthropic provider registered');
    });

    await test('aiOrchestrator retrieves registered provider instance', () => {
      const google = aiOrchestrator.getProvider('google');
      assert.ok(google, 'Google provider should be retrieved');
      assert.strictEqual(google?.name, 'google');

      const openai = aiOrchestrator.getProvider('openai');
      assert.ok(openai, 'OpenAI provider should be retrieved');
      assert.strictEqual(openai?.name, 'openai');

      const anthropic = aiOrchestrator.getProvider('anthropic');
      assert.ok(anthropic, 'Anthropic provider should be retrieved');
      assert.strictEqual(anthropic?.name, 'anthropic');
    });

    // ─── 4. Cost Tracking & Estimation Algorithms ───
    await test('calculateModelCost correctly computes token pricing for Gemini models', () => {
      // gemini-2.5-flash: $0.15/1M prompt, $0.60/1M completion
      const cost = calculateModelCost('gemini-2.5-flash', 1000, 1000);
      // (1000 * 0.15 / 1e6) + (1000 * 0.60 / 1e6) = 0.00015 + 0.0006 = 0.00075
      assert.strictEqual(cost, 0.00075);
    });

    await test('calculateModelCost correctly computes token pricing for OpenAI models', () => {
      // gpt-4o-mini: $0.15/1M prompt, $0.60/1M completion
      const cost = calculateModelCost('gpt-4o-mini', 2000, 500);
      // (2000 * 0.15 / 1e6) + (500 * 0.60 / 1e6) = 0.0003 + 0.0003 = 0.0006
      assert.strictEqual(cost, 0.0006);
    });

    await test('calculateModelCost correctly computes token pricing for Anthropic models', () => {
      // claude-3-5-haiku: $0.80/1M prompt, $4.00/1M completion
      const cost = calculateModelCost('claude-3-5-haiku', 1000, 1000);
      // (1000 * 0.80 / 1e6) + (1000 * 4.00 / 1e6) = 0.0008 + 0.004 = 0.0048
      assert.strictEqual(cost, 0.0048);
    });

    // ─── 5. System Prompt & Academic Instruction Verification ───
    await test('Academic tutor system instruction enforces concise academic guidelines', () => {
      const instruction = aiGateway.getSystemInstruction();
      assert.ok(instruction.includes('مامۆستای ژیری زانکۆ'));
      assert.ok(instruction.includes('GREETING'));
      assert.ok(instruction.includes('NO PREAMBLE'));
      assert.ok(instruction.includes('LANGUAGE MATCHING'));
    });
  } finally {
    server.close();
  }

  console.log(`\n=========================================`);
  console.log(`🏁 AI Chat Suite: ${passed}/${total} tests passed`);
  console.log(`=========================================\n`);
}

// Direct execution when run via tsx
if (process.argv[1]?.endsWith('ai_chat.test.ts') || process.argv[1]?.endsWith('ai_chat.test.js')) {
  runAiChatTests().catch((err) => {
    console.error('AI Chat test suite failed:', err);
    process.exit(1);
  });
}
