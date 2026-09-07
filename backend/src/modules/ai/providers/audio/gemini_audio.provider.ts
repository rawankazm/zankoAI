import { GoogleGenAI } from '@google/genai';
import { env } from '../../../../config/env.js';
import { logger } from '../../../../config/logger.js';

export interface AudioTranscriptionResult {
  transcript: string;
  languageDetected: string;
  provider: string;
}

export class GeminiAudioProvider {
  private client?: GoogleGenAI;
  private model: string;

  constructor(apiKey?: string, model?: string) {
    const key = apiKey || env.GEMINI_API_KEY;
    this.model = model || env.GEMINI_MODEL || 'gemini-2.5-flash';
    if (key) {
      this.client = new GoogleGenAI({ apiKey: key });
    }
  }

  async transcribeAudio(
    audioBuffer: Buffer,
    mimeType: string,
    languageHint = 'ku'
  ): Promise<AudioTranscriptionResult> {
    if (!this.client) {
      logger.warn('[GeminiAudioProvider] No Gemini API key configured. Using mock transcription.');
      return this.getMockTranscription(languageHint);
    }

    const base64Data = audioBuffer.toString('base64');

    const prompt = `You are an expert academic lecture transcriber specialized in Kurdish (Sorani and Badini in Arabic script), Arabic, and English.
Please transcribe this entire recorded lecture faithfully and verbatim.
- Capture technical terms, academic definitions, and mathematical expressions accurately.
- Organize the output with clear paragraphs and section headers reflecting the lecturer's topic transitions.
- Language preference: ${languageHint}.
- Output ONLY the transcription text.`;

    try {
      const response = await this.client.models.generateContent({
        model: this.model,
        contents: [
          {
            role: 'user',
            parts: [
              {
                inlineData: {
                  mimeType,
                  data: base64Data,
                },
              },
              { text: prompt },
            ],
          },
        ],
        config: {
          temperature: 0.1,
        },
      });

      const transcript = (response.text || '').trim();
      return {
        transcript,
        languageDetected: languageHint,
        provider: 'google',
      };
    } catch (err: any) {
      logger.error(`[GeminiAudioProvider] Speech-to-text failed: ${err.message}`);
      throw new Error(`Speech-to-text failed: ${err.message}`);
    }
  }

  private getMockTranscription(languageHint: string): AudioTranscriptionResult {
    const mock =
      `سڵاو قوتابییانی ئازیز، لەم وانەیەدا باسی بنەماکانی تۆڕەکانی کۆمپیوتەر دەکەین.\n\n` +
      `تۆڕی کۆمپیوتەر بریتییە لە بەستنەوەی دوو یان زیاتر لە ئامێر بە مەبەستی ئاڵوگۆڕکردنی داتا و سەرچاوەکان.\n` +
      `مۆدێلی OSI لە حەوت چینی سەرەکی پێکدێت: فیزیایی، بەستەری داتا، تۆڕ، گواستنەوە، دانیشتن، پێشکەشکردن، و بەرنامە.\n` +
      `پڕۆتۆکۆڵی TCP/IP پڕۆتۆکۆڵی بنەڕەتی ئینتەرنێتە کە دڵنیایی دەدات لە گەیشتنی پاکێتی داتاکان بەبێ لەدەستچوون.`;

    return {
      transcript: mock,
      languageDetected: languageHint,
      provider: 'mock',
    };
  }
}
