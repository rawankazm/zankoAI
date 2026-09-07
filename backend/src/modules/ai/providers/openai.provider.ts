import OpenAI from 'openai';
import { AIProvider, AICompletionOptions, AICompletionResult, calculateModelCost } from './ai_provider.interface.js';
import { env } from '../../../config/env.js';
import { logger } from '../../../config/logger.js';

export class OpenAIProvider implements AIProvider {
  readonly name = 'openai' as const;
  readonly defaultModel: string;
  private client?: OpenAI;

  constructor(apiKey?: string, defaultModel?: string) {
    const key = apiKey || env.OPENAI_API_KEY;
    this.defaultModel = defaultModel || env.OPENAI_MODEL || 'gpt-4o-mini';
    if (key) {
      this.client = new OpenAI({ apiKey: key });
    }
  }

  async generateCompletion(options: AICompletionOptions): Promise<AICompletionResult> {
    if (!this.client) {
      throw new Error('OpenAI API Key is not configured.');
    }

    const model = this.defaultModel;
    const timeoutMs = options.timeoutMs || env.AI_TIMEOUT_MS || 30000;

    const messages: OpenAI.Chat.ChatCompletionMessageParam[] = [];

    // System instruction
    if (options.systemInstruction) {
      messages.push({ role: 'system', content: options.systemInstruction });
    }

    // Convert messages
    for (const m of options.messages) {
      messages.push({
        role: m.role as 'system' | 'user' | 'assistant',
        content: m.content,
      });
    }

    let timeoutHandle: any;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        reject(new Error(`OpenAI request timed out after ${timeoutMs}ms`));
      }, timeoutMs);
    });

    const apiCall = this.client.chat.completions.create({
      model,
      messages,
      temperature: options.temperature ?? 0.7,
      max_tokens: options.maxTokens,
    });

    try {
      const completion: any = await Promise.race([apiCall, timeoutPromise]);
      clearTimeout(timeoutHandle);

      const text = completion.choices[0]?.message?.content || '';
      const usage = completion.usage;

      const promptChars = options.messages.reduce((acc, m) => acc + m.content.length, 0);
      const promptTokens = usage?.prompt_tokens ?? Math.max(1, Math.ceil(promptChars / 4));
      const completionTokens = usage?.completion_tokens ?? Math.max(1, Math.ceil(text.length / 4));
      const totalTokens = usage?.total_tokens ?? (promptTokens + completionTokens);

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
      logger.warn(`OpenAI API call failed: ${err.message}`);
      throw err;
    }
  }
}
