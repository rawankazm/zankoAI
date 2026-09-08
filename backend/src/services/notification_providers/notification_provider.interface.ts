// ==============================================================================
// ZankoAI Notification Provider Interface — Decoupled Push Notification Contract
// ==============================================================================

export type NotificationPlatform = 'android' | 'ios' | 'web';

export interface PushNotificationPayload {
  /** Target device tokens */
  tokens: string[];
  /** Notification title */
  title: string;
  /** Notification body content */
  body: string;
  /** Standard notification category */
  type: string;
  /** Arbitrary JSON payload data */
  data?: Record<string, any>;
  /** App badge number (iOS/Android) */
  badge?: number;
  /** Push priority: 'normal' | 'high' */
  priority?: 'normal' | 'high';
}

export interface FailedTokenResult {
  token: string;
  error: string;
  /**
   * When true, this token is permanently dead / unregistered / expired,
   * prompting ZankoAI to automatically deactivate or remove it from device registry.
   */
  isInvalidToken: boolean;
}

export interface PushDeliveryReceipt {
  /** Name of the provider that handled delivery (e.g., 'fcm', 'mock', 'apns') */
  provider: string;
  /** Successfully reached tokens */
  successfulTokens: string[];
  /** Failed tokens with error reasons and invalid token markers */
  failedTokens: FailedTokenResult[];
  /** Message ID or batch ID if available from vendor */
  messageId?: string;
}

export interface INotificationProvider {
  /** Identifier of the notification provider */
  readonly name: string;

  /**
   * Dispatches push notifications to one or many device tokens.
   * Must never throw unhandled exceptions; failures must be encapsulated in PushDeliveryReceipt.
   */
  send(payload: PushNotificationPayload): Promise<PushDeliveryReceipt>;

  /**
   * Indicates whether the provider has the required configuration/credentials
   * to send live notifications.
   */
  isConfigured(): boolean;
}
