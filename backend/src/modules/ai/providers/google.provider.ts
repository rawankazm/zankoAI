import { GoogleGenAI } from '@google/genai';
import { AIProvider, AICompletionOptions, AICompletionResult, calculateModelCost } from './ai_provider.interface.js';
import { env } from '../../../config/env.js';
import { logger } from '../../../config/logger.js';

export class GoogleAIProvider implements AIProvider {
  readonly name = 'google' as const;
  readonly defaultModel: string;
  private client?: GoogleGenAI;

  constructor(apiKey?: string, defaultModel?: string) {
    const key = apiKey || env.GEMINI_API_KEY;
    this.defaultModel = defaultModel || env.GEMINI_MODEL || 'gemini-2.5-flash';
    if (key) {
      this.client = new GoogleGenAI({ apiKey: key });
    }
  }

  async generateCompletion(options: AICompletionOptions): Promise<AICompletionResult> {
    if (!this.client) {
      throw new Error('Google Gemini API Key is not configured.');
    }

    const model = this.defaultModel;
    const timeoutMs = options.timeoutMs || env.AI_TIMEOUT_MS || 30000;

    // Convert messages to Gemini format (user | model)
    const contents = options.messages
      .filter((m) => m.role !== 'system') // System message goes to config.systemInstruction
      .map((m) => ({
        role: m.role === 'assistant' ? 'model' : 'user',
        parts: [{ text: m.content }],
      }));

    // System prompt resolution
    const systemMessage = options.messages.find((m) => m.role === 'system')?.content;
    const systemInstruction = options.systemInstruction || systemMessage;

    // Execute with timeout safeguard
    const apiCall = this.client.models.generateContent({
      model,
      contents,
      config: {
        ...(systemInstruction ? { systemInstruction } : {}),
        temperature: options.temperature ?? 0.7,
        ...(options.maxTokens ? { maxOutputTokens: options.maxTokens } : {}),
      },
    });

    let timeoutHandle: any;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        reject(new Error(`Google Gemini request timed out after ${timeoutMs}ms`));
      }, timeoutMs);
    });

    try {
      const result: any = await Promise.race([apiCall, timeoutPromise]);
      clearTimeout(timeoutHandle);

      const text = result.text || '';
      const usageMeta = result.usageMetadata;

      // Token tracking with heuristic fallback if not returned
      const promptChars = options.messages.reduce((acc, m) => acc + m.content.length, 0);
      const promptTokens = usageMeta?.promptTokenCount ?? Math.max(1, Math.ceil(promptChars / 4));
      const completionTokens = usageMeta?.candidatesTokenCount ?? Math.max(1, Math.ceil(text.length / 4));
      const totalTokens = usageMeta?.totalTokenCount ?? (promptTokens + completionTokens);

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
      logger.warn(`Google Gemini API call failed: ${err.message}`);
      throw err;
    }
  }
}
