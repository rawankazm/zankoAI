import { Router, Request, Response } from 'express';
import { authMiddleware } from '../middleware/auth.middleware.js';
import { LocalStorageService, StorageCategory } from '../services/local_storage.service.js';

const router = Router();

// Require JWT authentication on all file storage operations
router.use(authMiddleware);

/**
 * GET /api/v1/files/:fileId
 * Streams or downloads an authenticated file with full HTTP Range request support
 */
router.get('/:fileId', (req: Request, res: Response) => {
  LocalStorageService.handleDownloadStream(req, res);
});

/**
 * POST /api/v1/files/upload
 * Multipart file upload endpoint (PDF, OCR Image, or Document Export)
 */
router.post('/upload', LocalStorageService.uploadGeneric.single('file'), (req: Request, res: Response) => {
  const file = req.file;
  if (!file) {
    res.status(400).json({
      success: false,
      error: 'BadRequest',
      message: 'No file uploaded under key "file"',
    });
    return;
  }

  res.status(201).json({
    success: true,
    data: {
      filename: file.filename,
      originalName: file.originalname,
      mimeType: file.mimetype,
      sizeBytes: file.size,
      storagePath: file.path,
      fileUrl: `/api/v1/files/${file.filename}`,
      uploadedBy: req.user?.id,
    },
    message: 'File successfully stored on persistent disk volume',
  });
});

/**
 * DELETE /api/v1/files/:category/:filename
 * Secure file removal from local storage
 */
router.delete('/:category/:filename', async (req: Request, res: Response) => {
  const { category, filename } = req.params;
  const deleted = await LocalStorageService.deleteFile(category as StorageCategory, filename);

  if (!deleted) {
    res.status(404).json({
      success: false,
      error: 'NotFound',
      message: 'File could not be found or deleted',
    });
    return;
  }

  res.status(200).json({
    success: true,
    message: 'File deleted successfully',
  });
});

export const fileRoutes = router;
export default fileRoutes;
