import { z } from 'zod';

export const updateUserRoleSchema = z.object({
  user_id: z.string().uuid(),
  role: z.enum(['student', 'teacher', 'admin']),
  reason: z.string().max(500).optional(),
});

export const updateAccountStatusSchema = z.object({
  user_id: z.string().uuid(),
  status: z.enum(['active', 'suspended', 'deleted']),
  reason: z.string().max(500).optional(),
});

export const userIdParamSchema = z.object({
  id: z.string().uuid('Invalid user ID format'),
});

export const patchUserStatusBodySchema = z.object({
  status: z.enum(['active', 'suspended', 'deleted']),
  reason: z.string().max(500).optional(),
});

export const patchUserPlanBodySchema = z.object({
  plan: z.enum(['free', 'premium']),
  days: z.number().int().positive().max(3650).optional().default(30),
  reason: z.string().max(500).optional(),
});

export const patchUserRoleBodySchema = z.object({
  role: z.enum(['student', 'teacher', 'admin']),
  reason: z.string().max(500).optional(),
});

export const listUsersQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(100).optional().default(50),
  role: z.enum(['student', 'teacher', 'admin']).optional(),
  status: z.enum(['active', 'suspended', 'deleted', 'pending']).optional(),
  plan: z.enum(['free', 'premium']).optional(),
  q: z.string().max(100).optional(),
});

export const listSubscriptionsQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(100).optional().default(50),
  status: z.enum(['active', 'canceled', 'past_due', 'grace_period', 'expired', 'incomplete']).optional(),
  plan: z.string().max(50).optional(),
  provider: z.string().max(50).optional(),
  q: z.string().max(100).optional(),
});

export const listPaymentsQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(100).optional().default(50),
  status: z.enum(['completed', 'pending', 'failed', 'refunded']).optional(),
  provider: z.string().max(50).optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
  q: z.string().max(100).optional(),
});

export const listAuditLogsQuerySchema = z.object({
  page: z.coerce.number().int().positive().optional().default(1),
  limit: z.coerce.number().int().positive().max(100).optional().default(50),
  action: z.string().max(100).optional(),
  resource_type: z.string().max(100).optional(),
  actor_id: z.string().uuid().optional(),
  from: z.string().datetime().optional(),
  to: z.string().datetime().optional(),
});

export const getUsageQuerySchema = z.object({
  period: z.enum(['day', 'week', 'month', 'year']).optional().default('month'),
});
