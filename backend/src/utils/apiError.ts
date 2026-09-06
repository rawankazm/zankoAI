export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly isOperational: boolean;
  public readonly details?: any;

  constructor(message: string, statusCode = 500, code = 'INTERNAL_ERROR', isOperational = true, details?: any) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = isOperational;
    this.details = details;

    Object.setPrototypeOf(this, new.target.prototype);
    Error.captureStackTrace(this, this.constructor);
  }
}

export class BadRequestError extends AppError {
  constructor(message = 'Bad Request', details?: any) {
    super(message, 400, 'BAD_REQUEST', true, details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Unauthorized - Please provide a valid authentication token', details?: any) {
    super(message, 401, 'UNAUTHORIZED', true, details);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Forbidden - You do not have permission to access this resource', details?: any) {
    super(message, 403, 'FORBIDDEN', true, details);
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Resource not found', details?: any) {
    super(message, 404, 'NOT_FOUND', true, details);
  }
}

export class QuotaExceededError extends AppError {
  constructor(message = 'Usage quota exceeded - Please upgrade your subscription plan', details?: any) {
    super(message, 429, 'QUOTA_EXCEEDED', true, details);
  }
}

export class RateLimitError extends AppError {
  constructor(message = 'Too many requests - Please slow down', details?: any) {
    super(message, 429, 'RATE_LIMIT_EXCEEDED', true, details);
  }
}
