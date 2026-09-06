import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { env } from './config/env.js';
import { apiRouter } from './routes/index.js';
import { healthRoutes } from './routes/health.routes.js';
import { errorHandler } from './middleware/errorHandler.js';
import { rateLimiter } from './middleware/rateLimiter.js';
import { NotFoundError } from './utils/apiError.js';

export const createApp = (): Express => {
  const app = express();

  // ─── 1. Security & Hardening ───
  app.use(
    helmet({
      contentSecurityPolicy: env.NODE_ENV === 'production',
      crossOriginEmbedderPolicy: false,
    })
  );

  app.use(
    cors({
      origin: env.CORS_ORIGIN === '*' ? '*' : env.CORS_ORIGIN.split(','),
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With', 'Accept'],
    })
  );

  // ─── 2. Request Parsing & Limits ───
  app.use(express.json({ limit: '25mb' }));
  app.use(express.urlencoded({ extended: true, limit: '25mb' }));

  // ─── 3. Rate Limiting ───
  app.use(rateLimiter());

  // ─── 4. Health & Liveness Probes ───
  // Available directly on /health as well as /api/health for flexible proxy routing
  app.use('/', healthRoutes);

  // ─── 5. Mount API Router ───
  app.use(env.API_PREFIX, apiRouter);

  // ─── 6. 404 Handler ───
  app.use((req: Request, res: Response, next: NextFunction) => {
    next(new NotFoundError(`Route ${req.method} ${req.originalUrl} not found`));
  });

  // ─── 7. Centralized Error Handling ───
  app.use(errorHandler);

  return app;
};

export const app = createApp();
