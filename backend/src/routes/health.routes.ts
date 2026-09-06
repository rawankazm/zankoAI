import { Router } from 'express';
import { HealthController } from '../controllers/health.controller.js';
import { asyncWrapper } from '../utils/asyncWrapper.js';

const router = Router();

// Liveness probe (e.g. Docker / Kubernetes / DigitalOcean load balancer)
router.get('/health', HealthController.getHealth);

// Readiness probe (verifies database & Redis connectivity)
router.get('/ready', asyncWrapper(HealthController.getReady));

export const healthRoutes = router;
