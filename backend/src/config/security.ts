import { CorsOptions } from 'cors';
import { env } from './env.js';
import { logger } from './logger.js';

// Explicitly allowlisted origins
export const ALLOWED_ORIGINS = [
  'https://zanko-admin.vercel.app',
  'https://admin.zankoai.com',
  'https://zankoai.com',
  'https://www.zankoai.com',
  // Local development origins
  'http://localhost:3000',
  'http://localhost:4000',
  'http://localhost:5173',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:4000',
];

// Additional origins configured via environment variable (comma-separated)
if (env.CORS_ORIGIN && env.CORS_ORIGIN !== '*') {
  const extraOrigins = env.CORS_ORIGIN.split(',').map((o) => o.trim()).filter(Boolean);
  for (const origin of extraOrigins) {
    if (!ALLOWED_ORIGINS.includes(origin)) {
      ALLOWED_ORIGINS.push(origin);
    }
  }
}

/**
 * Dynamic CORS options with strict origin verification.
 * - Disallows wildcard (*) when credentials are true.
 * - Mobile apps (Flutter, Capacitor, etc.) and server-to-server requests typically send no origin (origin is undefined).
 * - Web browsers must match the allowlist.
 */
export const corsOptions: CorsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (e.g. mobile apps, curl, Postman, server-to-server)
    if (!origin) {
      return callback(null, true);
    }

    // In development or test, allow localhost and loopback variations
    if (env.NODE_ENV !== 'production') {
      if (
        origin.startsWith('http://localhost:') ||
        origin.startsWith('http://127.0.0.1:') ||
        ALLOWED_ORIGINS.includes(origin)
      ) {
        return callback(null, true);
      }
    }

    // In production, strictly check allowlist
    if (ALLOWED_ORIGINS.includes(origin)) {
      return callback(null, true);
    }

    logger.warn(`[CORS Blocked] Untrusted origin attempted access: ${origin}`);
    callback(new Error(`CORS policy violation: Origin '${origin}' is not permitted`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type',
    'Authorization',
    'X-Requested-With',
    'Accept',
    'X-Client-Version',
    'X-Request-Id',
  ],
  exposedHeaders: [
    'X-RateLimit-Limit',
    'X-RateLimit-Remaining',
    'X-RateLimit-Reset',
    'X-Usage-Limit',
    'X-Usage-Remaining',
  ],
  maxAge: 86400, // 24 hours preflight cache
};

export const SECURITY_LIMITS = {
  JSON_BODY_LIMIT: '2mb',
  URLENCODED_BODY_LIMIT: '2mb',
  DOCUMENT_UPLOAD_LIMIT_BYTES: 15 * 1024 * 1024, // 15 MB
  IMAGE_UPLOAD_LIMIT_BYTES: 5 * 1024 * 1024,      // 5 MB
};
