import axios from 'axios';
import pdfParse from 'pdf-parse';
import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../config/logger.js';

export async function processPdfJob(data: { lectureId: string; fileUrl: string }) {
  const { lectureId, fileUrl } = data;
  logger.info(`Starting background PDF text extraction for lecture: ${lectureId}`);

  try {
    // 1. Download file buffer
    const response = await axios.get(fileUrl, { responseType: 'arraybuffer' });
    const buffer = Buffer.from(response.data);

    // 2. Parse PDF text
    const parsed = await pdfParse(buffer);
    const extractedText = parsed.text || '';

    // 3. Save extracted text to PostgreSQL
    await supabaseAdmin
      .from('lectures')
      .update({
        extracted_text: extractedText,
        is_processed: true,
      })
      .eq('id', lectureId);

    logger.info(`Successfully extracted ${extractedText.length} characters for lecture ${lectureId}`);
  } catch (err: any) {
    logger.error(`Error processing PDF job for lecture ${lectureId}:`, err);
    throw err;
  }
}
