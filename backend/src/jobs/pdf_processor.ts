import axios from 'axios';
import pdfParse from 'pdf-parse';
import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';
import { validateExternalUrl } from '../utils/ssrfValidator.js';
import { validateMagicBytes } from '../middleware/uploadGuard.js';

export async function processPdfJob(data: { lectureId: string; fileUrl: string }) {
  const { lectureId, fileUrl } = data;
  logger.info(`Starting background PDF text extraction for lecture: ${lectureId}`);

  try {
    // 1. SSRF Protection: Validate URL does not target loopback or private network
    validateExternalUrl(fileUrl);

    // 2. Download file buffer with strict timeout and maximum size limit (25MB)
    const response = await axios.get(fileUrl, {
      responseType: 'arraybuffer',
      timeout: 15000,
      maxContentLength: 25 * 1024 * 1024,
    });
    const buffer = Buffer.from(response.data);

    // 3. Magic Bytes Validation: Ensure genuine PDF structure
    const magicCheck = validateMagicBytes(buffer);
    if (!magicCheck.isValid || magicCheck.detectedType !== 'application/pdf') {
      throw new Error(`Invalid PDF document: Magic bytes do not match genuine PDF structure`);
    }

    // 4. Parse PDF text
    const parsed = await pdfParse(buffer);
    const extractedText = parsed.text || '';

    // 5. Save extracted text to PostgreSQL
    await supabaseAdmin
      .from('lectures')
      .update({
        extracted_text: extractedText,
        is_processed: true,
      })
      .eq('id', lectureId);

    logger.info(`Successfully extracted ${extractedText.length} characters for lecture ${lectureId}`);
  } catch (err: any) {
    logger.error(`Error processing PDF job for lecture ${lectureId}: ${err.message}`);
    throw err;
  }
}
