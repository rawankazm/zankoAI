// ==============================================================================
// ZankoAI Device Registration Controller
// Endpoints:
//   POST   /api/devices
//   DELETE /api/devices/:id
//   GET    /api/devices
// ==============================================================================

import { Request, Response } from 'express';
import { NotificationService } from '../services/notification.service.js';
import { ResponseFormatter } from '../utils/apiResponse.js';

export class DeviceController {
  /**
   * POST /api/devices
   * Registers a new device or updates an existing device token.
   * Multi-device support: each user can have multiple active devices (phones, tablets, web).
   */
  static async registerDevice(req: Request, res: Response): Promise<Response> {
    const { fcm_token, platform, device_id, app_version } = req.body;

    const device = await NotificationService.registerDevice(req.user!.id, {
      fcm_token,
      platform,
      device_id,
      app_version,
    });

    return ResponseFormatter.success(res, device, 'Device registered successfully');
  }

  /**
   * DELETE /api/devices/:id
   * Handles device removal or user logout.
   * Parameter :id can be the device database UUID, device_id, or fcm_token.
   */
  static async deleteDevice(req: Request, res: Response): Promise<Response> {
    const { id } = req.params;
    const result = await NotificationService.deleteDevice(req.user!.id, id);

    return ResponseFormatter.success(
      res,
      result,
      result.deactivatedCount > 0
        ? 'Device unregistered successfully'
        : 'Device was already inactive or not found'
    );
  }

  /**
   * GET /api/devices
   * Lists all active registered devices for the authenticated user.
   */
  static async listDevices(req: Request, res: Response): Promise<Response> {
    const devices = await NotificationService.listDevices(req.user!.id);
    return ResponseFormatter.success(res, devices);
  }
}
