import { supabaseAdmin } from '../config/supabase.js';
import { StorageService } from '../services/storage.service.js';
import { logger } from '../config/logger.js';

// ─── Orphaned Storage File Cleanup ────────────────────────────────────────────

/**
 * Background routine to clean orphaned storage files older than 24 hours.
 * Scans all buckets for files without a corresponding database record.
 */
export async function executeStorageCleanupJob(olderThanHours = 24) {
  logger.info(`[StorageCleanupJob] Starting orphaned storage file cleanup (older than ${olderThanHours} hours)...`);

  try {
    const report = await StorageService.cleanupOrphanedFiles(olderThanHours);
    logger.info(
      `[StorageCleanupJob] Completed: Scanned ${report.scannedCount} files, deleted ${report.deletedCount} orphaned items.`
    );
    return report;
  } catch (err: any) {
    logger.error(`[StorageCleanupJob] Failed to execute cleanup job: ${err.message}`);
    throw err;
  }
}

// ─── Failed / Orphaned PDF Job Cleanup ───────────────────────────────────────

export interface PdfJobCleanupReport {
  scannedCount: number;
  storageDeletedCount: number;
  jobsMarkedFailed: number;
  timestamp: string;
}

/**
 * Cleans up stale PDF jobs (queued or failed) older than the specified hours.
 * 1. Queries pdf_jobs via RPC to find orphaned entries.
 * 2. Attempts to delete associated Supabase Storage files.
 * 3. Ensures all found jobs are marked 'failed' with a cleanup note.
 *
 * This prevents:
 * - Orphaned files in the pdfs bucket consuming storage
 * - Zombie 'queued' jobs that will never be processed (e.g., worker crash)
 */
export async function executeFailedPdfJobCleanup(
  olderThanHours = 24
): Promise<PdfJobCleanupReport> {
  logger.info(
    `[PdfJobCleanupJob] Starting cleanup of stale PDF jobs older than ${olderThanHours} hours...`
  );

  const report: PdfJobCleanupReport = {
    scannedCount: 0,
    storageDeletedCount: 0,
    jobsMarkedFailed: 0,
    timestamp: new Date().toISOString(),
  };

  try {
    // 1. Fetch orphaned jobs via RPC (uses SECURITY DEFINER to bypass RLS)
    const { data: orphanedJobs, error: rpcError } = await supabaseAdmin.rpc(
      'get_orphaned_pdf_jobs',
      { p_older_than_hours: olderThanHours }
    );

    if (rpcError) {
      logger.warn(
        `[PdfJobCleanupJob] RPC get_orphaned_pdf_jobs failed: ${rpcError.message}. Skipping cleanup.`
      );
      return report;
    }

    if (!Array.isArray(orphanedJobs) || orphanedJobs.length === 0) {
      logger.info(`[PdfJobCleanupJob] No orphaned PDF jobs found.`);
      return report;
    }

    report.scannedCount = orphanedJobs.length;
    logger.info(`[PdfJobCleanupJob] Found ${orphanedJobs.length} orphaned PDF jobs to clean up.`);

    for (const job of orphanedJobs) {
      const { job_id, storage_path, status } = job;

      // 2. Delete storage file if still present
      if (storage_path) {
        try {
          const { error: delError } = await supabaseAdmin.storage
            .from('pdfs')
            .remove([storage_path]);

          if (delError) {
            logger.warn(
              `[PdfJobCleanupJob] Could not delete storage file pdfs/${storage_path}: ${delError.message}`
            );
          } else {
            report.storageDeletedCount++;
            logger.info(`[PdfJobCleanupJob] Deleted orphaned storage file: pdfs/${storage_path}`);
          }
        } catch (storageErr: any) {
          logger.warn(
            `[PdfJobCleanupJob] Storage delete error for ${storage_path}: ${storageErr.message}`
          );
        }
      }

      // 3. Mark job as failed (only if it was stuck as 'queued')
      if (status === 'queued') {
        try {
          await supabaseAdmin
            .from('pdf_jobs')
            .update({
              status: 'failed',
              error_message: `Job timed out after ${olderThanHours} hours in queued state. Cleaned up by maintenance job.`,
            })
            .eq('id', job_id);

          report.jobsMarkedFailed++;
          logger.info(`[PdfJobCleanupJob] Marked job ${job_id} as failed (was stuck in queued).`);
        } catch (updateErr: any) {
          logger.warn(`[PdfJobCleanupJob] Failed to update job ${job_id} status: ${updateErr.message}`);
        }
      }
    }

    logger.info(
      `[PdfJobCleanupJob] Cleanup complete: ` +
      `scanned=${report.scannedCount}, ` +
      `storageDeleted=${report.storageDeletedCount}, ` +
      `markedFailed=${report.jobsMarkedFailed}`
    );
  } catch (err: any) {
    logger.error(`[PdfJobCleanupJob] Unexpected error during cleanup: ${err.message}`);
    throw err;
  }

  return report;
}

// ─── Failed / Orphaned OCR Job Cleanup ───────────────────────────────────────

export interface OcrJobCleanupReport {
  scannedCount: number;
  storageDeletedCount: number;
  jobsMarkedFailed: number;
  timestamp: string;
}

/**
 * Cleans up stale OCR jobs (queued or failed) older than the specified hours.
 * 1. Queries ocr_jobs via get_orphaned_ocr_jobs RPC.
 * 2. Deletes associated Supabase Storage files from ocr-images bucket.
 * 3. Ensures zombie 'queued' jobs are marked 'failed'.
 */
export async function executeFailedOcrJobCleanup(
  olderThanHours = 24
): Promise<OcrJobCleanupReport> {
  logger.info(
    `[OcrJobCleanupJob] Starting cleanup of stale OCR jobs older than ${olderThanHours} hours...`
  );

  const report: OcrJobCleanupReport = {
    scannedCount: 0,
    storageDeletedCount: 0,
    jobsMarkedFailed: 0,
    timestamp: new Date().toISOString(),
  };

  try {
    const { data: orphanedJobs, error: rpcErr } = await supabaseAdmin.rpc(
      'get_orphaned_ocr_jobs',
      { p_older_than_hours: olderThanHours }
    );

    if (rpcErr) {
      logger.error(`[OcrJobCleanupJob] RPC get_orphaned_ocr_jobs failed: ${rpcErr.message}`);
      throw new Error(`Failed to fetch orphaned OCR jobs: ${rpcErr.message}`);
    }

    if (!orphanedJobs || !Array.isArray(orphanedJobs) || orphanedJobs.length === 0) {
      logger.info('[OcrJobCleanupJob] No orphaned OCR jobs found. Nothing to clean.');
      return report;
    }

    report.scannedCount = orphanedJobs.length;
    logger.info(`[OcrJobCleanupJob] Found ${orphanedJobs.length} orphaned/stale OCR jobs.`);

    for (const job of orphanedJobs) {
      const { job_id, storage_path, status } = job;

      // Delete storage file if path exists
      if (storage_path) {
        try {
          const { error: storageErr } = await supabaseAdmin.storage
            .from('ocr-images')
            .remove([storage_path]);

          if (!storageErr) {
            report.storageDeletedCount++;
            logger.info(`[OcrJobCleanupJob] Deleted storage file ${storage_path} for job ${job_id}.`);
          } else {
            logger.warn(
              `[OcrJobCleanupJob] Storage delete error for ${storage_path}: ${storageErr.message}`
            );
          }
        } catch (storageErr: any) {
          logger.warn(
            `[OcrJobCleanupJob] Storage delete error for ${storage_path}: ${storageErr.message}`
          );
        }
      }

      // Mark job as failed if stuck in queued
      if (status === 'queued') {
        try {
          await supabaseAdmin
            .from('ocr_jobs')
            .update({
              status: 'failed',
              error_message: `Job timed out after ${olderThanHours} hours in queued state. Cleaned up by maintenance job.`,
            })
            .eq('id', job_id);

          report.jobsMarkedFailed++;
          logger.info(`[OcrJobCleanupJob] Marked job ${job_id} as failed (was stuck in queued).`);
        } catch (updateErr: any) {
          logger.warn(`[OcrJobCleanupJob] Failed to update job ${job_id} status: ${updateErr.message}`);
        }
      }
    }

    logger.info(
      `[OcrJobCleanupJob] Cleanup complete: scanned=${report.scannedCount}, storageDeleted=${report.storageDeletedCount}, markedFailed=${report.jobsMarkedFailed}`
    );
  } catch (err: any) {
    logger.error(`[OcrJobCleanupJob] Unexpected error during cleanup: ${err.message}`);
    throw err;
  }

  return report;
}

