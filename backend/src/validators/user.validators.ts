import { z } from 'zod';

export const updateUserProfileSchema = z.object({
  full_name: z.string().min(2, 'Name must be at least 2 characters').max(100).optional(),
  city_name: z.string().max(100).optional().nullable(),
  university_name: z.string().max(150).optional().nullable(),
  department_name: z.string().max(150).optional().nullable(),
  university_id: z.string().uuid().optional().nullable(),
  department_id: z.string().uuid().optional().nullable(),
  bio: z.string().max(500).optional().nullable(),
  avatar_url: z.string().url().optional().or(z.literal('')).nullable(),
});

export const adminUpdateUserSchema = updateUserProfileSchema.extend({
  role: z.enum(['student', 'teacher', 'admin']).optional(),
  status: z.enum(['active', 'suspended', 'deleted']).optional(),
  plan: z.enum(['free', 'premium']).optional(),
  score: z.number().int().min(0).optional(),
  rank_title: z.string().max(100).optional(),
});
