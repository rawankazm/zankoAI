// ==============================================================================
// ZankoAI Production Push Notification Architecture — Automated Test Suite
// ==============================================================================

import assert from 'node:assert';
import {
  providerRegistry,
  MockNotificationProvider,
  FcmNotificationProvider,
} from '../src/services/notification_providers/index.js';
import { NotificationService } from '../src/services/notification.service.js';
import { NotificationType } from '../src/types/calendar_notification.types.js';

console.log('🔔 Starting Production Push Notification Architecture Suite...\n');

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

export const runProductionNotificationTests = async () => {
  const mockProvider = new MockNotificationProvider();
  providerRegistry.registerProvider(mockProvider);
  providerRegistry.setActiveProvider('mock');

  // ─── 1. Provider Abstraction & Decoupling ──────────────────────────────────
  await runTest('Provider Abstraction: retrieves active provider and supports hot-swapping', () => {
    const active = providerRegistry.getProvider();
    assert.strictEqual(active.name, 'mock');

    const fcm = new FcmNotificationProvider();
    providerRegistry.registerProvider(fcm);
    providerRegistry.setActiveProvider('fcm');
    assert.strictEqual(providerRegistry.getProvider().name, 'fcm');

    // Switch back to mock for safe deterministic tests
    providerRegistry.setActiveProvider('mock');
    assert.strictEqual(providerRegistry.getProvider().name, 'mock');
  });

  await runTest('Provider Abstraction: dispatches push payload and returns structured receipt', async () => {
    mockProvider.clearHistory();

    const receipt = await mockProvider.send({
      tokens: ['token_device_alpha_123', 'token_device_beta_456'],
      title: 'Exam Reminder',
      body: 'Your Artificial Intelligence exam starts in 1 hour',
      type: 'exam_reminder',
      data: { courseId: 'crs-ai-101', leadMinutes: 60 },
      priority: 'high',
    });

    assert.strictEqual(receipt.provider, 'mock');
    assert.strictEqual(receipt.successfulTokens.length, 2);
    assert.strictEqual(receipt.failedTokens.length, 0);
    assert.strictEqual(mockProvider.sentHistory.length, 1);
    assert.strictEqual(mockProvider.sentHistory[0].title, 'Exam Reminder');
  });

  // ─── 2. Invalid Token Detection & Automatic Deactivation ───────────────────
  await runTest('Invalid Token Handling: provider identifies invalid/expired tokens for cleanup', async () => {
    mockProvider.clearHistory();
    mockProvider.setInvalidToken('dead_token_unregistered_789');

    const receipt = await mockProvider.send({
      tokens: ['valid_token_device_1', 'dead_token_unregistered_789', 'token_expired_999'],
      title: 'Assignment Deadline',
      body: 'Calculus assignment is due tonight at 23:59',
      type: 'assignment_reminder',
    });

    assert.strictEqual(receipt.successfulTokens.length, 1);
    assert.strictEqual(receipt.successfulTokens[0], 'valid_token_device_1');
    assert.strictEqual(receipt.failedTokens.length, 2);

    const invalidTokens = receipt.failedTokens.filter((f) => f.isInvalidToken);
    assert.strictEqual(invalidTokens.length, 2);
    assert.ok(invalidTokens.some((t) => t.token === 'dead_token_unregistered_789'));
  });

  // ─── 3. All 8 Required Production Notification Types ───────────────────────
  await runTest('Supported Categories: validates all 8 production notification types', () => {
    const requiredTypes: NotificationType[] = [
      'assignment_reminder',
      'exam_reminder',
      'announcement',
      'ai_job_completion',
      'subscription_activated',
      'subscription_expiring',
      'payment_result',
      'system_notification',
    ];

    const prefs = {
      user_id: 'usr-test-123',
      assignment_reminders: true,
      exam_reminders: true,
      teacher_announcements: true,
      announcements: true,
      ai_job_completion: true,
      subscription_notifications: true,
      payment_updates: true,
      system_notifications: true,
      push_enabled: true,
      email_enabled: false,
      lead_time_minutes: 60,
      timezone: 'Asia/Baghdad',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    for (const type of requiredTypes) {
      const isEnabled = NotificationService.isCategoryEnabled(prefs, type);
      assert.strictEqual(isEnabled, true, `Expected ${type} to be enabled by default`);
    }
  });

  // ─── 4. Notification Preferences Enforcement ───────────────────────────────
  await runTest('Notification Preferences: suppresses notifications when category is disabled', () => {
    const prefs = {
      user_id: 'usr-test-123',
      assignment_reminders: false, // Disabled
      exam_reminders: true,
      teacher_announcements: true,
      announcements: false, // Disabled
      ai_job_completion: false, // Disabled
      subscription_notifications: true,
      payment_updates: false, // Disabled
      system_notifications: true,
      push_enabled: true,
      email_enabled: false,
      lead_time_minutes: 60,
      timezone: 'Asia/Baghdad',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    assert.strictEqual(NotificationService.isCategoryEnabled(prefs, 'assignment_reminder'), false);
    assert.strictEqual(NotificationService.isCategoryEnabled(prefs, 'announcement'), false);
    assert.strictEqual(NotificationService.isCategoryEnabled(prefs, 'ai_job_completion'), false);
    assert.strictEqual(NotificationService.isCategoryEnabled(prefs, 'payment_result'), false);
    assert.strictEqual(NotificationService.isCategoryEnabled(prefs, 'exam_reminder'), true);
    assert.strictEqual(NotificationService.isCategoryEnabled(prefs, 'system_notification'), true);
    assert.strictEqual(NotificationService.isCategoryEnabled(prefs, 'subscription_activated'), true);
    assert.strictEqual(NotificationService.isCategoryEnabled(prefs, 'subscription_expiring'), true);
  });

  // ─── 5. Duplicate Prevention (Idempotency Key) ─────────────────────────────
  await runTest('Duplicate Prevention: rejects duplicate notifications sharing idempotency key', async () => {
    const idempotencyKey = `notif_dedup_test_${Date.now()}`;
    const testUserId = 'f47ac10b-58cc-4372-a567-0e02b2c3d479';

    // Mock first schedule
    const firstResult = await NotificationService.scheduleNotification({
      userId: testUserId,
      title: 'AI Job Finished',
      body: 'Your study guide PDF has finished generating',
      type: 'ai_job_completion',
      idempotencyKey,
    });

    assert.strictEqual(firstResult.scheduled, true);
    assert.ok(firstResult.jobId);

    // Attempt second schedule with the identical idempotencyKey
    const duplicateResult = await NotificationService.scheduleNotification({
      userId: testUserId,
      title: 'AI Job Finished (Duplicate)',
      body: 'Your study guide PDF has finished generating',
      type: 'ai_job_completion',
      idempotencyKey,
    });

    assert.strictEqual(duplicateResult.scheduled, false);
    assert.strictEqual(duplicateResult.reason, 'duplicate_idempotency_key');
  });

  // ─── 6. Multi-Device Registration & Lifecycle ──────────────────────────────
  await runTest('Device Registration: handles multi-device registration and unregistration', async () => {
    const userId = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

    // Device 1: Android phone
    const device1 = await NotificationService.registerDevice(userId, {
      fcm_token: 'mock_fcm_token_samsung_galaxy_s24',
      platform: 'android',
      device_id: 'sm-s928b',
      app_version: '1.2.0',
    });

    assert.ok(device1);
    assert.strictEqual(device1.is_active, true);
    assert.strictEqual(device1.platform, 'android');

    // Device 2: iOS iPad (multi-device)
    const device2 = await NotificationService.registerDevice(userId, {
      fcm_token: 'mock_fcm_token_ipad_pro_m4',
      platform: 'ios',
      device_id: 'ipad16,3',
      app_version: '1.2.0',
    });

    assert.ok(device2);
    assert.strictEqual(device2.is_active, true);
    assert.strictEqual(device2.platform, 'ios');

    // Unregister Device 1 (e.g. user logged out of Android phone)
    const deleteResult = await NotificationService.deleteDevice(userId, 'mock_fcm_token_samsung_galaxy_s24');
    assert.strictEqual(deleteResult.success, true);
  });

  console.log(`\n🎉 Production Push Notification Suite Completed: ${passedTests}/${totalTests} Passed.\n`);
};

runProductionNotificationTests().catch((err) => {
  console.error('Fatal test error in production_notification.test.ts:', err);
  process.exit(1);
});
