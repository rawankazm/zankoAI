import { Response } from 'express';
import { ApiResponse } from '../types/common.types.js';

export class ResponseFormatter {
  static success<T>(res: Response, data?: T, message = 'Success', statusCode = 200): Response {
    const body: ApiResponse<T> = {
      success: true,
      message,
      data,
      timestamp: new Date().toISOString(),
    };
    return res.status(statusCode).json(body);
  }

  static created<T>(res: Response, data?: T, message = 'Resource created successfully'): Response {
    return this.success(res, data, message, 201);
  }

  static error(res: Response, message: string, statusCode = 500, code = 'INTERNAL_ERROR', details?: any): Response {
    const body: ApiResponse = {
      success: false,
      error: {
        message,
        code,
        details,
      },
      timestamp: new Date().toISOString(),
    };
    return res.status(statusCode).json(body);
  }
}
