import Anthropic from '@anthropic-ai/sdk';
import { AIProvider, AICompletionOptions, AICompletionResult, calculateModelCost } from './ai_provider.interface.js';
import { env } from '../../../config/env.js';
import { logger } from '../../../config/logger.js';

export class AnthropicAIProvider implements AIProvider {
  readonly name = 'anthropic' as const;
  readonly defaultModel: string;
  private client?: Anthropic;

  constructor(apiKey?: string, defaultModel?: string) {
    const key = apiKey || env.ANTHROPIC_API_KEY;
    this.defaultModel = defaultModel || env.ANTHROPIC_MODEL || 'claude-3-5-haiku-20241022';
    if (key) {
      this.client = new Anthropic({ apiKey: key });
    }
  }

  async generateCompletion(options: AICompletionOptions): Promise<AICompletionResult> {
    if (!this.client) {
      throw new Error('Anthropic API Key is not configured.');
    }

    const model = this.defaultModel;
    const timeoutMs = options.timeoutMs || env.AI_TIMEOUT_MS || 30000;

    // Filter messages for Anthropic (only user and assistant roles allowed)
    const messages: Anthropic.MessageParam[] = options.messages
      .filter((m) => m.role === 'user' || m.role === 'assistant')
      .map((m) => ({
        role: m.role as 'user' | 'assistant',
        content: m.content,
      }));

    // Ensure at least one message is present
    if (messages.length === 0) {
      messages.push({ role: 'user', content: 'سڵاو' });
    }

    const systemPrompt = options.systemInstruction || options.messages.find((m) => m.role === 'system')?.content;

    let timeoutHandle: any;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        reject(new Error(`Anthropic request timed out after ${timeoutMs}ms`));
      }, timeoutMs);
    });

    const apiCall = this.client.messages.create({
      model,
      messages,
      max_tokens: options.maxTokens || 4096,
      temperature: options.temperature ?? 0.7,
      ...(systemPrompt ? { system: systemPrompt } : {}),
    });

    try {
      const response: any = await Promise.race([apiCall, timeoutPromise]);
      clearTimeout(timeoutHandle);

      let text = '';
      if (Array.isArray(response.content)) {
        text = response.content
          .filter((block: any) => block.type === 'text')
          .map((block: any) => block.text)
          .join('\n');
      }

      const promptTokens = response.usage?.input_tokens ?? Math.max(1, Math.ceil(messages.reduce((a, b) => a + b.content.length, 0) / 4));
      const completionTokens = response.usage?.output_tokens ?? Math.max(1, Math.ceil(text.length / 4));
      const totalTokens = promptTokens + completionTokens;

      const estimatedCost = calculateModelCost(model, promptTokens, completionTokens);

      return {
        text,
        provider: this.name,
        model,
        promptTokens,
        completionTokens,
        totalTokens,
        estimatedCost,
      };
    } catch (err: any) {
      clearTimeout(timeoutHandle);
      logger.warn(`Anthropic API call failed: ${err.message}`);
      throw err;
    }
  }
}
