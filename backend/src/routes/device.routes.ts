// ==============================================================================
// ZankoAI Device Registration Routes
// Mounted at: /api/devices
// ==============================================================================

import { Router } from 'express';
import { DeviceController } from '../controllers/device.controller.js';
import { authenticateUser } from '../middleware/authenticateUser.js';
import { validateRequest } from '../middleware/validateRequest.js';
import { registerDeviceSchema } from '../validators/calendar_notification.validators.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// All device management endpoints require authentication
router.use(authenticateUser);

// POST /api/devices — Register or refresh a device token
router.post(
  '/',
  validateRequest({ body: registerDeviceSchema }),
  asyncWrapper(DeviceController.registerDevice)
);

// DELETE /api/devices/:id — Unregister or remove a device (by UUID, device_id, or token)
router.delete('/:id', asyncWrapper(DeviceController.deleteDevice));

// GET /api/devices — List active devices for current user
router.get('/', asyncWrapper(DeviceController.listDevices));

export const deviceRoutes = router;
