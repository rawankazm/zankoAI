import dotenv from 'dotenv';
import { z } from 'zod';

dotenv.config();

const envSchema = z.object({
  PORT: z
    .string()
    .default('4000')
    .transform((val) => parseInt(val, 10)),
  NODE_ENV: z.enum(['development', 'staging', 'production', 'test']).default('development'),
  API_PREFIX: z.string().default('/api'),
  CORS_ORIGIN: z.string().default('https://zankoai.com'),

  // Supabase Credentials (Headless Auth & Self-Hosted PostgREST Engine)
  SUPABASE_URL: z.string().default('http://postgrest:3000'),
  SUPABASE_ANON_KEY: z.string().min(1).default('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiZXhwIjoyNTI0NjA4MDAwfQ._yGDnGXilGQzpkjZy4aNQjD5gPb8JqY9m3an0j7PQog'),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1).default('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoicG9zdGdyZXMiLCJpc3MiOiJzdXBhYmFzZSIsImV4cCI6MjUyNDYwODAwMH0.S3ubvgdtgcamzqf-d0xJITu8C6wIriT56ekZxowJ-VU'),
  SUPABASE_JWT_SECRET: z.string().min(32).default('zanko_production_secure_jwt_secret_min_32_chars_2026'),

  // PostgreSQL Configuration (Self-Hosted)
  DATABASE_URL: z.string().optional(),
  POSTGRES_HOST: z.string().default('postgres'),
  POSTGRES_PORT: z
    .string()
    .default('5432')
    .transform((val) => parseInt(val, 10)),
  POSTGRES_DB: z.string().default('zanko_db'),
  POSTGRES_USER: z.string().default('postgres'),
  POSTGRES_PASSWORD: z.string().default('postgres_secure_zanko_2026'),

  // Storage Configuration (Self-Hosted Local Volume)
  STORAGE_PATH: z.string().default('/app/uploads'),

  // Redis Configuration
  REDIS_HOST: z.string().default('127.0.0.1'),
  REDIS_PORT: z
    .string()
    .default('6379')
    .transform((val) => parseInt(val, 10)),
  REDIS_PASSWORD: z.string().optional(),
  REDIS_TLS: z
    .string()
    .default('false')
    .transform((val) => val === 'true'),

  // Rate Limiting Config
  RATE_LIMIT_WINDOW_MS: z
    .string()
    .default('60000')
    .transform((val) => parseInt(val, 10)),
  RATE_LIMIT_MAX_REQUESTS: z
    .string()
    .default('100')
    .transform((val) => parseInt(val, 10)),

  // AI Provider Configurations & API Keys
  DEFAULT_AI_PROVIDER: z.enum(['google', 'openai', 'anthropic']).default('google'),
  GEMINI_API_KEY: z.string().optional(),
  GEMINI_MODEL: z.string().default('gemini-3.5-flash-lite'),
  OPENAI_API_KEY: z.string().optional(),
  OPENAI_MODEL: z.string().default('gpt-4o-mini'),
  ANTHROPIC_API_KEY: z.string().optional(),
  ANTHROPIC_MODEL: z.string().default('claude-3-5-haiku-20241022'),
  AI_TIMEOUT_MS: z
    .string()
    .default('30000')
    .transform((val) => parseInt(val, 10)),
  AI_MAX_RETRIES: z
    .string()
    .default('2')
    .transform((val) => parseInt(val, 10)),

  // TTS Provider Configurations & API Keys (Server-Side Only)
  DEFAULT_TTS_PROVIDER: z.enum(['google', 'elevenlabs', 'fallback']).default('google'),
  GOOGLE_TTS_API_KEY: z.string().optional(),
  ELEVENLABS_API_KEY: z.string().optional(),
  ELEVENLABS_VOICE_ID: z.string().default('CwhRBWXzGAHq8TQ4Fs17'),

  // Payment Gateways — Optional in core deployment
  FIB_BASE_URL: z.string().default('https://api.fib.iq'),
  FIB_CLIENT_ID: z.string().optional(),
  FIB_CLIENT_SECRET: z.string().optional(),
  FASTPAY_MERCHANT_ID: z.string().optional(),
  FASTPAY_PASSWORD: z.string().optional(),
  ZAINCASH_MSISDN: z.string().optional(),
  ZAINCASH_SECRET: z
    .string()
    .optional()
    .transform((val) => (val && val.trim().length > 0 && !val.startsWith('your-') ? val.trim() : undefined)),
  QI_CARD_SECRET_KEY: z
    .string()
    .optional()
    .transform((val) => (val && val.trim().length > 0 && !val.startsWith('your-') ? val.trim() : undefined)),

  // Notifications
  NOTIFICATION_SECRET: z
    .string()
    .optional()
    .transform((val) => (val && val.trim().length > 0 && !val.startsWith('your-') ? val.trim() : undefined)),
});

export type Env = z.infer<typeof envSchema>;

export const validateEnv = (): Env => {
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    console.error('❌ Environment configuration validation failed:');
    console.error(parsed.error.format());
    process.exit(1);
  }

  const cfg = parsed.data;

  // SECURITY [C-04]: Reject wildcard CORS in production — prevents auth bypass from any origin.
  if (cfg.NODE_ENV === 'production' && (cfg.CORS_ORIGIN === '*' || !cfg.CORS_ORIGIN)) {
    console.error('❌ SECURITY: CORS_ORIGIN cannot be "*" or empty in production. Set it to your explicit domain(s).');
    process.exit(1);
  }

  // In production, warn if default JWT secret is in use
  if (cfg.NODE_ENV === 'production') {
    if (cfg.SUPABASE_JWT_SECRET === 'zanko_production_secure_jwt_secret_min_32_chars_2026') {
      console.warn('⚠️ Note: Default production JWT secret in use. Recommended to supply custom SUPABASE_JWT_SECRET in .env.production');
    }
  }

  return cfg;
};

export const env = validateEnv();
