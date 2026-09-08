// ==============================================================================
// ZankoAI Notification Provider Registry & Factory
// ==============================================================================

import { INotificationProvider } from './notification_provider.interface.js';
import { FcmNotificationProvider } from './fcm.provider.js';
import { MockNotificationProvider } from './mock.provider.js';

export * from './notification_provider.interface.js';
export * from './fcm.provider.js';
export * from './mock.provider.js';

class NotificationProviderRegistry {
  private static instance: NotificationProviderRegistry;
  private providers: Map<string, INotificationProvider> = new Map();
  private activeProviderName: string = 'fcm';

  private constructor() {
    // Register default built-in providers
    this.registerProvider(new FcmNotificationProvider());
    this.registerProvider(new MockNotificationProvider());

    // If NODE_ENV is test, default to mock provider
    if (process.env.NODE_ENV === 'test') {
      this.activeProviderName = 'mock';
    }
  }

  public static getInstance(): NotificationProviderRegistry {
    if (!NotificationProviderRegistry.instance) {
      NotificationProviderRegistry.instance = new NotificationProviderRegistry();
    }
    return NotificationProviderRegistry.instance;
  }

  public registerProvider(provider: INotificationProvider): void {
    this.providers.set(provider.name.toLowerCase(), provider);
  }

  public setActiveProvider(name: string): void {
    const key = name.toLowerCase();
    if (!this.providers.has(key)) {
      throw new Error(`Notification provider '${name}' is not registered`);
    }
    this.activeProviderName = key;
  }

  public getProvider(name?: string): INotificationProvider {
    const key = (name || this.activeProviderName).toLowerCase();
    const provider = this.providers.get(key);
    if (!provider) {
      // Fallback to first available provider or mock
      const fallback = this.providers.get('mock') || this.providers.values().next().value;
      if (!fallback) {
        throw new Error(`No notification providers registered`);
      }
      return fallback;
    }
    return provider;
  }

  public getMockProvider(): MockNotificationProvider {
    return this.getProvider('mock') as MockNotificationProvider;
  }
}

export const providerRegistry = NotificationProviderRegistry.getInstance();
