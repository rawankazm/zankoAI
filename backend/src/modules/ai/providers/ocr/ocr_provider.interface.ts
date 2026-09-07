import { OcrExtractionOptions, OcrExtractionResult } from '../../../../types/ocr.types.js';

export interface IOcrProvider {
  readonly name: string;
  extractText(
    imageBuffer: Buffer,
    mimeType: string,
    options?: OcrExtractionOptions
  ): Promise<OcrExtractionResult>;
}
