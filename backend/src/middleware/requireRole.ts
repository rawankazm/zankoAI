import { Request, Response, NextFunction } from 'express';
import { UserRole } from '../types/user.types.js';
import { ForbiddenError, UnauthorizedError } from '../utils/apiError.js';
import { SecurityLogger } from '../utils/securityLogger.js';

export const requireRole = (allowedRoles: UserRole[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.profile) {
      return next(new UnauthorizedError('User must be authenticated before role check'));
    }

    const userRole = req.profile.role;

    if (!allowedRoles.includes(userRole)) {
      SecurityLogger.fromRequest(req, 'PRIVILEGE_ESCALATION_ATTEMPT', 'WARN', 'DENIED', {
        userRole,
        allowedRoles,
        attemptedResource: `${req.method} ${req.originalUrl}`,
      });

      return next(
        new ForbiddenError(
          `Access denied. Role '${userRole}' is not authorized. Allowed roles: [${allowedRoles.join(', ')}]`
        )
      );
    }

    next();
  };
};
