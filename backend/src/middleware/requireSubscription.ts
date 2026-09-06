import { Request, Response, NextFunction } from 'express';
import { SubscriptionPlan } from '../types/user.types.js';
import { ForbiddenError, UnauthorizedError } from '../utils/apiError.js';

export const requireSubscription = (allowedPlans: SubscriptionPlan[] = ['premium'], allowVip = true) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.profile) {
      return next(new UnauthorizedError('User must be authenticated before subscription check'));
    }

    // Admins always bypass subscription restrictions
    if (req.profile.role === 'admin') {
      return next();
    }

    const isVip = req.profile.is_vip || req.profile.vip_status === 'active';
    const userPlan = req.profile.plan;

    if (allowVip && isVip) {
      return next();
    }

    if (allowedPlans.includes(userPlan)) {
      return next();
    }

    return next(
      new ForbiddenError(
        `This feature requires an upgraded subscription plan (${allowedPlans.join(', ')}). Your current plan is '${userPlan}'.`
      )
    );
  };
};
