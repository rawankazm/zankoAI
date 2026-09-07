// ==============================================================================
// ZankoAI Payment Provider Registry
// ==============================================================================

import { PaymentProvider } from './payment_provider.interface.js';
import { QiCardPaymentProvider } from './qi_card_payment_provider.js';
import { ZainCashPaymentProvider } from './zaincash_payment_provider.js';
import { FastPayPaymentProvider } from './fastpay_payment_provider.js';
import { FibPaymentProvider } from './fib_payment_provider.js';
import { SandboxPaymentProvider } from './sandbox_payment_provider.js';

export * from './payment_provider.interface.js';
export * from './qi_card_payment_provider.js';
export * from './zaincash_payment_provider.js';
export * from './fastpay_payment_provider.js';
export * from './fib_payment_provider.js';
export * from './sandbox_payment_provider.js';

export class PaymentProviderRegistry {
  private static providers: Map<string, PaymentProvider> = new Map();

  static {
    this.register(new QiCardPaymentProvider());
    this.register(new ZainCashPaymentProvider());
    this.register(new FastPayPaymentProvider());
    this.register(new FibPaymentProvider());
    this.register(new SandboxPaymentProvider());
  }

  static register(provider: PaymentProvider): void {
    this.providers.set(provider.name.toLowerCase(), provider);
  }

  static get(name?: string): PaymentProvider {
    const requestedName = (name || process.env.PAYMENT_DEFAULT_PROVIDER || 'qi_card').toLowerCase();
    
    // Check if Sandbox simulation is globally forced
    if (process.env.PAYMENT_SANDBOX_MODE === 'true' && requestedName === 'sandbox') {
      return this.providers.get('sandbox')!;
    }

    const provider = this.providers.get(requestedName);
    if (!provider) {
      // Fallback to sandbox if requested provider not found in test environment
      if (process.env.NODE_ENV === 'test' || process.env.PAYMENT_SANDBOX_MODE === 'true') {
        return this.providers.get('sandbox')!;
      }
      throw new Error('Unsupported payment provider: ' + (name || requestedName));
    }
    return provider;
  }

  static has(name: string): boolean {
    return this.providers.has(name.toLowerCase());
  }

  static listSupported(): string[] {
    return Array.from(this.providers.keys());
  }
}
