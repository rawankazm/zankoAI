import { IOcrProvider } from './ocr_provider.interface.js';
import { OcrExtractionOptions, OcrExtractionResult, DetectedTextType } from '../../../../types/ocr.types.js';

export class MockOcrProvider implements IOcrProvider {
  readonly name = 'mock';

  async extractText(
    _imageBuffer: Buffer,
    _mimeType: string,
    options: OcrExtractionOptions = {}
  ): Promise<OcrExtractionResult> {
    const mode = options.mode || 'auto';
    const detectedType: DetectedTextType =
      mode === 'handwriting' ? 'handwriting' : mode === 'printed' ? 'printed' : 'mixed';

    const sampleText =
      mode === 'handwriting'
        ? `[Handwritten Student Notes - University of Sulaimani]\n` +
          `Date: 2026-09-07\n` +
          `بابەت: بنەماکانی سیستەمی کۆمپیوتەر و بیرکاری\n` +
          `1. ئەلگۆریتم بریتییە لە زنجیرەیەک هەنگاوی ژیربێژی بۆ چارەسەرکردنی کێشەیەک.\n` +
          `2. پێکهاتەکانی داتابەیس: خشتە، پەیوەندی، و کلیلە سەرەکییەکان (Primary Keys).\n` +
          `3. Formula: E = mc^2 and O(n log n) for MergeSort.`
        : `[Printed Lecture Slide - Faculty of Science]\n` +
          `Chapter 4: Advanced Database Systems & Concurrency Control\n` +
          `ACID Properties:\n` +
          `- Atomicity: All or nothing execution of transactions.\n` +
          `- Consistency: Database transitions from one valid state to another.\n` +
          `- Isolation: Concurrent transactions do not interfere.\n` +
          `- Durability: Committed transactions persist permanently in storage.`;

    return {
      rawText: sampleText,
      cleanedText: sampleText,
      detectedType,
      confidence: 0.98,
      languageDetected: 'ckb',
      provider: this.name,
    };
  }
}
