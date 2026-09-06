import { Request, Response } from 'express';
import { StorageService, BUCKET_CONFIGS } from '../services/storage.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { StorageCategory } from '../types/storage.types.js';

export class StorageController {
  /**
   * Request a pre-signed upload ticket for direct, authenticated client upload
   */
  static async createUploadTicket(req: Request, res: Response): Promise<Response> {
    const caller = {
      id: req.user!.id,
      profile: req.profile!,
    };

    const ticket = await StorageService.createUploadTicket(caller, req.body);
    return ResponseFormatter.created(res, ticket, 'Upload authorization ticket granted');
  }

  /**
   * Request a short-lived Signed URL for private file viewing/downloading
   */
  static async getSignedUrl(req: Request, res: Response): Promise<Response> {
    const caller = {
      id: req.user!.id,
      profile: req.profile!,
    };

    const signedUrlData = await StorageService.createSignedDownloadUrl(caller, req.body);
    return ResponseFormatter.success(res, signedUrlData, 'Signed URL generated successfully');
  }

  /**
   * Delete a file from storage
   */
  static async deleteFile(req: Request, res: Response): Promise<Response> {
    const caller = {
      id: req.user!.id,
      profile: req.profile!,
    };

    const { category, storagePath } = req.body;
    await StorageService.deleteFile(caller, category as StorageCategory, storagePath);

    return ResponseFormatter.success(res, null, 'File successfully deleted from storage');
  }

  /**
   * Trigger cleanup of orphaned files (Admin only)
   */
  static async triggerCleanup(req: Request, res: Response): Promise<Response> {
    const olderThanHours = req.query.olderThanHours
      ? parseInt(req.query.olderThanHours as string, 10)
      : 24;

    const report = await StorageService.cleanupOrphanedFiles(olderThanHours);
    return ResponseFormatter.success(res, report, 'Storage cleanup job completed');
  }

  /**
   * Get storage categories and limits metadata
   */
  static async getCategories(req: Request, res: Response): Promise<Response> {
    const categories = Object.values(BUCKET_CONFIGS).map((cfg) => ({
      id: cfg.id,
      isPublic: cfg.isPublic,
      maxSizeBytes: cfg.maxSizeBytes,
      maxSizeMB: Math.round(cfg.maxSizeBytes / (1024 * 1024)),
      allowedExtensions: cfg.allowedExtensions,
      allowedMimeTypes: cfg.allowedMimeTypes,
    }));

    return ResponseFormatter.success(res, categories);
  }
}
