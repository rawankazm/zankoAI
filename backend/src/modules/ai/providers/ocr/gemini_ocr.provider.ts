import { GoogleGenAI } from '@google/genai';
import { IOcrProvider } from './ocr_provider.interface.js';
import { OcrExtractionOptions, OcrExtractionResult, DetectedTextType } from '../../../../types/ocr.types.js';
import { env } from '../../../../config/env.js';
import { logger } from '../../../../config/logger.js';

export class GeminiOcrProvider implements IOcrProvider {
  readonly name = 'google';
  private client?: GoogleGenAI;
  private model: string;

  constructor(apiKey?: string, model?: string) {
    const key = apiKey || env.GEMINI_API_KEY;
    this.model = model || env.GEMINI_MODEL || 'gemini-2.5-flash';
    if (key) {
      this.client = new GoogleGenAI({ apiKey: key });
    }
  }

  async extractText(
    imageBuffer: Buffer,
    mimeType: string,
    options: OcrExtractionOptions = {}
  ): Promise<OcrExtractionResult> {
    if (!this.client) {
      throw new Error('Google Gemini API Key is not configured for OCR.');
    }

    const mode = options.mode || 'auto';
    const langHint = options.languageHint || 'Kurdish, Arabic, English';

    const systemInstruction = `You are a high-accuracy academic Optical Character Recognition (OCR) engine specialized in Kurdish (Sorani and Badini in Arabic script), Arabic, English, and scientific formulas.
Your objective:
1. Accurately transcribe all visible text in the image into plain text.
2. Preserve reading order, headings, bullet points, and paragraph structure.
3. Transcribe mathematical formulas using standard notation.
4. Mode instruction: ${
      mode === 'handwriting'
        ? 'Focus specifically on deciphering handwritten notes, cursive writing, exam solutions, and annotations.'
        : mode === 'printed'
        ? 'Focus on cleanly transcribing printed lecture notes, slides, book pages, and typography.'
        : 'Transcribe both printed and handwritten text in the document.'
    }
5. Language hints: ${langHint}.
6. At the very end of your response, output a single JSON metadata line formatted exactly like:
---METADATA---{"detectedType":"handwriting"|"printed"|"mixed","confidence":0.95}`;

    const base64Data = imageBuffer.toString('base64');

    const prompt = 'Please extract and transcribe all text from this image faithfully and completely.';

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
          systemInstruction,
          temperature: 0.1, // Low temperature for maximum fidelity
        },
      });

      const outputText = response.text || '';
      return this.parseOcrOutput(outputText);
    } catch (err: any) {
      logger.error(`[GeminiOcrProvider] OCR extraction failed: ${err.message}`);
      throw new Error(`Gemini OCR failed: ${err.message}`);
    }
  }

  private parseOcrOutput(output: string): OcrExtractionResult {
    let rawText = output.trim();
    let detectedType: DetectedTextType = 'mixed';
    let confidence = 0.95;

    const metaSplit = rawText.split('---METADATA---');
    if (metaSplit.length > 1) {
      rawText = metaSplit[0].trim();
      const metaJsonStr = metaSplit[1].trim();
      try {
        const meta = JSON.parse(metaJsonStr);
        if (meta.detectedType === 'handwriting' || meta.detectedType === 'printed' || meta.detectedType === 'mixed') {
          detectedType = meta.detectedType;
        }
        if (typeof meta.confidence === 'number' && meta.confidence >= 0 && meta.confidence <= 1) {
          confidence = meta.confidence;
        }
      } catch {
        // Fallback: heuristic detection if JSON parse fails
        detectedType = 'mixed';
      }
    }

    return {
      rawText,
      cleanedText: rawText,
      detectedType,
      confidence,
      provider: this.name,
    };
  }
}
