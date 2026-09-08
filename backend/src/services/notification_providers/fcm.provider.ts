// ==============================================================================
// ZankoAI Firebase Cloud Messaging (FCM) Push Notification Provider
// ==============================================================================

import axios from 'axios';
import { logger } from '../../config/logger.js';
import {
  INotificationProvider,
  PushNotificationPayload,
  PushDeliveryReceipt,
  FailedTokenResult,
} from './notification_provider.interface.js';

export class FcmNotificationProvider implements INotificationProvider {
  readonly name = 'fcm';

  private readonly serverKey: string | undefined;
  private readonly projectId: string | undefined;

  constructor() {
    this.serverKey = process.env.FCM_SERVER_KEY || process.env.FIREBASE_SERVER_KEY;
    this.projectId = process.env.FIREBASE_PROJECT_ID || process.env.GCP_PROJECT_ID;
  }

  isConfigured(): boolean {
    return Boolean(this.serverKey || this.projectId);
  }

  async send(payload: PushNotificationPayload): Promise<PushDeliveryReceipt> {
    const { tokens, title, body, data, priority } = payload;

    if (!tokens || tokens.length === 0) {
      return {
        provider: this.name,
        successfulTokens: [],
        failedTokens: [],
      };
    }

    // If FCM is not configured with live credentials (e.g. in test / local dev),
    // emulate delivery while validating token formats.
    if (!this.isConfigured()) {
      logger.warn(
        `[FcmProvider] FCM credentials not configured. Simulating delivery for ${tokens.length} token(s).`
      );

      const successfulTokens: string[] = [];
      const failedTokens: FailedTokenResult[] = [];

      for (const token of tokens) {
        // Detect mock invalid tokens for testing
        if (
          token.includes('invalid') ||
          token.includes('unregistered') ||
          token.trim().length < 10
        ) {
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
        messageId: `mock_fcm_${Date.now()}`,
      };
    }

    // Live FCM HTTP dispatch
    const successfulTokens: string[] = [];
    const failedTokens: FailedTokenResult[] = [];

    // Dispatch per token or in batches
    for (const token of tokens) {
      try {
        const fcmPayload = {
          to: token,
          notification: {
            title,
            body,
            sound: 'default',
          },
          data: {
            ...data,
            type: payload.type,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          priority: priority === 'high' ? 'high' : 'normal',
        };

        const response = await axios.post(
          'https://fcm.googleapis.com/fcm/send',
          fcmPayload,
          {
            headers: {
              'Content-Type': 'application/json',
              Authorization: `key=${this.serverKey}`,
            },
            timeout: 8000,
          }
        );

        if (response.data?.failure > 0 && response.data?.results?.[0]?.error) {
          const rawErr = response.data.results[0].error;
          const isInvalid = this.isTokenInvalidError(rawErr);
          failedTokens.push({
            token,
            error: rawErr,
            isInvalidToken: isInvalid,
          });
        } else {
          successfulTokens.push(token);
        }
      } catch (err: any) {
        const errorMsg = err.response?.data?.error || err.message || 'FCM dispatch error';
        const isInvalid =
          err.response?.status === 404 ||
          err.response?.status === 410 ||
          this.isTokenInvalidError(errorMsg);

        failedTokens.push({
          token,
          error: String(errorMsg),
          isInvalidToken: isInvalid,
        });
      }
    }

    logger.info(
      `[FcmProvider] Delivery summary: ${successfulTokens.length} succeeded, ${failedTokens.length} failed.`
    );

    return {
      provider: this.name,
      successfulTokens,
      failedTokens,
      messageId: `fcm_${Date.now()}`,
    };
  }

  /**
   * Identifies whether an FCM error indicates the device token should be removed or deactivated.
   */
  private isTokenInvalidError(error: string): boolean {
    const lower = String(error).toLowerCase();
    return (
      lower.includes('notregistered') ||
      lower.includes('invalidregistration') ||
      lower.includes('unregistered') ||
      lower.includes('invalid_argument') ||
      lower.includes('registration-token-not-registered') ||
      lower.includes('invalid-registration-token') ||
      lower.includes('bad_token')
    );
  }
}
