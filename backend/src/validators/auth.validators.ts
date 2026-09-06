import { z } from 'zod';

export const updateProfileSchema = z.object({
  full_name: z.string().min(2, 'Name must be at least 2 characters').max(100),
  city_name: z.string().max(100).optional(),
  university_name: z.string().max(150).optional(),
  department_name: z.string().max(150).optional(),
  bio: z.string().max(500).optional(),
  avatar_url: z.string().url().optional().or(z.literal('')),
});
