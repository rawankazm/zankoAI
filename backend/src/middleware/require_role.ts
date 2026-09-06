import { Request, Response, NextFunction } from 'express';

export const requireRole = (allowedRoles: Array<'student' | 'teacher' | 'admin'>) => {
  return (req: Request, res: Response, next: NextFunction) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        error: 'Unauthorized: Authentication required',
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        error: `Forbidden: Access restricted to roles: ${allowedRoles.join(', ')}`,
      });
    }

    next();
  };
};
