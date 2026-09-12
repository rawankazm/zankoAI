import { z } from 'zod';

const sectionSchema = z.object({
  section_order: z.number().int().min(0).optional(),
  title: z.string().max(255).optional(),
  content: z.string().optional(),
});

export const createReportSchema = z.object({
  title: z.string().min(1, 'Title is required').max(300),
  subject: z.string().max(200).optional(),
  language: z.enum(['ku', 'ar', 'en']).default('ku'),
  topic: z.string().max(300).optional(),
  description: z.string().optional(),
  content: z.string().optional(),
  status: z.enum(['draft', 'processing', 'completed', 'failed', 'archived']).default('completed'),
  sections: z.array(sectionSchema).optional(),
});

export const updateReportSchema = createReportSchema.partial();

export const createSeminarSchema = z.object({
  title: z.string().min(1, 'Title is required').max(300),
  subject: z.string().max(200).optional(),
  language: z.enum(['ku', 'ar', 'en']).default('ku'),
  topic: z.string().max(300).optional(),
  description: z.string().optional(),
  content: z.string().optional(),
  status: z.enum(['draft', 'processing', 'completed', 'failed', 'archived']).default('completed'),
  sections: z.array(sectionSchema).optional(),
});

export const updateSeminarSchema = createSeminarSchema.partial();

export const academicQuerySchema = z.object({
  page: z.string().optional(),
  limit: z.string().optional(),
  search: z.string().optional(),
  status: z.string().optional(),
  language: z.string().optional(),
});
