import { Router } from 'express';
import { StorageController } from '../controllers/storage.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { requireRole } from '../middleware/requireRole.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { rateLimiter } from '../middleware/rateLimiter.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';
import {
  uploadTicketSchema,
  signedUrlSchema,
  deleteFileSchema,
} from '../validators/storage.validators.js';

const router = Router();

// Public / Authenticated: Inspect storage categories, size limits, and allowed extensions
router.get('/categories', asyncWrapper(StorageController.getCategories));

// All mutative storage routes require an authenticated user
router.use(authenticateUser);

// Request a pre-signed upload ticket (15 uploads / minute limit per user)
router.post(
  '/upload-ticket',
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 15, keyPrefix: 'rl:storage:upload' }),
  validateRequest({ body: uploadTicketSchema }),
  asyncWrapper(StorageController.createUploadTicket)
);

// Request a short-lived signed URL for private file access (60 downloads / minute)
router.post(
  '/signed-url',
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 60, keyPrefix: 'rl:storage:download' }),
  validateRequest({ body: signedUrlSchema }),
  asyncWrapper(StorageController.getSignedUrl)
);

// Secure deletion of a storage file (Owner or Admin)
router.delete(
  '/file',
  rateLimiter({ windowMs: 60 * 1000, maxRequests: 20, keyPrefix: 'rl:storage:delete' }),
  validateRequest({ body: deleteFileSchema }),
  asyncWrapper(StorageController.deleteFile)
);

// Admin-only: Trigger orphaned file cleanup
router.post(
  '/cleanup',
  requireRole(['admin']),
  asyncWrapper(StorageController.triggerCleanup)
);

export const storageRoutes = router;
export default storageRoutes;
