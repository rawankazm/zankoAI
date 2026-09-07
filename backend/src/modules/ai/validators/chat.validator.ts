import { z } from 'zod';

export const chatSchema = z.object({
  message: z
    .string()
    .trim()
    .min(1, { message: 'پەیام ناتوانێت بەتاڵ بێت' })
    .max(4000, { message: 'پەیام ناتوانێت لە ٤٠٠٠ پیت زیاتر بێت' }),
  conversationId: z
    .string()
    .uuid({ message: 'ئایدی گفتوگۆ دەبێت شێوازێکی دروستی UUID بێت' })
    .optional(),
});

export const listConversationsSchema = z.object({
  limit: z
    .string()
    .optional()
    .transform((val) => (val ? Math.min(50, Math.max(1, parseInt(val, 10) || 20)) : 20)),
  offset: z
    .string()
    .optional()
    .transform((val) => (val ? Math.max(0, parseInt(val, 10) || 0) : 0)),
});

export const conversationIdParamSchema = z.object({
  id: z.string().uuid({ message: 'ئایدی گفتوگۆ دروست نییە' }),
});

export type ChatInput = z.infer<typeof chatSchema>;
