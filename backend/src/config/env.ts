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

  // Supabase Credentials (Strictly Server-Side)
  SUPABASE_URL: z.string().url().default('https://placeholder.supabase.co'),
  SUPABASE_ANON_KEY: z.string().min(1).default('placeholder-anon-key'),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1).default('placeholder-service-role-key'),
  // SECURITY [C-01]: SUPABASE_JWT_SECRET must be set explicitly — no insecure default.
  SUPABASE_JWT_SECRET: z.string().min(32).default('REPLACE_ME_SUPABASE_JWT_SECRET_32_CHARS_MIN'),

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

  // Payment Gateways — SECURITY [C-01]: All secrets required in production; no insecure fallbacks.
  FIB_CLIENT_ID: z.string().optional(),
  FIB_CLIENT_SECRET: z.string().optional(),
  FASTPAY_MERCHANT_ID: z.string().optional(),
  FASTPAY_PASSWORD: z.string().optional(),
  ZAINCASH_MSISDN: z.string().optional(),
  // SECURITY [C-01]: Required — used to sign/verify ZainCash JWT tokens.
  ZAINCASH_SECRET: z.string().min(32).optional(),
  QI_CARD_SECRET_KEY: z.string().min(32).optional(),

  // Notifications — SECURITY [C-01]: Must be a strong random secret in production.
  NOTIFICATION_SECRET: z.string().min(32).optional(),
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

  // SECURITY [C-01]: Reject placeholder/default secrets in production.
  if (cfg.NODE_ENV === 'production') {
    const insecureDefaults = [
      'REPLACE_ME_SUPABASE_JWT_SECRET_32_CHARS_MIN',
      'placeholder-jwt-secret',
      'placeholder-service-role-key',
      'placeholder-anon-key',
    ];
    if (insecureDefaults.some(d => cfg.SUPABASE_JWT_SECRET?.includes(d) || cfg.SUPABASE_SERVICE_ROLE_KEY?.includes(d))) {
      console.error('❌ SECURITY: Placeholder secrets detected in production environment. Set real values in environment variables.');
      process.exit(1);
    }
  }

  return cfg;
};

export const env = validateEnv();
