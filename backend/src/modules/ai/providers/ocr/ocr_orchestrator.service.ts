import { IOcrProvider } from './ocr_provider.interface.js';
import { GeminiOcrProvider } from './gemini_ocr.provider.js';
import { OpenAiOcrProvider } from './openai_ocr.provider.js';
import { MockOcrProvider } from './mock_ocr.provider.js';
import { OcrExtractionOptions, OcrExtractionResult } from '../../../../types/ocr.types.js';
import { env } from '../../../../config/env.js';
import { logger } from '../../../../config/logger.js';

export class OcrOrchestrator {
  private static instance: OcrOrchestrator;
  private providers: Map<string, IOcrProvider> = new Map();
  private primaryProviderName: string = 'google';

  private constructor() {
    // 1. Always register Mock provider for testing
    this.providers.set('mock', new MockOcrProvider());

    // 2. Register Gemini provider if key exists
    if (env.GEMINI_API_KEY) {
      this.providers.set('google', new GeminiOcrProvider());
    }

    // 3. Register OpenAI provider if key exists
    if (env.OPENAI_API_KEY) {
      this.providers.set('openai', new OpenAiOcrProvider());
    }

    // Determine primary provider
    if (this.providers.has('google')) {
      this.primaryProviderName = 'google';
    } else if (this.providers.has('openai')) {
      this.primaryProviderName = 'openai';
    } else {
      logger.warn('[OcrOrchestrator] No AI API keys detected. Falling back to Mock OCR provider.');
      this.primaryProviderName = 'mock';
    }
  }

  public static getInstance(): OcrOrchestrator {
    if (!OcrOrchestrator.instance) {
      OcrOrchestrator.instance = new OcrOrchestrator();
    }
    return OcrOrchestrator.instance;
  }

  /**
   * Extracts text with automatic fallback between providers.
   */
  public async extractText(
    imageBuffer: Buffer,
    mimeType: string,
    options: OcrExtractionOptions = {}
  ): Promise<OcrExtractionResult> {
    const primary = this.providers.get(this.primaryProviderName);

    if (primary) {
      try {
        logger.info(`[OcrOrchestrator] Extracting text using primary provider: ${primary.name} (mode=${options.mode || 'auto'})`);
        return await primary.extractText(imageBuffer, mimeType, options);
      } catch (primaryErr: any) {
        logger.warn(`[OcrOrchestrator] Primary provider ${primary.name} failed: ${primaryErr.message}. Attempting fallback...`);
      }
    }

    // Try fallback providers
    for (const [name, provider] of this.providers.entries()) {
      if (name === this.primaryProviderName) continue;
      try {
        logger.info(`[OcrOrchestrator] Trying fallback OCR provider: ${name}`);
        return await provider.extractText(imageBuffer, mimeType, options);
      } catch (fallbackErr: any) {
        logger.warn(`[OcrOrchestrator] Fallback provider ${name} failed: ${fallbackErr.message}`);
      }
    }

    throw new Error('All configured OCR providers failed to extract text from the image.');
  }
}
