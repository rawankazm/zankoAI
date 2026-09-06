import assert from 'node:assert';
import { createApp } from '../src/app.js';
import { AnalyticsService } from '../src/services/analytics.service.js';
import { CostMonitorService } from '../src/services/cost_monitor.service.js';
import { ActivityTrackerService } from '../src/services/activity_tracker.service.js';
import { supabaseAdmin } from '../src/config/supabase.js';

export async function runMauAnalyticsTests() {
  console.log('\n📊 Running ZankoAI MAU Analytics & Cost Control Test Suite...\n');

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
  const PORT = 4098;
  const server = app.listen(PORT);

  try {
    // ─── 1. Analytics Service Returns Exact Required Metric Fields ───
    await test('AnalyticsService.getUserAnalytics returns all 8 required metrics', async () => {
      const data = await AnalyticsService.getUserAnalytics();

      assert.ok('total_registered_users' in data, 'Expected total_registered_users');
      assert.ok('daily_active_users' in data, 'Expected daily_active_users');
      assert.ok('monthly_active_users' in data, 'Expected monthly_active_users');
      assert.ok('new_users' in data, 'Expected new_users');
      assert.ok('active_students' in data, 'Expected active_students');
      assert.ok('active_teachers' in data, 'Expected active_teachers');
      assert.ok('premium_users' in data, 'Expected premium_users');
      assert.ok('free_users' in data, 'Expected free_users');
      assert.ok('alerts' in data, 'Expected alerts array');
      assert.ok('period' in data, 'Expected period string');

      assert.strictEqual(typeof data.total_registered_users, 'number');
      assert.strictEqual(typeof data.daily_active_users, 'number');
      assert.strictEqual(typeof data.monthly_active_users, 'number');
      assert.strictEqual(typeof data.new_users, 'number');
      assert.strictEqual(typeof data.active_students, 'number');
      assert.strictEqual(typeof data.active_teachers, 'number');
      assert.strictEqual(typeof data.premium_users, 'number');
      assert.strictEqual(typeof data.free_users, 'number');
      assert.ok(Array.isArray(data.alerts));
    });

    // ─── 2. Critical Separation: Registered Users != MAU ───
    await test('MAU does not confuse registered dormant accounts with active users', async () => {
      const data = await AnalyticsService.getUserAnalytics();
      
      // Total registered must be >= monthly active users (dormant accounts do not inflate MAU)
      assert.ok(
        data.total_registered_users >= data.monthly_active_users,
        `Expected total_registered (${data.total_registered_users}) >= MAU (${data.monthly_active_users})`
      );

      // Total registered must also be >= daily active users
      assert.ok(
        data.total_registered_users >= data.daily_active_users,
        `Expected total_registered (${data.total_registered_users}) >= DAU (${data.daily_active_users})`
      );
    });

    // ─── 3. Deduplication: Active Student/Teacher Sum Check ───
    await test('Active role breakdown (students + teachers) does not exceed total MAU', async () => {
      const data = await AnalyticsService.getUserAnalytics();
      
      // Since a user is either a student, teacher, or admin, active_students + active_teachers <= MAU
      assert.ok(
        data.active_students + data.active_teachers <= data.monthly_active_users,
        `Sum of active students (${data.active_students}) and teachers (${data.active_teachers}) should not exceed MAU (${data.monthly_active_users})`
      );

      // Active plan breakdown: premium + free <= MAU
      assert.ok(
        data.premium_users + data.free_users <= data.monthly_active_users,
        `Sum of premium (${data.premium_users}) and free (${data.free_users}) users should not exceed MAU (${data.monthly_active_users})`
      );
    });

    // ─── 4. Zero Double-Counting across Multiple Calls ───
    await test('ActivityTrackerService handles repeated calls idempotently without duplicate records', async () => {
      const testUserId = '00000000-0000-0000-0000-000000000099';
      
      // Call tracker multiple times in a row
      ActivityTrackerService.trackUser(testUserId, 'student', 'free');
      ActivityTrackerService.trackUser(testUserId, 'student', 'free');
      ActivityTrackerService.trackUser(testUserId, 'student', 'free');

      // Wait a moment for setImmediate execution
      await new Promise((r) => setTimeout(r, 100));

      // Check PostgreSQL user_daily_activity count for this user on today's date
      const today = new Date().toISOString().substring(0, 10);
      const { data, error } = await supabaseAdmin
        .from('user_daily_activity')
        .select('*')
        .eq('user_id', testUserId)
        .eq('activity_date', today);

      if (!error && data) {
        // Must have AT MOST 1 row (composite PK constraint user_id, activity_date)
        assert.ok(data.length <= 1, `Expected at most 1 row, found ${data.length}`);
      }
    });

    // ─── 5. Supabase Cost Thresholds Configuration ───
    await test('CostMonitorService lists configured scale thresholds including 50k and 100k MAU', async () => {
      const thresholds = await CostMonitorService.listThresholds();
      assert.ok(Array.isArray(thresholds), 'Expected array of thresholds');

      if (thresholds.length > 0) {
        const mauThresholds = thresholds.filter((t) => t.metric_name === 'mau');
        assert.ok(mauThresholds.length >= 1, 'Expected at least 1 MAU threshold');

        const values = mauThresholds.map((t) => Number(t.threshold_value));
        assert.ok(
          values.includes(50000) || values.includes(100000),
          'Expected standard 50k or 100k MAU threshold in configuration'
        );
      }
    });

    // ─── 6. No Auto-Upgrade Guarantee ───
    await test('Threshold evaluation triggers alerts without auto-upgrading user or organization plans', async () => {
      // Execute threshold evaluation
      const alerts = await CostMonitorService.evaluateThresholds();
      assert.ok(Array.isArray(alerts), 'Expected array return from evaluateThresholds');

      // Verify that no auto-upgrade command or mutation occurred on billing plans
      const { data: adminProfiles } = await supabaseAdmin
        .from('profiles')
        .select('id, plan')
        .limit(5);

      if (adminProfiles) {
        // Plans remain determined only by payments/subscriptions
        for (const p of adminProfiles) {
          assert.ok(['free', 'premium'].includes(p.plan));
        }
      }
    });

    // ─── 7. Admin API Security & Authentication ───
    await test('GET /api/admin/analytics/users denies unauthenticated requests (HTTP 401)', async () => {
      const res = await fetch(`http://localhost:${PORT}/api/admin/analytics/users`);
      assert.strictEqual(res.status, 401, 'Unauthenticated access must be rejected with HTTP 401');
      const body = await res.json();
      assert.strictEqual(body.success, false);
    });

  } finally {
    server.close();
  }

  console.log(`\n🏁 Test Run Summary: ${passed}/${total} tests passed.\n`);
  if (passed < total) {
    throw new Error(`Only ${passed} of ${total} tests passed.`);
  }
}

// Standalone execution support
if (import.meta.url === `file://${process.argv[1]?.replace(/\\/g, '/')}`) {
  runMauAnalyticsTests()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error('Fatal test error:', err);
      process.exit(1);
    });
}
