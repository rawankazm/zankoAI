// ==============================================================================
// ZankoAI Payment Provider Registry
// ==============================================================================

import { PaymentProvider } from './payment_provider.interface.js';
import { FibPaymentProvider } from './fib_payment_provider.js';
import { FastPayPaymentProvider } from './fastpay_payment_provider.js';
import { ZainCashPaymentProvider } from './zaincash_payment_provider.js';

export * from './payment_provider.interface.js';
export * from './fib_payment_provider.js';
export * from './fastpay_payment_provider.js';
export * from './zaincash_payment_provider.js';

export class PaymentProviderRegistry {
  private static providers: Map<string, PaymentProvider> = new Map();

  static {
    this.register(new FibPaymentProvider());
    this.register(new FastPayPaymentProvider());
    this.register(new ZainCashPaymentProvider());
  }

  static register(provider: PaymentProvider): void {
    this.providers.set(provider.name.toLowerCase(), provider);
  }

  static get(name: string): PaymentProvider {
    const provider = this.providers.get(name.toLowerCase());
    if (!provider) {
      throw new Error('Unsupported payment provider: ' + name);
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
