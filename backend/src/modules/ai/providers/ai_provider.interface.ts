export interface AIMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface AICompletionOptions {
  messages: AIMessage[];
  systemInstruction?: string;
  temperature?: number;
  maxTokens?: number;
  timeoutMs?: number;
  signal?: AbortSignal;
}

export interface AICompletionResult {
  text: string;
  provider: 'google' | 'openai' | 'anthropic' | string;
  model: string;
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  estimatedCost: number; // in USD ($)
}

export interface AIProvider {
  readonly name: 'google' | 'openai' | 'anthropic' | string;
  readonly defaultModel: string;
  generateCompletion(options: AICompletionOptions): Promise<AICompletionResult>;
}

/**
 * Standard Token Pricing Table (USD per 1 Million Tokens)
 * Used to calculate accurate server-side cost tracking.
 */
export const MODEL_PRICING: Record<string, { promptPricePerMillion: number; completionPricePerMillion: number }> = {
  // Google Gemini Pricing
  'gemini-3.5-flash-lite': { promptPricePerMillion: 0.075, completionPricePerMillion: 0.30 },
  'gemini-3.5-flash': { promptPricePerMillion: 0.075, completionPricePerMillion: 0.30 },
  'gemini-3.6-flash': { promptPricePerMillion: 0.075, completionPricePerMillion: 0.30 },
  'gemini-2.5-flash': { promptPricePerMillion: 0.075, completionPricePerMillion: 0.30 },
  'gemini-1.5-flash': { promptPricePerMillion: 0.075, completionPricePerMillion: 0.30 },
  'gemini-1.5-pro': { promptPricePerMillion: 1.25, completionPricePerMillion: 5.00 },
  'gemini-3.8-flash': { promptPricePerMillion: 0.075, completionPricePerMillion: 0.30 },

  // OpenAI Pricing
  'gpt-4o-mini': { promptPricePerMillion: 0.15, completionPricePerMillion: 0.60 },
  'gpt-4o': { promptPricePerMillion: 2.50, completionPricePerMillion: 10.00 },
  'gpt-3.5-turbo': { promptPricePerMillion: 0.50, completionPricePerMillion: 1.50 },

  // Anthropic Claude Pricing
  'claude-3-5-haiku-20241022': { promptPricePerMillion: 0.80, completionPricePerMillion: 4.00 },
  'claude-3-5-sonnet-20241022': { promptPricePerMillion: 3.00, completionPricePerMillion: 15.00 },
  'claude-3-haiku-20240307': { promptPricePerMillion: 0.25, completionPricePerMillion: 1.25 },
};

/**
 * Computes the estimated USD cost of an AI inference based on tokens used.
 */
export function calculateModelCost(model: string, promptTokens: number, completionTokens: number): number {
  const pricing = MODEL_PRICING[model] || { promptPricePerMillion: 0.10, completionPricePerMillion: 0.40 };
  const promptCost = (promptTokens / 1_000_000) * pricing.promptPricePerMillion;
  const completionCost = (completionTokens / 1_000_000) * pricing.completionPricePerMillion;
  const totalCost = promptCost + completionCost;
  // Round to 6 decimal places ($0.000001 precision)
  return Math.round(totalCost * 1_000_000) / 1_000_000;
}
