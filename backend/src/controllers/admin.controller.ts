import { Request, Response } from 'express';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { AdminService } from '../services/admin.service.js';

export class AdminController {
  static async listUsers(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 50;

    const data = await AdminService.listAllUsers(page, limit);
    return ResponseFormatter.success(res, data);
  }

  static async setUserRole(req: Request, res: Response): Promise<Response> {
    const { user_id, role } = req.body;
    await AdminService.changeUserRole(user_id, role);
    return ResponseFormatter.success(res, { user_id, role }, 'User role updated successfully');
  }

  static async setUserStatus(req: Request, res: Response): Promise<Response> {
    const { user_id, status } = req.body;
    await AdminService.changeUserStatus(user_id, status);
    return ResponseFormatter.success(res, { user_id, status }, 'User status updated successfully');
  }

  static async getSystemStats(req: Request, res: Response): Promise<Response> {
    const stats = await AdminService.getSystemStats();
    return ResponseFormatter.success(res, stats);
  }
}
