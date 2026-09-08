import winston from 'winston';
import { env } from './env.js';

const { combine, timestamp, printf, colorize, json, errors } = winston.format;

// Sensitive keys pattern to redact from all log outputs (Strict Zero-Leakage Policy)
const SENSITIVE_KEY_REGEX = /^(password|pass|new_password|old_password|token|access_token|refresh_token|authorization|auth_token|cookie|secret|jwt_secret|api_key|apikey|gemini_api_key|openai_api_key|anthropic_api_key|deepseek_api_key|service_role_key|anon_key|client_secret|cvv|cvc|security_code|card_number|credit_card|pan|card_data)$/i;

// Recursively sanitize objects and arrays
export function redactSensitiveData(obj: any, depth = 0): any {
  if (depth > 6 || obj === null || obj === undefined) return obj;

  if (typeof obj === 'string') {
    // Redact Bearer tokens, AI API keys, and payment card numbers in raw strings
    return obj
      .replace(/Bearer\s+[A-Za-z0-9-_=.]+/gi, 'Bearer [REDACTED]')
      .replace(/(AIzaSy[A-Za-z0-9-_]{20,})/gi, '[REDACTED_API_KEY]')
      .replace(/(sk-[A-Za-z0-9-_]{20,})/gi, '[REDACTED_API_KEY]')
      .replace(/(sk-ant-[A-Za-z0-9-_]{20,})/gi, '[REDACTED_API_KEY]')
      .replace(/\b(?:\d{4}[ -]?){3}\d{4}\b/g, '[REDACTED_CARD_NUMBER]');
  }

  if (Array.isArray(obj)) {
    return obj.map((item) => redactSensitiveData(item, depth + 1));
  }

  if (typeof obj === 'object') {
    const redacted: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      if (SENSITIVE_KEY_REGEX.test(key)) {
        redacted[key] = '[REDACTED]';
      } else if (typeof value === 'object' && value !== null) {
        redacted[key] = redactSensitiveData(value, depth + 1);
      } else if (typeof value === 'string') {
        redacted[key] = redactSensitiveData(value, depth + 1);
      } else {
        redacted[key] = value;
      }
    }
    return redacted;
  }

  return obj;
}

// Winston format for redaction
const redactFormat = winston.format((info) => {
  return redactSensitiveData(info) as winston.Logform.TransformableInfo;
});

const devFormat = printf(({ level, message, timestamp, stack, ...meta }) => {
  const metaString = Object.keys(meta).length ? JSON.stringify(meta, null, 2) : '';
  return `[${timestamp}] ${level}: ${stack || message} ${metaString}`;
});

export const logger = winston.createLogger({
  level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  format: combine(
    redactFormat(),
    timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    errors({ stack: true }),
    env.NODE_ENV === 'production' ? json() : combine(colorize(), devFormat)
  ),
  defaultMeta: { service: 'zanko-backend' },
  transports: [
    new winston.transports.Console({
      silent: env.NODE_ENV === 'test',
    }),
  ],
});
