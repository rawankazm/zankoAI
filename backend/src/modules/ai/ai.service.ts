import { GoogleGenAI } from '@google/genai';
import OpenAI from 'openai';
import Anthropic from '@anthropic-ai/sdk';
import { env } from '../../config/env.js';
import { logger } from '../../config/logger.js';
import { supabaseAdmin } from '../../config/supabase.js';

export class AiGatewayService {
  private geminiClient?: GoogleGenAI;
  private openaiClient?: OpenAI;
  private anthropicClient?: Anthropic;

  constructor() {
    if (env.GEMINI_API_KEY) {
      this.geminiClient = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
    }
    if (env.OPENAI_API_KEY) {
      this.openaiClient = new OpenAI({ apiKey: env.OPENAI_API_KEY });
    }
    if (env.ANTHROPIC_API_KEY) {
      this.anthropicClient = new Anthropic({ apiKey: env.ANTHROPIC_API_KEY });
    }
  }

  /**
   * System Prompt for ZankoAI - Specialized in Kurdish (Sorani & Badini) & Arabic Academic Instruction
   */
  private getSystemInstruction(): string {
    return `You are ZankoAI (مامۆستای ژیری زانکۆ), the academic tutor for university students.
CRITICAL INSTRUCTIONS:
1. GREETING: If the user says a greeting (such as "سڵاو", "سلاو", "hello", "hi", "مرحبا"), respond ONLY with: "سڵاو! چۆن دەتوانم یارمەتیت بدەم؟"
2. NO PREAMBLE / NO FLUFF: Answer the user's question directly and immediately. Do NOT write unnecessary introductions, conversational filler, polite intros, or redundant disclaimers.
3. CONCISE & PRECISE: Keep answers focused, academic, and directly address what was asked without unnecessary extra text.
4. LANGUAGE: Always reply in the exact language/dialect of the prompt (Kurdish Sorani, Kurdish Badini, Arabic, or English).`;
  }

  /**
   * Chat with AI Teacher using Gemini with automatic fallback to GPT-4o / Claude
   */
  async chatWithTeacher(
    userId: string,
    prompt: string,
    history: Array<{ role: 'user' | 'model'; parts: string }> = []
  ): Promise<{ response: string; provider: string; model: string }> {
    const startTime = Date.now();

    // 1. Try Gemini 2.0 / 1.5 Flash first
    if (this.geminiClient && env.GEMINI_API_KEY) {
      try {
        const contents = [
          ...history.map((h) => ({
            role: h.role,
            parts: [{ text: h.parts }],
          })),
          { role: 'user', parts: [{ text: prompt }] },
        ];

        const result = await this.geminiClient.models.generateContent({
          model: 'gemini-3.8-flash',
          contents,
          config: {
            systemInstruction: this.getSystemInstruction(),
            temperature: 0.7,
          },
        });

        const reply = result.text || '';
        await this.logAiUsage(userId, 'chat', 'gemini-3.8-flash', Date.now() - startTime);

        return { response: reply, provider: 'google', model: 'gemini-3.8-flash' };
      } catch (err: any) {
        logger.warn('Primary AI (Gemini) failed, attempting failover to OpenAI...', { error: err.message });
      }
    }

    // 2. Failover to OpenAI GPT-4o
    if (this.openaiClient && env.OPENAI_API_KEY) {
      try {
        const completion = await this.openaiClient.chat.completions.create({
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: this.getSystemInstruction() },
            ...history.map((h) => ({
              role: (h.role === 'model' ? 'assistant' : 'user') as 'assistant' | 'user',
              content: h.parts,
            })),
            { role: 'user', content: prompt },
          ],
        });

        const reply = completion.choices[0]?.message?.content || '';
        await this.logAiUsage(userId, 'chat', 'gpt-4o-mini', Date.now() - startTime);

        return { response: reply, provider: 'openai', model: 'gpt-4o-mini' };
      } catch (err: any) {
        logger.error('Failover to OpenAI also failed:', { error: err.message });
      }
    }

    throw new Error('All configured AI providers are currently unavailable. Please try again in a few moments.');
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

    if (this.geminiClient) {
      const response = await this.geminiClient.models.generateContent({
        model: 'gemini-2.5-flash',
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
      await this.logAiUsage(userId, 'solve_image', 'gemini-2.5-flash', Date.now() - startTime);
      return { solution, provider: 'google' };
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

    const { response } = await this.chatWithTeacher(userId, prompt);
    try {
      const cleanJson = response.replace(/```json/g, '').replace(/```/g, '').trim();
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

    const { response } = await this.chatWithTeacher(userId, prompt);
    try {
      let cleanJson = response.replace(/```json/g, '').replace(/```/g, '').trim();
      const match = cleanJson.match(/\[\s*\{[\s\S]*\}\s*\]/);
      if (match) {
        cleanJson = match[0];
      }
      return JSON.parse(cleanJson);
    } catch {
      throw new Error('Failed to parse AI-generated flashcards structure.');
    }
  }

  /**
   * Log AI token usage to Supabase ai_usage_logs for analytics and fair usage auditing
   */
  private async logAiUsage(userId: string, feature: string, model: string, durationMs: number) {
    try {
      await supabaseAdmin.from('ai_usage_logs').insert({
        user_id: userId,
        feature,
        model_used: model,
        duration_ms: durationMs,
      });
    } catch (err) {
      logger.error('Failed to record AI usage log:', err);
    }
  }
}

export const aiGateway = new AiGatewayService();
