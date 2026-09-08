import { GoogleGenAI } from '@google/genai';
import { env } from '../../config/env.js';
import { logger } from '../../config/logger.js';
import { supabaseAdmin } from '../../config/supabase.js';
import { aiOrchestrator } from './providers/ai_orchestrator.service.js';
import { AIMessage, AICompletionResult } from './providers/ai_provider.interface.js';
import { AiCostGuardService } from '../../services/ai_cost_guard.service.js';

export interface ChatExecutionResult {
  text: string;
  provider: string;
  model: string;
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  estimatedCost: number;
  durationMs: number;
}

export class AiGatewayService {
  private geminiVisionClient?: GoogleGenAI;

  constructor() {
    if (env.GEMINI_API_KEY) {
      this.geminiVisionClient = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
    }
  }

  /**
   * System Instruction for ZankoAI Academic Tutor
   */
  getSystemInstruction(): string {
    return `You are ZankoAI (مامۆستای ژیری زانکۆ), the dedicated academic AI tutor for university students in Kurdistan and Iraq.
CRITICAL BEHAVIORAL RULES:
1. GREETING ONLY: If the user simply says a greeting without a question (such as "سڵاو", "سلاو", "hello", "hi", "مرحبا"), respond ONLY with: "سڵاو! چۆن دەتوانم لە وانەکانتدا یارمەتیت بدەم؟"
2. GREETING WITH QUESTION: If the user writes both a greeting AND asks a question in the same message (e.g. "سڵاو مامۆستا، یاسای ئۆم چییە؟", "سڵاو چۆنی، داتابەیس چییە؟", or "Hello, what is polymorphism?"): You MUST answer BOTH in the single chat response! First acknowledge and answer their greeting warmly and politely in the same language/dialect (e.g. "سڵاو و ڕێز! زۆر بەخێربێیت خوێندکاری ئازیز، هیوادارم هەمیشە باش و سەرکەوتوو بیت 🌸"), and then immediately provide the comprehensive, structured academic explanation answering their question. Do not skip either the greeting or the question!
3. DIRECT QUESTION: If the prompt contains only a question without any greeting, answer the question directly without unnecessary conversational filler.
4. ACADEMIC EXCELLENCE & CONCISENESS: Keep explanations structured, rigorous, and directly helpful for university coursework. Use clear bullet points, formulas, or code snippets where applicable.
5. LANGUAGE MATCHING: Always reply in the exact language/dialect of the prompt (Kurdish Sorani, Kurdish Badini, Arabic, or English).
6. MATH FORMATTING: NEVER use dollar signs ($ or $$) or LaTeX math delimiters ($...$ or $$...$$). NEVER wrap formulas in dollar signs. Present all math, formulas, and expressions using plain readable text or Unicode (e.g. x², d/dx, ·, =, +, -). Right-to-left readers must not have dollar signs breaking text flow.`;
  }

  /**
   * Executes AI Chat through the multi-provider orchestrator with automatic timeout,
   * retry policy, failover, and comprehensive cost auditing in public.ai_requests.
   */
  async chatWithTeacher(
    userId: string,
    prompt: string,
    history: AIMessage[] = [],
    feature: string = 'ai_chat'
  ): Promise<ChatExecutionResult> {
    const startTime = Date.now();
    const createdAt = new Date(startTime).toISOString();

    const messages: AIMessage[] = [
      ...history,
      { role: 'user', content: prompt },
    ];

    let result: AICompletionResult | null = null;
    let errorMessage: string | null = null;
    let status: 'success' | 'failed' | 'timeout' = 'success';

    try {
      result = await aiOrchestrator.completeWithFailover({
        messages,
        systemInstruction: this.getSystemInstruction(),
        temperature: 0.7,
        timeoutMs: env.AI_TIMEOUT_MS || 30000,
      });

      const durationMs = Date.now() - startTime;
      const completedAt = new Date().toISOString();

      // Record detailed audit log in public.ai_requests via AiCostGuardService
      await this.recordAiRequest({
        userId,
        feature,
        provider: result.provider,
        model: result.model,
        status: 'success',
        tokens: result.totalTokens,
        promptTokens: result.promptTokens,
        completionTokens: result.completionTokens,
        estimatedCost: result.estimatedCost,
        duration: durationMs,
        createdAt,
        completedAt,
      });

      return {
        text: cleanMathAndDollarSigns(result.text),
        provider: result.provider,
        model: result.model,
        promptTokens: result.promptTokens,
        completionTokens: result.completionTokens,
        totalTokens: result.totalTokens,
        estimatedCost: result.estimatedCost,
        durationMs,
      };
    } catch (err: any) {
      const durationMs = Date.now() - startTime;
      const completedAt = new Date().toISOString();
      const rawError = err?.message || 'AI generation failed';
      // NEVER EXPOSE PROVIDER API KEYS
      errorMessage = AiCostGuardService.sanitizeSecrets(rawError);
      status = errorMessage.includes('timed out') ? 'timeout' : 'failed';

      // Record failure audit log
      await this.recordAiRequest({
        userId,
        feature,
        provider: env.DEFAULT_AI_PROVIDER || 'google',
        model: 'unknown',
        status,
        tokens: 0,
        promptTokens: 0,
        completionTokens: 0,
        estimatedCost: 0,
        duration: durationMs,
        errorMessage,
        createdAt,
        completedAt,
      });

      err.message = errorMessage;
      throw err;
    }
  }

  /**
   * Persists granular AI request metrics into public.ai_requests and public.ai_usage_logs
   */
  private async recordAiRequest(data: {
    userId: string;
    feature: string;
    provider: string;
    model: string;
    status: 'success' | 'failed' | 'timeout' | 'blocked';
    tokens: number;
    promptTokens?: number;
    completionTokens?: number;
    estimatedCost: number;
    duration: number;
    errorMessage?: string | null;
    createdAt: string;
    completedAt: string;
  }): Promise<void> {
    try {
      await AiCostGuardService.recordAiRequest({
        user_id: data.userId,
        feature: data.feature,
        provider: data.provider,
        model: data.model,
        input_tokens: data.promptTokens || 0,
        output_tokens: data.completionTokens || 0,
        estimated_cost: data.estimatedCost,
        duration: data.duration,
        status: data.status,
        created_at: data.createdAt,
        completed_at: data.completedAt,
        error_message: data.errorMessage,
      });
    } catch (err) {
      logger.error('Failed to record AI request log in AiCostGuardService:', err);
    }
  }


  /**
   * Multimodal Homework / Image Question Solver
   */
  async solveImageQuestion(
    userId: string,
    imageBase64: string,
    mimeType: string,
    userPrompt?: string
  ): Promise<{ solution: string; provider: string }> {
    const startTime = Date.now();
    const prompt = userPrompt || 'تکایە ئەم پرسیارە شیکار بکە بە هەنگاو بە هەنگاو بە زمانی کوردی، و وەڵامی دروست لەگەڵ هۆکارەکەیدا ڕوون بکەرەوە.';

    if (this.geminiVisionClient) {
      try {
        const response = await this.geminiVisionClient.models.generateContent({
          model: env.GEMINI_MODEL || 'gemini-2.5-flash',
          contents: [
            {
              role: 'user',
              parts: [
                {
                  inlineData: {
                    mimeType: mimeType || 'image/jpeg',
                    data: imageBase64,
                  },
                },
                { text: prompt },
              ],
            },
          ],
          config: {
            systemInstruction: this.getSystemInstruction(),
          },
        });

        const solution = response.text || '';
        const durationMs = Date.now() - startTime;
        const promptTokens = Math.ceil(prompt.length / 4);
        const completionTokens = Math.ceil(solution.length / 4);
        const estimatedCost = (promptTokens * 0.075 + completionTokens * 0.3) / 1000000;

        await this.recordAiRequest({
          userId,
          feature: 'solve_image',
          provider: 'google',
          model: env.GEMINI_MODEL || 'gemini-2.5-flash',
          status: 'success',
          tokens: promptTokens + completionTokens,
          promptTokens,
          completionTokens,
          estimatedCost,
          duration: durationMs,
          createdAt: new Date(startTime).toISOString(),
          completedAt: new Date().toISOString(),
        });

        return { solution, provider: 'google' };
      } catch (err: any) {
        const durationMs = Date.now() - startTime;
        const cleanMsg = AiCostGuardService.sanitizeSecrets(err?.message || 'Vision AI failed');
        await this.recordAiRequest({
          userId,
          feature: 'solve_image',
          provider: 'google',
          model: env.GEMINI_MODEL || 'gemini-2.5-flash',
          status: 'failed',
          tokens: 0,
          estimatedCost: 0,
          duration: durationMs,
          errorMessage: cleanMsg,
          createdAt: new Date(startTime).toISOString(),
          completedAt: new Date().toISOString(),
        });
        err.message = cleanMsg;
        throw err;
      }
    }

    throw new Error('Vision AI model is not configured.');
  }

  /**
   * Generate Custom Exam / Quiz
   */
  async generateQuiz(
    userId: string,
    topic: string,
    courseName: string,
    questionCount: number = 5,
    difficulty: string = 'medium'
  ): Promise<any> {
    const prompt = `Create a structured academic quiz for university students on:
Topic: "${topic}"
Course: "${courseName}"
Questions: ${questionCount}
Difficulty: ${difficulty}

Respond ONLY with valid JSON in the following format:
{
  "title": "کویزی سەرکەوتوو",
  "questions": [
    {
      "questionText": "پرسیار لێرە دابنێ",
      "type": "multiple_choice",
      "options": ["هەڵبژاردەی ١", "هەڵبژاردەی ٢", "هەڵبژاردەی ٣", "هەڵبژاردەی ٤"],
      "correctAnswer": "هەڵبژاردەی ١",
      "explanation": "ڕوونکردنەوەی وەڵامی دروست"
    }
  ]
}`;

    const result = await this.chatWithTeacher(userId, prompt, [], 'quiz');
    try {
      const cleanJson = result.text.replace(/```json/g, '').replace(/```/g, '').trim();
      return JSON.parse(cleanJson);
    } catch {
      throw new Error('Failed to parse AI-generated quiz structure.');
    }
  }

  /**
   * Generate Flashcards with AI
   */
  async generateFlashcards(
    userId: string,
    topic: string,
    courseName?: string,
    cardCount: number = 5
  ): Promise<Array<{ front: string; back: string }>> {
    const prompt = `ئەم تێبینییە یان بابەتەی خوارەوە بە وردی بخوێنەوە و ${cardCount} فلاشکاردی خوێندنەوەی پرۆفێشناڵ و پوخت دروست بکە بە زمانی کوردی (سۆرانی) یان بە زمانی دەقەکە.
بابەت: "${topic}" ${courseName ? `کۆرس: "${courseName}"` : ''}
تەنها و تەنها وەک JSON لەم فۆرماتەی خوارەوە بنووسە:
[
  { "front": "پرسیار یان زاراوە", "back": "ڕوونکردنەوە یان وەڵام" }
]`;

    const result = await this.chatWithTeacher(userId, prompt, [], 'flashcards');
    try {
      let cleanJson = result.text.replace(/```json/g, '').replace(/```/g, '').trim();
      const match = cleanJson.match(/\[\s*\{[\s\S]*\}\s*\]/);
      if (match) {
        cleanJson = match[0];
      }
      return JSON.parse(cleanJson);
    } catch {
      throw new Error('Failed to parse AI-generated flashcards structure.');
    }
  }
}

export const aiGateway = new AiGatewayService();

/**
 * Cleans LaTeX delimiters ($, $$, \$) and converts LaTeX math syntax into clean Unicode/plain text.
 */
export function cleanMathAndDollarSigns(text: string): string {
  if (!text) return text;
  let result = text;
  result = result.replace(/\\\$\$/g, '');
  result = result.replace(/\$\$/g, '');
  result = result.replace(/\\?\$/g, '');
  result = result.replace(/\\?frac\s*\{([^{}]+)\}\s*\{([^{}]+)\}/g, (_m, num, den) => {
    const n = num.trim();
    const d = den.trim();
    return n.length <= 4 && d.length <= 4 ? `${n}/${d}` : `(${n})/(${d})`;
  });
  result = result.replace(/\\?sqrt\s*\{([^{}]+)\}/g, '√($1)');
  result = result.replace(/\\cdot/g, '·');
  result = result.replace(/\\times/g, '×');
  result = result.replace(/\\div/g, '÷');
  result = result.replace(/\\pm/g, '±');
  result = result.replace(/\\mp/g, '∓');
  result = result.replace(/\\leq|\\le/g, '≤');
  result = result.replace(/\\geq|\\ge/g, '≥');
  result = result.replace(/\\neq|\\ne/g, '≠');
  result = result.replace(/\\approx/g, '≈');
  result = result.replace(/\\sim/g, '~');
  result = result.replace(/\\infty/g, '∞');
  result = result.replace(/\\int/g, '∫');
  result = result.replace(/\\partial/g, '∂');
  result = result.replace(/\\sum/g, '∑');
  result = result.replace(/\\prod/g, '∏');
  result = result.replace(/\\pi/g, 'π');
  result = result.replace(/\\theta/g, 'θ');
  result = result.replace(/\\alpha/g, 'α');
  result = result.replace(/\\beta/g, 'β');
  result = result.replace(/\\Delta/g, 'Δ');
  result = result.replace(/\\to|\\rightarrow/g, '→');
  result = result.replace(/\\Rightarrow/g, '⇒');
  result = result.replace(/\\Leftrightarrow|\\iff/g, '⇔');
  result = result.replace(/\^\{([^{}]+)\}/g, (_m, inner) => (inner.length === 1 ? `^${inner}` : `^(${inner})`));
  result = result.replace(/_\{([^{}]+)\}/g, (_m, inner) => (inner.length === 1 ? `_${inner}` : `_(${inner})`));
  result = result.replace(/\\(text|mathrm|mathbf|mathit|textbf|textit)\{([^{}]+)\}/g, '$2');
  result = result.replace(/\\\(/g, '(').replace(/\\\)/g, ')');
  result = result.replace(/\\\[/g, '[').replace(/\\\]/g, ']');
  result = result.replace(/\$/g, '');
  result = result.replace(/[ \t]{2,}/g, ' ');
  return result;
}
