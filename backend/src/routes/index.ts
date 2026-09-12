import { Router } from 'express';
import { healthRoutes } from './health.routes.js';
import { authRoutes } from './auth.routes.js';
import { teacherRoutes } from './teacher.routes.js';
import { adminRoutes } from './admin.routes.js';
import { academicRoutes } from './academic.routes.js';
import { learningRoutes } from './learning.routes.js';
import { personalRoutes } from './personal.routes.js';
import { userRoutes } from './user.routes.js';
import { paymentRoutes } from './payment.routes.js';
import { aiRoutes } from '../modules/ai/ai.routes.js';
import { aiTeacherRoutes } from '../modules/ai/ai_teacher/ai_teacher.routes.js';
import { storageRoutes } from './storage.routes.js';
import { usageRoutes } from './usage.routes.js';
import { subscriptionRoutes } from './subscription.routes.js';
import { notificationRoutes } from './notification.routes.js';
import { deviceRoutes } from './device.routes.js';
import { reportsRouter, seminarsRouter } from '../modules/academic/reports_seminars/reports_seminars.routes.js';

const apiRouter = Router();

// 1. Health & Probes (/api/health, /api/ready)
apiRouter.use('/', healthRoutes);

// 2. Auth & Profiles (/api/auth/profile, /api/users)
apiRouter.use('/auth', authRoutes);
apiRouter.use('/users', userRoutes);

// 3. Academic Structure (/api/universities, /api/faculties, /api/departments, /api/courses)
apiRouter.use('/', academicRoutes);

// 4. Learning Materials (/api/lectures, /api/assignments, /api/quizzes, /api/flashcards)
apiRouter.use('/', learningRoutes);

// 5. Personal & Progress (/api/calendar, /api/progress, /api/notifications)
apiRouter.use('/', personalRoutes);

// 6. Role-Specific Dedicated Subsystems
apiRouter.use('/teacher', teacherRoutes);
apiRouter.use('/admin', adminRoutes);

// 7. Secure Payments & VIP Subscriptions (/api/payments)
apiRouter.use('/payments', paymentRoutes);

// 8. AI Services with Server-Enforced Quotas & Rate Limits (/api/ai and /api/ai-teacher)
apiRouter.use('/ai', aiRoutes);
apiRouter.use('/ai-teacher', aiTeacherRoutes);
apiRouter.use('/v1/ai-teacher', aiTeacherRoutes);

// 9. Secure Supabase Storage (/api/storage)
apiRouter.use('/storage', storageRoutes);

// 10. Centralized Usage Limits & Quotas (/api/usage)
apiRouter.use('/usage', usageRoutes);

// 11. Production Subscription Architecture (/api/subscription)
apiRouter.use('/subscription', subscriptionRoutes);

// 12. Production Push Notifications (/api/notifications) & Multi-Device Registration (/api/devices)
apiRouter.use('/notifications', notificationRoutes);
apiRouter.use('/devices', deviceRoutes);

// 13. Reports & Seminars System (/api/reports, /api/seminars)
apiRouter.use('/reports', reportsRouter);
apiRouter.use('/v1/reports', reportsRouter);
apiRouter.use('/seminars', seminarsRouter);
apiRouter.use('/v1/seminars', seminarsRouter);

export { apiRouter };

