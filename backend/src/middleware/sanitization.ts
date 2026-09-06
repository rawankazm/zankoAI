import { Request, Response, NextFunction } from 'express';
import { SecurityLogger } from '../utils/securityLogger.js';
import { BadRequestError } from '../utils/apiError.js';

const PROTOTYPE_POLLUTION_KEYS = new Set(['__proto__', 'constructor', 'prototype']);

// Basic HTML tag stripping / escaping for XSS protection
function sanitizeString(input: string): string {
  // Strip null bytes
  let cleaned = input.replace(/\0/g, '');

  // Strip control characters except newline, carriage return, and tab
  cleaned = cleaned.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '');

  // Neutralize script tags and dangerous event handlers
  cleaned = cleaned
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '')
    .replace(/javascript:/gi, 'blocked-scheme:')
    .replace(/on\w+\s*=/gi, 'data-blocked=');

  return cleaned;
}

function sanitizeValue(val: any, depth = 0): any {
  if (depth > 8 || val === null || val === undefined) return val;

  if (typeof val === 'string') {
    return sanitizeString(val);
  }

  if (Array.isArray(val)) {
    return val.map((item) => sanitizeValue(item, depth + 1));
  }

  if (typeof val === 'object') {
    const cleanedObj: Record<string, any> = {};
    for (const [key, value] of Object.entries(val)) {
      if (PROTOTYPE_POLLUTION_KEYS.has(key)) {
        throw new BadRequestError('Malicious object key detected (Prototype Pollution attempt)');
      }
      cleanedObj[key] = sanitizeValue(value, depth + 1);
    }
    return cleanedObj;
  }

  return val;
}

/**
 * Global input sanitization middleware
 */
export const sanitizeInput = (req: Request, res: Response, next: NextFunction): void => {
  try {
    if (req.body && typeof req.body === 'object') {
      req.body = sanitizeValue(req.body);
    }

    if (req.query && typeof req.query === 'object') {
      req.query = sanitizeValue(req.query);
    }

    if (req.params && typeof req.params === 'object') {
      req.params = sanitizeValue(req.params);
    }

    next();
  } catch (error: any) {
    SecurityLogger.fromRequest(req, 'SUSPICIOUS_PAYLOAD', 'WARN', 'BLOCKED', {
      error: error.message,
    });
    next(error);
  }
};
