import express, { Express, Request, Response, NextFunction } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { env } from './config/env.js';
import { corsOptions, SECURITY_LIMITS } from './config/security.js';
import { apiRouter } from './routes/index.js';
import { healthRoutes } from './routes/health.routes.js';
import { requestLogger } from './middleware/request_logger.js';
import { errorHandler } from './middleware/errorHandler.js';
import { rateLimiter } from './middleware/rateLimiter.js';
import { sanitizeInput } from './middleware/sanitization.js';
import { NotFoundError } from './utils/apiError.js';

export const createApp = (): Express => {
  const app = express();

  // ─── 0. Structured JSON Request Tracing & Production Latency Logger ───
  app.use(requestLogger);

  // ─── 1. Core Security & Fingerprint Reduction ───
  app.disable('x-powered-by');

  // Helmet with comprehensive security directives
  app.use(
    helmet({
      contentSecurityPolicy: env.NODE_ENV === 'production' ? {
        directives: {
          defaultSrc: ["'self'"],
          baseUri: ["'self'"],
          fontSrc: ["'self'", 'https:', 'data:'],
          formAction: ["'self'"],
          frameAncestors: ["'none'"],
          imgSrc: ["'self'", 'data:', 'https:'],
          objectSrc: ["'none'"],
          scriptSrc: ["'self'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          upgradeInsecureRequests: [],
        },
      } : false,
      crossOriginEmbedderPolicy: false,
      hsts: {
        maxAge: 31536000, // 1 year
        includeSubDomains: true,
        preload: true,
      },
      noSniff: true,
      frameguard: { action: 'deny' },
      referrerPolicy: { policy: 'strict-origin-when-cross-origin' },
      permittedCrossDomainPolicies: { permittedPolicies: 'none' },
    })
  );

  // CORS with strict origin validation
  app.use(cors(corsOptions));

  // ─── 2. Request Parsing & Strict Body Limits ───
  // Lowered from 25MB to 2MB to eliminate memory exhaustion DoS vectors
  app.use(express.json({ limit: SECURITY_LIMITS.JSON_BODY_LIMIT }));
  app.use(express.urlencoded({ extended: true, limit: SECURITY_LIMITS.URLENCODED_BODY_LIMIT }));

  // ─── 3. Global Input Sanitization ───
  // Strips null bytes, neutralizes prototype pollution attempts and XSS injections
  app.use(sanitizeInput);

  // ─── 4. Secure API Headers Middleware ───
  // Enforces no-store caching on all API endpoints to protect sensitive user data
  app.use((req: Request, res: Response, next: NextFunction) => {
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    next();
  });

  // ─── 5. Global Rate Limiting ───
  app.use(rateLimiter());

  // ─── 6. Health & Liveness Probes ───
  app.use('/', healthRoutes);

  // ─── 7. Mount API Router ───
  app.use(env.API_PREFIX, apiRouter);

  // ─── 8. 404 Catch-All ───
  app.use((req: Request, res: Response, next: NextFunction) => {
    next(new NotFoundError(`Route ${req.method} ${req.originalUrl} not found`));
  });

  // ─── 9. Centralized Error Handling ───
  app.use(errorHandler);

  return app;
};

export const app = createApp();
export default app;
