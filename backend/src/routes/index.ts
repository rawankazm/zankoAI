import { Router } from 'express';
import { healthRoutes } from './health.routes.js';
import { authRoutes } from './auth.routes.js';
import { teacherRoutes } from './teacher.routes.js';
import { adminRoutes } from './admin.routes.js';

const apiRouter = Router();

// Mount sub-routers
apiRouter.use('/', healthRoutes); // Provides /api/health and /api/ready
apiRouter.use('/auth', authRoutes);
apiRouter.use('/teacher', teacherRoutes);
apiRouter.use('/admin', adminRoutes);

export { apiRouter };
