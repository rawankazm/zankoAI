import OpenAI from 'openai';
import { IOcrProvider } from './ocr_provider.interface.js';
import { OcrExtractionOptions, OcrExtractionResult, DetectedTextType } from '../../../../types/ocr.types.js';
import { env } from '../../../../config/env.js';
import { logger } from '../../../../config/logger.js';

export class OpenAiOcrProvider implements IOcrProvider {
  readonly name = 'openai';
  private client?: OpenAI;
  private model: string;

  constructor(apiKey?: string, model?: string) {
    const key = apiKey || env.OPENAI_API_KEY;
    this.model = model || env.OPENAI_MODEL || 'gpt-4o';
    if (key) {
      this.client = new OpenAI({ apiKey: key });
    }
  }

  async extractText(
    imageBuffer: Buffer,
    mimeType: string,
    options: OcrExtractionOptions = {}
  ): Promise<OcrExtractionResult> {
    if (!this.client) {
      throw new Error('OpenAI API Key is not configured for OCR.');
    }

    const mode = options.mode || 'auto';
    const base64 = imageBuffer.toString('base64');
    const dataUrl = `data:${mimeType};base64,${base64}`;

    const systemPrompt = `You are a high-precision academic OCR engine specialized in handwritten notes and printed academic documents.
Transcribe all text from the image faithfully.
Mode: ${mode}.
At the end of your response, output a single line:
---METADATA---{"detectedType":"handwriting"|"printed"|"mixed","confidence":0.9}`;

    try {
      const completion = await this.client.chat.completions.create({
        model: this.model,
        messages: [
          { role: 'system', content: systemPrompt },
          {
            role: 'user',
            content: [
              { type: 'text', text: 'Transcribe all text from this image faithfully.' },
              { type: 'image_url', image_url: { url: dataUrl } },
            ],
          },
        ],
        max_tokens: 4096,
        temperature: 0.1,
      });

      const outputText = completion.choices[0]?.message?.content || '';
      return this.parseOcrOutput(outputText);
    } catch (err: any) {
      logger.error(`[OpenAiOcrProvider] OCR extraction failed: ${err.message}`);
      throw new Error(`OpenAI OCR failed: ${err.message}`);
    }
  }

  private parseOcrOutput(output: string): OcrExtractionResult {
    let rawText = output.trim();
    let detectedType: DetectedTextType = 'mixed';
    let confidence = 0.90;

    const metaSplit = rawText.split('---METADATA---');
    if (metaSplit.length > 1) {
      rawText = metaSplit[0].trim();
      const metaJsonStr = metaSplit[1].trim();
      try {
        const meta = JSON.parse(metaJsonStr);
        if (meta.detectedType === 'handwriting' || meta.detectedType === 'printed' || meta.detectedType === 'mixed') {
          detectedType = meta.detectedType;
        }
        if (typeof meta.confidence === 'number') {
          confidence = meta.confidence;
        }
      } catch {
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
