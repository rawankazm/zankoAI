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
  CORS_ORIGIN: z.string().default('*'),

  // Supabase Credentials (Strictly Server-Side)
  SUPABASE_URL: z.string().url().default('https://placeholder.supabase.co'),
  SUPABASE_ANON_KEY: z.string().min(1).default('placeholder-anon-key'),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1).default('placeholder-service-role-key'),
  SUPABASE_JWT_SECRET: z.string().default('placeholder-jwt-secret'),

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

  // Future Payment Gateways (placeholders)
  FIB_CLIENT_ID: z.string().optional(),
  FIB_CLIENT_SECRET: z.string().optional(),
  FASTPAY_MERCHANT_ID: z.string().optional(),
});

export type Env = z.infer<typeof envSchema>;

export const validateEnv = (): Env => {
  const parsed = envSchema.safeParse(process.env);
  if (!parsed.success) {
    console.error('❌ Environment configuration validation failed:');
    console.error(parsed.error.format());
    process.exit(1);
  }
  return parsed.data;
};

export const env = validateEnv();
