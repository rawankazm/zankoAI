import assert from 'node:assert';
import { createApp } from '../src/app.js';
import { requireRole } from '../src/middleware/requireRole.js';
import { requireSubscription } from '../src/middleware/requireSubscription.js';
import { checkUsage } from '../src/middleware/checkUsage.js';
import { UserProfile } from '../src/types/user.types.js';

// Setup test environment
process.env.NODE_ENV = 'test';
process.env.PORT = '4001';

console.log('🧪 Starting ZankoAI Backend Test Suite...\n');

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
  }
};

const main = async () => {
  const app = createApp();
  const server = app.listen(4001);

  try {
    // ─── 1. Health & Liveness Tests ───
    await runTest('GET /api/health returns 200 and status ok', async () => {
      const res = await fetch('http://localhost:4001/api/health');
      assert.strictEqual(res.status, 200);
      const json: any = await res.json();
      assert.strictEqual(json.success, true);
      assert.strictEqual(json.data.status, 'ok');
      assert.strictEqual(json.data.service, 'zanko-backend');
    });

    await runTest('GET /api/ready returns dependencies status', async () => {
      const res = await fetch('http://localhost:4001/api/ready');
      assert.ok([200, 503].includes(res.status));
      const json: any = await res.json();
      assert.ok('dependencies' in json);
      assert.ok('supabaseDatabase' in json.dependencies);
      assert.ok('redisCache' in json.dependencies);
    });

    await runTest('GET /health (root level probe) returns 200', async () => {
      const res = await fetch('http://localhost:4001/health');
      assert.strictEqual(res.status, 200);
      const json: any = await res.json();
      assert.strictEqual(json.success, true);
    });

    // ─── 2. Authentication Rejection Tests ───
    await runTest('Protected route rejects missing Authorization header with 401', async () => {
      const res = await fetch('http://localhost:4001/api/auth/profile');
      assert.strictEqual(res.status, 401);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'UNAUTHORIZED');
    });

    await runTest('Protected route rejects invalid Bearer token with 401', async () => {
      const res = await fetch('http://localhost:4001/api/auth/profile', {
        headers: {
          Authorization: 'Bearer invalid-token-12345',
        },
      });
      assert.strictEqual(res.status, 401);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'UNAUTHORIZED');
    });

    // ─── 3. Role-Based Access Control (RBAC) Middleware Tests ───
    await runTest('requireRole allows authorized roles and rejects unauthorized roles', () => {
      const teacherMiddleware = requireRole(['teacher', 'admin']);

      // Case A: Student tries to access
      const studentReq: any = {
        profile: { role: 'student' } as UserProfile,
      };
      let studentError: any = null;
      teacherMiddleware(studentReq, {} as any, (err?: any) => {
        studentError = err;
      });
      assert.ok(studentError, 'Expected student access to be blocked');
      assert.strictEqual(studentError.statusCode, 403);
      assert.strictEqual(studentError.code, 'FORBIDDEN');

      // Case B: Teacher accesses
      const teacherReq: any = {
        profile: { role: 'teacher' } as UserProfile,
      };
      let teacherError: any = null;
      teacherMiddleware(teacherReq, {} as any, (err?: any) => {
        teacherError = err;
      });
      assert.strictEqual(teacherError, undefined, 'Teacher should be allowed');

      // Case C: Admin accesses
      const adminReq: any = {
        profile: { role: 'admin' } as UserProfile,
      };
      let adminError: any = null;
      teacherMiddleware(adminReq, {} as any, (err?: any) => {
        adminError = err;
      });
      assert.strictEqual(adminError, undefined, 'Admin should be allowed');
    });

    // ─── 4. Subscription & VIP Guard Tests ───
    await runTest('requireSubscription blocks free users and permits premium/VIP users', () => {
      const subMiddleware = requireSubscription(['premium'], true);

      // Case A: Free user without VIP
      const freeReq: any = {
        profile: { plan: 'free', is_vip: false, role: 'student', vip_status: 'none' } as UserProfile,
      };
      let freeError: any = null;
      subMiddleware(freeReq, {} as any, (err?: any) => {
        freeError = err;
      });
      assert.ok(freeError, 'Free user should be blocked');
      assert.strictEqual(freeError.statusCode, 403);

      // Case B: VIP student user
      const vipReq: any = {
        profile: { plan: 'free', is_vip: true, role: 'student', vip_status: 'active' } as UserProfile,
      };
      let vipError: any = null;
      subMiddleware(vipReq, {} as any, (err?: any) => {
        vipError = err;
      });
      assert.strictEqual(vipError, undefined, 'VIP member should be granted access');

      // Case C: Admin user bypass
      const adminReq: any = {
        profile: { plan: 'free', is_vip: false, role: 'admin', vip_status: 'none' } as UserProfile,
      };
      let adminError: any = null;
      subMiddleware(adminReq, {} as any, (err?: any) => {
        adminError = err;
      });
      assert.strictEqual(adminError, undefined, 'Admin should always bypass subscription requirements');
    });

    // ─── 5. 404 Route Handling ───
    await runTest('Unknown endpoint returns 404 Not Found error JSON', async () => {
      const res = await fetch('http://localhost:4001/api/unknown-endpoint-xyz');
      assert.strictEqual(res.status, 404);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.error.code, 'NOT_FOUND');
    });
  } finally {
    server.close();
  }

  console.log(`\n=========================================`);
  console.log(`🏁 Core Suite: ${passedTests}/${totalTests} tests passed`);
  console.log(`=========================================\n`);

  // Run Integration Suite
  console.log('🚀 Launching Integration Data API Suite...\n');
  await import('./integration_data_api.test.js').catch(async () => {
    // Fallback for tsx direct execution
    await import('./integration_data_api.test.ts' as any);
  });

  // Run Security Hardening Suite
  console.log('🛡️ Launching Security Hardening Suite...\n');
  await import('./security.test.js').catch(async () => {
    await import('./security.test.ts' as any);
  });

  // Run Supabase Storage Security Suite
  console.log('📦 Launching Supabase Storage Security Suite...\n');
  await import('./storage.test.js').catch(async () => {
    await import('./storage.test.ts' as any);
  });

  // Run Plan Limits and Usage System Suite
  console.log('💎 Launching Plan Limits & Usage System Suite...\n');
  await import('./usage_limits.test.js').catch(async () => {
    await import('./usage_limits.test.ts' as any);
  });

  // Run MAU Analytics & Supabase Cost Control Suite
  console.log('📊 Launching MAU Analytics & Cost Control Suite...\n');
  await import('./mau_analytics.test.js').catch(async () => {
    await import('./mau_analytics.test.ts' as any);
  });
};

main().catch((err) => {
  console.error('Test runner execution failed:', err);
  process.exit(1);
});
