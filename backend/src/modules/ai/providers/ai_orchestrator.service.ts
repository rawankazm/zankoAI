import { AIProvider, AICompletionOptions, AICompletionResult } from './ai_provider.interface.js';
import { GoogleAIProvider } from './google.provider.js';
import { OpenAIProvider } from './openai.provider.js';
import { AnthropicAIProvider } from './anthropic.provider.js';
import { env } from '../../../config/env.js';
import { logger } from '../../../config/logger.js';

export class AIOrchestratorService {
  private providers: Map<string, AIProvider> = new Map();

  constructor() {
    this.registerProviders();
  }

  private registerProviders() {
    this.providers.set('google', new GoogleAIProvider());
    this.providers.set('openai', new OpenAIProvider());
    this.providers.set('anthropic', new AnthropicAIProvider());
  }

  /**
   * Returns ordered list of providers to attempt, beginning with DEFAULT_AI_PROVIDER
   */
  private getProviderChain(): AIProvider[] {
    const defaultName = env.DEFAULT_AI_PROVIDER || 'google';
    const allNames = ['google', 'openai', 'anthropic'];

    // Put preferred provider first, followed by others
    const orderedNames = [defaultName, ...allNames.filter((n) => n !== defaultName)];

    const chain: AIProvider[] = [];
    for (const name of orderedNames) {
      const p = this.providers.get(name);
      if (p) chain.push(p);
    }
    return chain;
  }

  /**
   * Helper delay for exponential backoff retry
   */
  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Executes AI completion with automatic retry policy and multi-provider failover
   */
  async completeWithFailover(options: AICompletionOptions): Promise<AICompletionResult> {
    const chain = this.getProviderChain();
    const maxRetries = env.AI_MAX_RETRIES || 2;
    const errors: Array<{ provider: string; error: string }> = [];

    for (const provider of chain) {
      for (let attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          if (attempt > 0) {
            const backoffMs = Math.min(2000, 500 * Math.pow(2, attempt - 1));
            logger.info(`Retrying ${provider.name} (attempt ${attempt}/${maxRetries}) after ${backoffMs}ms...`);
            await this.sleep(backoffMs);
          }

          const result = await provider.generateCompletion(options);
          return result;
        } catch (err: any) {
          const errMsg = err?.message || String(err);
          const isRetryable =
            errMsg.includes('429') ||
            errMsg.includes('rate') ||
            errMsg.includes('timeout') ||
            errMsg.includes('500') ||
            errMsg.includes('503') ||
            errMsg.includes('network') ||
            errMsg.includes('socket');

          logger.warn(`Provider ${provider.name} failed on attempt ${attempt + 1}: ${errMsg}`);

          if (!isRetryable || attempt === maxRetries) {
            errors.push({ provider: provider.name, error: errMsg });
            break; // Move to next provider in failover chain
          }
        }
      }
      logger.warn(`Failing over from ${provider.name} to next configured provider...`);
    }

    logger.error('All AI providers in failover chain exhausted:', { errors });
    throw new Error('All configured AI providers are currently unavailable. Please try again in a few moments.');
  }
}

export const aiOrchestrator = new AIOrchestratorService();
