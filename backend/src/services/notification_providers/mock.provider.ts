// ==============================================================================
// ZankoAI Mock Notification Provider — Testing & Development Implementation
// ==============================================================================

import {
  INotificationProvider,
  PushNotificationPayload,
  PushDeliveryReceipt,
  FailedTokenResult,
} from './notification_provider.interface.js';

export class MockNotificationProvider implements INotificationProvider {
  readonly name = 'mock';

  /** History of dispatched notifications for test assertions */
  public sentHistory: PushNotificationPayload[] = [];

  /** Simulated tokens that will trigger invalid token errors */
  public invalidTokens: Set<string> = new Set(['invalid_token', 'stale_token_dead']);

  isConfigured(): boolean {
    return true;
  }

  clearHistory(): void {
    this.sentHistory = [];
  }

  setInvalidToken(token: string): void {
    this.invalidTokens.add(token);
  }

  removeInvalidToken(token: string): void {
    this.invalidTokens.delete(token);
  }

  async send(payload: PushNotificationPayload): Promise<PushDeliveryReceipt> {
    this.sentHistory.push({ ...payload });

    const successfulTokens: string[] = [];
    const failedTokens: FailedTokenResult[] = [];

    for (const token of payload.tokens) {
      if (this.invalidTokens.has(token) || token.includes('invalid') || token.includes('expired')) {
        failedTokens.push({
          token,
          error: 'messaging/registration-token-not-registered',
          isInvalidToken: true,
        });
      } else {
        successfulTokens.push(token);
      }
    }

    return {
      provider: this.name,
      successfulTokens,
      failedTokens,
      messageId: `mock_msg_${Date.now()}_${Math.random().toString(36).substring(7)}`,
    };
  }
}
