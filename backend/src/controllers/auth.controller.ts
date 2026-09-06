import { Request, Response } from 'express';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { AuthService } from '../services/auth.service.js';
import { UsageService } from '../services/usage.service.js';

export class AuthController {
  static async getMe(req: Request, res: Response): Promise<Response> {
    const profile = await AuthService.getCurrentProfile(req.user!.id);
    const usage = await UsageService.getUserUsageToday(req.user!.id);

    return ResponseFormatter.success(res, {
      profile,
      usageToday: usage.used,
    });
  }

  static async updateMe(req: Request, res: Response): Promise<Response> {
    const updated = await AuthService.updateProfile(req.user!.id, req.body);
    return ResponseFormatter.success(res, updated, 'Profile updated successfully');
  }
}
