import { z } from 'zod';

export const updateUserRoleSchema = z.object({
  user_id: z.string().uuid(),
  role: z.enum(['student', 'teacher', 'admin']),
});

export const updateAccountStatusSchema = z.object({
  user_id: z.string().uuid(),
  status: z.enum(['active', 'suspended', 'deleted']),
  reason: z.string().max(250).optional(),
});
