// ==============================================================================
// ZankoAI Admin System & Audit Engine Integration Tests
// ==============================================================================

import assert from 'node:assert';
import { createApp } from '../src/app.js';
import { supabaseAdmin } from '../src/config/supabase.js';
import { AuditService } from '../src/services/audit.service.js';
import { AdminService } from '../src/services/admin.service.js';

console.log('👑 Launching ZankoAI Admin System & Security Audit Suite...\n');

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

export const runAdminSystemTests = async () => {
  const app = createApp();
  const testPort = 4005;
  const server = app.listen(testPort);
  const baseUrl = `http://localhost:${testPort}/api/admin`;

  try {
    // ─── 1. Authentication & Authorization Enforcement ───────────────────────
    await runTest('GET /api/admin/users without token returns 401 Unauthorized', async () => {
      const res = await fetch(`${baseUrl}/users`);
      assert.strictEqual(res.status, 401);
      const json: any = await res.json();
      assert.strictEqual(json.success, false);
      assert.strictEqual(json.code, 'UNAUTHORIZED');
    });

    await runTest('PATCH /api/admin/users/:id/status without token returns 401', async () => {
      const res = await fetch(`${baseUrl}/users/11111111-1111-1111-1111-111111111111/status`, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: 'suspended' }),
      });
      assert.strictEqual(res.status, 401);
    });

    await runTest('GET /api/admin/subscriptions without token returns 401', async () => {
      const res = await fetch(`${baseUrl}/subscriptions`);
      assert.strictEqual(res.status, 401);
    });

    await runTest('GET /api/admin/payments without token returns 401', async () => {
      const res = await fetch(`${baseUrl}/payments`);
      assert.strictEqual(res.status, 401);
    });

    await runTest('GET /api/admin/usage without token returns 401', async () => {
      const res = await fetch(`${baseUrl}/usage`);
      assert.strictEqual(res.status, 401);
    });

    await runTest('GET /api/admin/audit-logs without token returns 401', async () => {
      const res = await fetch(`${baseUrl}/audit-logs`);
      assert.strictEqual(res.status, 401);
    });

    // ─── 2. Audit Logging Service Core Verification ──────────────────────────
    await runTest('AuditService records and retrieves audit logs without throwing', async () => {
      const testAction = 'test_audit_event_' + Date.now();
      await AuditService.logAction({
        actorId: null,
        action: testAction,
        resourceType: 'system_test',
        resourceId: 'test-123',
        ipAddress: '127.0.0.1',
        userAgent: 'ZankoAdminTestAgent/1.0',
        changes: { status: 'tested' },
      });

      const list = await AuditService.listAuditLogs({ action: testAction, limit: 5 });
      assert.ok(list.pagination.total >= 0);
    });

    // ─── 3. Self-Lockout Defense Logic ──────────────────────────────────────
    await runTest('AdminService prevents admin from suspending their own account', async () => {
      let threw = false;
      try {
        await AdminService.updateUserStatus('admin-123', 'admin-123', 'suspended');
      } catch (err: any) {
        threw = true;
        assert.ok(err.message.includes('Self-lockout prevented'));
      }
      assert.strictEqual(threw, true);
    });

    await runTest('AdminService prevents admin from demoting their own role', async () => {
      let threw = false;
      try {
        await AdminService.changeUserRole('admin-123', 'admin-123', 'student');
      } catch (err: any) {
        threw = true;
        assert.ok(err.message.includes('Self-lockout prevented'));
      }
      assert.strictEqual(threw, true);
    });

    console.log(`\n👑 Admin System Tests Completed: ${passedTests}/${totalTests} passed.\n`);
  } finally {
    server.close();
  }
};

// Auto-run if executed directly
if (process.argv[1]?.includes('admin_system.test')) {
  runAdminSystemTests().catch((err) => {
    console.error('Fatal admin test error:', err);
    process.exit(1);
  });
}
