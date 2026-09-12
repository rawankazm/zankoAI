import { Router } from 'express';
import { ReportsSeminarsController } from './reports_seminars.controller.js';
import { authenticateUser } from '../../../middleware/authenticateUser.js';
import { validateRequest } from '../../../middleware/validateRequest.js';
import { asyncWrapper } from '../../../utils/asyncWrapper.js';
import {
  createReportSchema,
  updateReportSchema,
  createSeminarSchema,
  updateSeminarSchema,
  academicQuerySchema,
} from '../../../validators/reports_seminars.validators.js';

// ─── Reports Router ──────────────────────────────────────────────────────────
const reportsRouter = Router();

// All reports routes require authenticated Supabase user
reportsRouter.use(authenticateUser);

reportsRouter.post(
  '/',
  validateRequest({ body: createReportSchema }),
  asyncWrapper(ReportsSeminarsController.createReport)
);

reportsRouter.get(
  '/',
  validateRequest({ query: academicQuerySchema }),
  asyncWrapper(ReportsSeminarsController.getReports)
);

reportsRouter.get(
  '/:id',
  asyncWrapper(ReportsSeminarsController.getReportById)
);

reportsRouter.patch(
  '/:id',
  validateRequest({ body: updateReportSchema }),
  asyncWrapper(ReportsSeminarsController.updateReport)
);

reportsRouter.delete(
  '/:id',
  asyncWrapper(ReportsSeminarsController.deleteReport)
);

// ─── Seminars Router ─────────────────────────────────────────────────────────
const seminarsRouter = Router();

// All seminars routes require authenticated Supabase user
seminarsRouter.use(authenticateUser);

seminarsRouter.post(
  '/',
  validateRequest({ body: createSeminarSchema }),
  asyncWrapper(ReportsSeminarsController.createSeminar)
);

seminarsRouter.get(
  '/',
  validateRequest({ query: academicQuerySchema }),
  asyncWrapper(ReportsSeminarsController.getSeminars)
);

seminarsRouter.get(
  '/:id',
  asyncWrapper(ReportsSeminarsController.getSeminarById)
);

seminarsRouter.patch(
  '/:id',
  validateRequest({ body: updateSeminarSchema }),
  asyncWrapper(ReportsSeminarsController.updateSeminar)
);

seminarsRouter.delete(
  '/:id',
  asyncWrapper(ReportsSeminarsController.deleteSeminar)
);

export { reportsRouter, seminarsRouter };
