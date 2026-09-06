import { Request, Response, NextFunction } from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { ForbiddenError, NotFoundError, UnauthorizedError } from '../utils/apiError.js';
import { SecurityLogger } from '../utils/securityLogger.js';

export interface OwnershipOptions {
  tableName: string;
  idParam?: string; // param name in req.params, default 'id'
  ownerColumn?: string; // column holding user ID, default 'user_id' or 'creator_id'
  resourceName?: string;
  allowAdmin?: boolean; // default true
}

/**
 * Express middleware to enforce resource ownership (prevents IDOR).
 * Blocks users from reading/modifying resources they do not own unless they are an admin.
 */
export const enforceOwnership = (options: OwnershipOptions) => {
  const {
    tableName,
    idParam = 'id',
    ownerColumn = 'user_id',
    resourceName = 'Resource',
    allowAdmin = true,
  } = options;

  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
      if (!req.user || !req.profile) {
        return next(new UnauthorizedError('User must be authenticated before checking ownership'));
      }

      const resourceId = req.params[idParam];
      if (!resourceId) {
        return next();
      }

      // Admins bypass ownership checks if allowed
      if (allowAdmin && req.profile.role === 'admin') {
        return next();
      }

      // Fetch the owner ID of the target resource
      const { data, error } = await supabaseAdmin
        .from(tableName)
        .select(ownerColumn)
        .eq('id', resourceId)
        .maybeSingle();

      if (error || !data) {
        return next(new NotFoundError(`${resourceName} not found`));
      }

      const ownerId = (data as any)[ownerColumn];

      if (ownerId !== req.user.id) {
        SecurityLogger.fromRequest(req, 'IDOR_ATTEMPT', 'CRITICAL', 'BLOCKED', {
          tableName,
          resourceId,
          resourceOwner: ownerId,
          attemptedBy: req.user.id,
        });

        return next(
          new ForbiddenError(`Access denied: You do not own this ${resourceName.toLowerCase()}`)
        );
      }

      next();
    } catch (err) {
      next(err);
    }
  };
};

/**
 * Programmatic ownership check for service layer
 */
export function verifyResourceOwnership(
  resourceOwnerId: string,
  callerId: string,
  callerRole: string,
  resourceDescription = 'resource'
): void {
  if (callerRole === 'admin') {
    return;
  }

  if (resourceOwnerId !== callerId) {
    throw new ForbiddenError(`Access denied: You can only modify your own ${resourceDescription}`);
  }
}
