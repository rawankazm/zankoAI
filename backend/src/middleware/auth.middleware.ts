import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';

export interface DecodedSupabaseJwt {
  sub: string;
  email?: string;
  role?: string;
  aud?: string;
  exp?: number;
  iat?: number;
  app_metadata?: Record<string, any>;
  user_metadata?: Record<string, any>;
  [key: string]: any;
}

/**
 * Supabase JWT Authentication Middleware
 * Validates incoming Bearer token against SUPABASE_JWT_SECRET locally without remote round-trips.
 */
export const authMiddleware = (req: Request, res: Response, next: NextFunction): void => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    res.status(401).json({
      success: false,
      error: 'Unauthorized',
      message: 'Missing or malformed Authorization header. Expected Bearer <token>',
    });
    return;
  }

  const token = authHeader.substring(7).trim();
  if (!token) {
    res.status(401).json({
      success: false,
      error: 'Unauthorized',
      message: 'Bearer token is empty',
    });
    return;
  }

  const jwtSecret = process.env.SUPABASE_JWT_SECRET;
  if (!jwtSecret) {
    res.status(500).json({
      success: false,
      error: 'ConfigurationError',
      message: 'SUPABASE_JWT_SECRET is not configured on the server',
    });
    return;
  }

  try {
    const decoded = jwt.verify(token, jwtSecret, {
      algorithms: ['HS256'],
    }) as DecodedSupabaseJwt;

    if (!decoded || !decoded.sub) {
      res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Invalid token payload: missing subject identifier (sub)',
      });
      return;
    }

    // Attach verified user identity to Express Request
    req.user = {
      id: decoded.sub,
      email: decoded.email,
      role: decoded.role || 'authenticated',
      app_metadata: decoded.app_metadata,
      user_metadata: decoded.user_metadata,
    };
    req.token = token;

    next();
  } catch (err: any) {
    if (err instanceof jwt.TokenExpiredError) {
      res.status(401).json({
        success: false,
        error: 'Unauthorized',
        message: 'Authentication token has expired',
      });
      return;
    }

    res.status(401).json({
      success: false,
      error: 'Unauthorized',
      message: 'Invalid authentication token or signature verification failed',
    });
  }
};

export const authenticate = authMiddleware;
export default authMiddleware;
