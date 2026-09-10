import { Request, Response } from 'express';
import { ResponseFormatter } from '../utils/apiResponse.js';
import { AdminService } from '../services/admin.service.js';
import { AuditService } from '../services/audit.service.js';

export class AdminController {
  private static getReqMeta(req: Request) {
    return {
      ip: (req.headers['x-forwarded-for'] as string) || req.socket.remoteAddress || req.ip,
      userAgent: req.headers['user-agent'] as string,
    };
  }

  // ─── Users ─────────────────────────────────────────────────────────────────

  static async listUsers(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const role = req.query.role as string | undefined;
    const status = req.query.status as string | undefined;
    const plan = req.query.plan as string | undefined;
    const q = req.query.q as string | undefined;

    const data = await AdminService.listAllUsers({ page, limit, role, status, plan, q });
    return ResponseFormatter.success(res, data, 'Users retrieved successfully');
  }

  static async updateUserStatus(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const targetUserId = req.params.id || req.body.user_id;
    const { status, reason } = req.body;
    const meta = AdminController.getReqMeta(req);

    const result = await AdminService.updateUserStatus(adminId, targetUserId, status, reason, meta);
    return ResponseFormatter.success(
      res,
      result,
      `User account ${status === 'suspended' ? 'suspended' : 'activated'} successfully`
    );
  }

  static async updateUserPlan(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const targetUserId = req.params.id || req.body.user_id;
    const { plan, days, reason } = req.body;
    const meta = AdminController.getReqMeta(req);

    const result = await AdminService.updateUserPlan(adminId, targetUserId, plan, days || 30, reason, meta);
    return ResponseFormatter.success(
      res,
      result,
      `User plan updated to '${plan}' successfully`
    );
  }

  static async setUserRole(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const targetUserId = req.params.id || req.body.user_id;
    const { role, reason } = req.body;
    const meta = AdminController.getReqMeta(req);

    const result = await AdminService.changeUserRole(adminId, targetUserId, role, reason, meta);
    return ResponseFormatter.success(res, result, 'User role updated successfully');
  }

  static async setUserVip(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const { user_id, is_vip, days, reason } = req.body;
    const meta = AdminController.getReqMeta(req);

    const result = await AdminService.updateUserPlan(
      adminId,
      user_id,
      is_vip !== false ? 'premium' : 'free',
      days || 30,
      reason,
      meta
    );

    return ResponseFormatter.success(
      res,
      result,
      is_vip !== false ? 'User upgraded to VIP successfully' : 'User downgraded from VIP'
    );
  }

  // ─── Subscriptions & Payments ──────────────────────────────────────────────

  static async listSubscriptions(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const status = req.query.status as string | undefined;
    const plan = req.query.plan as string | undefined;
    const provider = req.query.provider as string | undefined;
    const q = req.query.q as string | undefined;

    const data = await AdminService.listSubscriptions({ page, limit, status, plan, provider, q });
    return ResponseFormatter.success(res, data, 'Subscriptions retrieved successfully');
  }

  static async listPayments(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const status = req.query.status as string | undefined;
    const provider = req.query.provider as string | undefined;
    const from = req.query.from as string | undefined;
    const to = req.query.to as string | undefined;
    const q = req.query.q as string | undefined;

    const data = await AdminService.listPayments({ page, limit, status, provider, from, to, q });
    return ResponseFormatter.success(res, data, 'Payments retrieved successfully');
  }

  // ─── System Usage & Telemetry ──────────────────────────────────────────────

  static async getSystemUsage(req: Request, res: Response): Promise<Response> {
    const period = (req.query.period as 'day' | 'week' | 'month' | 'year') || 'month';
    const data = await AdminService.getSystemUsage(period);
    return ResponseFormatter.success(res, data, 'System usage statistics retrieved successfully');
  }

  static async getSystemStats(req: Request, res: Response): Promise<Response> {
    const stats = await AdminService.getSystemStats();
    return ResponseFormatter.success(res, stats);
  }

  static async getReports(req: Request, res: Response): Promise<Response> {
    const reports = await AdminService.getReportsSummary();
    return ResponseFormatter.success(res, reports, 'Reports summary generated successfully');
  }

  // ─── Audit Logs ────────────────────────────────────────────────────────────

  static async listAuditLogs(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const action = req.query.action as string | undefined;
    const resourceType = req.query.resource_type as string | undefined;
    const actorId = req.query.actor_id as string | undefined;
    const from = req.query.from as string | undefined;
    const to = req.query.to as string | undefined;

    const data = await AuditService.listAuditLogs({ page, limit, action, resourceType, actorId, from, to });
    return ResponseFormatter.success(res, data, 'Audit logs retrieved successfully');
  }

  // ─── Academic Directory ───────────────────────────────────────────────────

  static async listUniversities(req: Request, res: Response): Promise<Response> {
    const limit = parseInt(req.query.limit as string, 10) || 100;
    const data = await AdminService.listUniversities(limit);
    return ResponseFormatter.success(res, data);
  }

  static async listFaculties(req: Request, res: Response): Promise<Response> {
    const universityId = req.query.university_id as string | undefined;
    const limit = parseInt(req.query.limit as string, 10) || 100;
    const data = await AdminService.listFaculties(universityId, limit);
    return ResponseFormatter.success(res, data);
  }

  static async listDepartments(req: Request, res: Response): Promise<Response> {
    const facultyId = req.query.faculty_id as string | undefined;
    const limit = parseInt(req.query.limit as string, 10) || 100;
    const data = await AdminService.listDepartments(facultyId, limit);
    return ResponseFormatter.success(res, data);
  }

  static async listCourses(req: Request, res: Response): Promise<Response> {
    const departmentId = req.query.department_id as string | undefined;
    const limit = parseInt(req.query.limit as string, 10) || 100;
    const data = await AdminService.listCourses(departmentId, limit);
    return ResponseFormatter.success(res, data);
  }

  // ─── Plan Limits (with Audit Logging) ──────────────────────────────────────

  static async listPlanLimits(req: Request, res: Response): Promise<Response> {
    const { UsageService } = await import('../services/usage.service.js');
    const limits = await UsageService.listPlanLimits();
    return ResponseFormatter.success(res, limits, 'Plan limits retrieved successfully');
  }

  static async updatePlanLimit(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const { id } = req.params;
    const meta = AdminController.getReqMeta(req);
    const { UsageService } = await import('../services/usage.service.js');

    const updated = await UsageService.updatePlanLimit(id, req.body);

    await AuditService.logAction({
      actorId: adminId,
      action: 'limit_changed',
      resourceType: 'plan_limit',
      resourceId: id,
      ipAddress: meta.ip,
      userAgent: meta.userAgent,
      changes: req.body,
    });

    return ResponseFormatter.success(res, updated, 'Plan limit updated successfully');
  }

  static async createPlanLimit(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const { UsageService } = await import('../services/usage.service.js');

    const created = await UsageService.createPlanLimit(req.body);

    await AuditService.logAction({
      actorId: adminId,
      action: 'limit_created',
      resourceType: 'plan_limit',
      resourceId: (created as any)?.id || null,
      ipAddress: meta.ip,
      userAgent: meta.userAgent,
      changes: req.body,
    });

    return ResponseFormatter.created(res, created, 'Plan limit created successfully');
  }

  // ─── Verification & Extended Admin Handlers ──────────────────────────────

  static async verifyAdmin(req: Request, res: Response): Promise<Response> {
    return ResponseFormatter.success(
      res,
      {
        id: req.profile!.id,
        email: req.profile!.email,
        full_name: req.profile!.full_name,
        role: req.profile!.role,
        status: req.profile!.status,
        plan: req.profile!.plan,
      },
      'Admin verified successfully'
    );
  }

  static async getDashboardOverview(req: Request, res: Response): Promise<Response> {
    const data = await AdminService.getDashboardOverview();
    return ResponseFormatter.success(res, data, 'Dashboard overview retrieved successfully');
  }

  static async getUserDetail(req: Request, res: Response): Promise<Response> {
    const { id } = req.params;
    const detail = await AdminService.getUserDetail(id);
    return ResponseFormatter.success(res, detail, 'User detail retrieved successfully');
  }

  static async listTeachers(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const status = req.query.status as string | undefined;
    const q = req.query.q as string | undefined;

    const data = await AdminService.listAllUsers({ page, limit, role: 'teacher', status, q });
    return ResponseFormatter.success(res, data, 'Teachers retrieved successfully');
  }

  static async listStudents(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const status = req.query.status as string | undefined;
    const plan = req.query.plan as string | undefined;
    const q = req.query.q as string | undefined;

    const data = await AdminService.listAllUsers({ page, limit, role: 'student', status, plan, q });
    return ResponseFormatter.success(res, data, 'Students retrieved successfully');
  }

  // ─── Academic Hierarchy Handlers ──────────────────────────────────────────

  static async createUniversity(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.createUniversity(adminId, req.body, meta);
    return ResponseFormatter.created(res, result, 'University created successfully');
  }

  static async updateUniversity(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.updateUniversity(adminId, req.params.id, req.body, meta);
    return ResponseFormatter.success(res, result, 'University updated successfully');
  }

  static async deleteUniversity(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.deleteUniversity(adminId, req.params.id, meta);
    return ResponseFormatter.success(res, result, 'University deleted successfully');
  }

  static async createFaculty(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.createFaculty(adminId, req.body, meta);
    return ResponseFormatter.created(res, result, 'Faculty created successfully');
  }

  static async updateFaculty(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.updateFaculty(adminId, req.params.id, req.body, meta);
    return ResponseFormatter.success(res, result, 'Faculty updated successfully');
  }

  static async deleteFaculty(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.deleteFaculty(adminId, req.params.id, meta);
    return ResponseFormatter.success(res, result, 'Faculty deleted successfully');
  }

  static async createDepartment(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.createDepartment(adminId, req.body, meta);
    return ResponseFormatter.created(res, result, 'Department created successfully');
  }

  static async updateDepartment(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.updateDepartment(adminId, req.params.id, req.body, meta);
    return ResponseFormatter.success(res, result, 'Department updated successfully');
  }

  static async deleteDepartment(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.deleteDepartment(adminId, req.params.id, meta);
    return ResponseFormatter.success(res, result, 'Department deleted successfully');
  }

  static async createCourse(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.createCourse(adminId, req.body, meta);
    return ResponseFormatter.created(res, result, 'Course created successfully');
  }

  static async updateCourse(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.updateCourse(adminId, req.params.id, req.body, meta);
    return ResponseFormatter.success(res, result, 'Course updated successfully');
  }

  static async archiveCourse(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.archiveCourse(adminId, req.params.id, meta);
    return ResponseFormatter.success(res, result, 'Course archived successfully');
  }

  static async getCourseDetail(req: Request, res: Response): Promise<Response> {
    const result = await AdminService.getCourseDetail(req.params.id);
    return ResponseFormatter.success(res, result, 'Course details retrieved successfully');
  }

  // ─── Broadcast Notifications ─────────────────────────────────────────────

  static async listBroadcastNotifications(req: Request, res: Response): Promise<Response> {
    const page = parseInt(req.query.page as string, 10) || 1;
    const limit = parseInt(req.query.limit as string, 10) || 50;
    const result = await AdminService.listBroadcastNotifications(page, limit);
    return ResponseFormatter.success(res, result, 'Broadcast notifications retrieved successfully');
  }

  static async createBroadcastNotification(req: Request, res: Response): Promise<Response> {
    const adminId = req.profile!.id;
    const meta = AdminController.getReqMeta(req);
    const result = await AdminService.createBroadcastNotification(adminId, req.body, meta);
    return ResponseFormatter.created(res, result, 'Broadcast notification dispatched successfully');
  }

  // ─── System Health ───────────────────────────────────────────────────────

  static async getSystemHealth(req: Request, res: Response): Promise<Response> {
    const health = await AdminService.getSystemHealth();
    return ResponseFormatter.success(res, health, 'System health report generated successfully');
  }
}

