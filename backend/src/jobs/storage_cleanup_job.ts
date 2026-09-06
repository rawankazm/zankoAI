import { StorageService } from '../services/storage.service.js';
import { logger } from '../config/logger.js';

/**
 * Background routine to clean orphaned storage files older than 24 hours
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
