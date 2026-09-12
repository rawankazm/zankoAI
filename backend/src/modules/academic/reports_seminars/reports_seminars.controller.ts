import { Request, Response } from 'express';
import { ReportsSeminarsService } from './reports_seminars.service.js';
import { ResponseFormatter } from '../../../utils/apiResponse.js';
import { AcademicQueryOptions } from './reports_seminars.interface.js';

export class ReportsSeminarsController {
  // ─── Reports Endpoints ───────────────────────────────────────────────────

  static async createReport(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const report = await ReportsSeminarsService.createReport(userId, req.body);
    return ResponseFormatter.created(res, report, 'Report created successfully');
  }

  static async getReports(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const options: AcademicQueryOptions = {
      page: req.query.page ? parseInt(req.query.page as string, 10) : undefined,
      limit: req.query.limit ? parseInt(req.query.limit as string, 10) : undefined,
      search: req.query.search as string | undefined,
      status: req.query.status as string | undefined,
      language: req.query.language as string | undefined,
    };

    const result = await ReportsSeminarsService.getReports(userId, options);
    return ResponseFormatter.success(res, result, 'Reports retrieved successfully');
  }

  static async getReportById(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const { id } = req.params;
    const report = await ReportsSeminarsService.getReportById(userId, id);
    return ResponseFormatter.success(res, report, 'Report retrieved successfully');
  }

  static async updateReport(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const { id } = req.params;
    const updated = await ReportsSeminarsService.updateReport(userId, id, req.body);
    return ResponseFormatter.success(res, updated, 'Report updated successfully');
  }

  static async deleteReport(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const { id } = req.params;
    const result = await ReportsSeminarsService.deleteReport(userId, id);
    return ResponseFormatter.success(res, result, 'Report deleted successfully');
  }

  // ─── Seminars Endpoints ──────────────────────────────────────────────────

  static async createSeminar(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const seminar = await ReportsSeminarsService.createSeminar(userId, req.body);
    return ResponseFormatter.created(res, seminar, 'Seminar created successfully');
  }

  static async getSeminars(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const options: AcademicQueryOptions = {
      page: req.query.page ? parseInt(req.query.page as string, 10) : undefined,
      limit: req.query.limit ? parseInt(req.query.limit as string, 10) : undefined,
      search: req.query.search as string | undefined,
      status: req.query.status as string | undefined,
      language: req.query.language as string | undefined,
    };

    const result = await ReportsSeminarsService.getSeminars(userId, options);
    return ResponseFormatter.success(res, result, 'Seminars retrieved successfully');
  }

  static async getSeminarById(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const { id } = req.params;
    const seminar = await ReportsSeminarsService.getSeminarById(userId, id);
    return ResponseFormatter.success(res, seminar, 'Seminar retrieved successfully');
  }

  static async updateSeminar(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const { id } = req.params;
    const updated = await ReportsSeminarsService.updateSeminar(userId, id, req.body);
    return ResponseFormatter.success(res, updated, 'Seminar updated successfully');
  }

  static async deleteSeminar(req: Request, res: Response): Promise<Response> {
    const userId = req.user!.id;
    const { id } = req.params;
    const result = await ReportsSeminarsService.deleteSeminar(userId, id);
    return ResponseFormatter.success(res, result, 'Seminar deleted successfully');
  }
}
