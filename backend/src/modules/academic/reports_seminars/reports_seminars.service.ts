import { ReportsSeminarsRepository } from './reports_seminars.repository.js';
import {
  AcademicReport,
  CreateReportDTO,
  UpdateReportDTO,
  Seminar,
  CreateSeminarDTO,
  UpdateSeminarDTO,
  AcademicQueryOptions,
} from './reports_seminars.interface.js';
import { NotFoundError, ForbiddenError, BadRequestError } from '../../../utils/apiError.js';
import { redis } from '../../../config/redis.js';
import { logger } from '../../../config/logger.js';

export class ReportsSeminarsService {
  // ─── Reports Service ──────────────────────────────────────────────────────

  static async createReport(userId: string, dto: CreateReportDTO): Promise<AcademicReport> {
    if (!dto.title || dto.title.trim().length === 0) {
      throw new BadRequestError('Report title is required.');
    }

    const report = await ReportsSeminarsRepository.createReport(userId, {
      ...dto,
      title: dto.title.trim(),
    });

    // Invalidate user report cache list
    try {
      await redis.del(`user:${userId}:reports:list:*`);
    } catch (_) {}

    return report;
  }

  static async getReports(
    userId: string,
    options: AcademicQueryOptions = {}
  ): Promise<{ reports: AcademicReport[]; total: number; page: number; limit: number }> {
    const page = Math.max(1, options.page || 1);
    const limit = Math.min(50, Math.max(1, options.limit || 20));

    const result = await ReportsSeminarsRepository.getReportsByUser(userId, {
      ...options,
      page,
      limit,
    });

    return {
      reports: result.reports,
      total: result.total,
      page,
      limit,
    };
  }

  static async getReportById(userId: string, reportId: string): Promise<AcademicReport> {
    const report = await ReportsSeminarsRepository.getReportById(reportId);
    if (!report) {
      throw new NotFoundError('Report not found.');
    }

    // Ownership Verification (IDOR Protection)
    if (report.user_id !== userId) {
      logger.warn(`[IDOR Attempt] User ${userId} tried to access Report ${reportId} owned by ${report.user_id}`);
      throw new ForbiddenError('You do not have permission to view this report.');
    }

    return report;
  }

  static async updateReport(
    userId: string,
    reportId: string,
    dto: UpdateReportDTO
  ): Promise<AcademicReport> {
    // 1. Verify existence & ownership
    await this.getReportById(userId, reportId);

    // 2. Perform update
    const updated = await ReportsSeminarsRepository.updateReport(reportId, dto);
    if (!updated) {
      throw new NotFoundError('Report not found after update.');
    }

    // Invalidate cache
    try {
      await redis.del(`user:${userId}:reports:list:*`);
    } catch (_) {}

    return updated;
  }

  static async deleteReport(userId: string, reportId: string): Promise<{ success: boolean }> {
    // 1. Verify existence & ownership
    await this.getReportById(userId, reportId);

    // 2. Delete
    await ReportsSeminarsRepository.deleteReport(reportId);

    // Invalidate cache
    try {
      await redis.del(`user:${userId}:reports:list:*`);
    } catch (_) {}

    return { success: true };
  }

  // ─── Seminars Service ─────────────────────────────────────────────────────

  static async createSeminar(userId: string, dto: CreateSeminarDTO): Promise<Seminar> {
    if (!dto.title || dto.title.trim().length === 0) {
      throw new BadRequestError('Seminar title is required.');
    }

    const seminar = await ReportsSeminarsRepository.createSeminar(userId, {
      ...dto,
      title: dto.title.trim(),
    });

    try {
      await redis.del(`user:${userId}:seminars:list:*`);
    } catch (_) {}

    return seminar;
  }

  static async getSeminars(
    userId: string,
    options: AcademicQueryOptions = {}
  ): Promise<{ seminars: Seminar[]; total: number; page: number; limit: number }> {
    const page = Math.max(1, options.page || 1);
    const limit = Math.min(50, Math.max(1, options.limit || 20));

    const result = await ReportsSeminarsRepository.getSeminarsByUser(userId, {
      ...options,
      page,
      limit,
    });

    return {
      seminars: result.seminars,
      total: result.total,
      page,
      limit,
    };
  }

  static async getSeminarById(userId: string, seminarId: string): Promise<Seminar> {
    const seminar = await ReportsSeminarsRepository.getSeminarById(seminarId);
    if (!seminar) {
      throw new NotFoundError('Seminar not found.');
    }

    // Ownership Verification (IDOR Protection)
    if (seminar.user_id !== userId) {
      logger.warn(`[IDOR Attempt] User ${userId} tried to access Seminar ${seminarId} owned by ${seminar.user_id}`);
      throw new ForbiddenError('You do not have permission to view this seminar.');
    }

    return seminar;
  }

  static async updateSeminar(
    userId: string,
    seminarId: string,
    dto: UpdateSeminarDTO
  ): Promise<Seminar> {
    await this.getSeminarById(userId, seminarId);

    const updated = await ReportsSeminarsRepository.updateSeminar(seminarId, dto);
    if (!updated) {
      throw new NotFoundError('Seminar not found after update.');
    }

    try {
      await redis.del(`user:${userId}:seminars:list:*`);
    } catch (_) {}

    return updated;
  }

  static async deleteSeminar(userId: string, seminarId: string): Promise<{ success: boolean }> {
    await this.getSeminarById(userId, seminarId);

    await ReportsSeminarsRepository.deleteSeminar(seminarId);

    try {
      await redis.del(`user:${userId}:seminars:list:*`);
    } catch (_) {}

    return { success: true };
  }
}
