import { Request, Response, NextFunction } from 'express';
import { aiGateway } from './ai.service.js';
import { z } from 'zod';

const chatSchema = z.object({
  prompt: z.string().min(1),
  history: z
    .array(
      z.object({
        role: z.enum(['user', 'model']),
        parts: z.string(),
      })
    )
    .optional()
    .default([]),
});

const solveImageSchema = z.object({
  imageBase64: z.string().min(1),
  mimeType: z.string().default('image/jpeg'),
  prompt: z.string().optional(),
});

const generateQuizSchema = z.object({
  topic: z.string().min(1),
  courseName: z.string().min(1),
  questionCount: z.number().int().min(1).max(20).default(5),
  difficulty: z.enum(['easy', 'medium', 'hard']).default('medium'),
});

const generateFlashcardsSchema = z.object({
  topic: z.string().min(1),
  courseName: z.string().optional(),
  cardCount: z.number().int().min(1).max(20).default(5),
});

export const chatHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { prompt, history } = chatSchema.parse(req.body);
    const userId = req.user!.id;

    const result = await aiGateway.chatWithTeacher(userId, prompt, history);
    res.json({
      success: true,
      data: result,
      usage: req.usageInfo
        ? {
            current_usage: req.usageInfo.current_usage,
            limit: req.usageInfo.limit,
            remaining: req.usageInfo.remaining,
            reset_at: req.usageInfo.reset_at,
          }
        : undefined,
    });
  } catch (err) {
    next(err);
  }
};

export const solveImageHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { imageBase64, mimeType, prompt } = solveImageSchema.parse(req.body);
    const userId = req.user!.id;

    const result = await aiGateway.solveImageQuestion(userId, imageBase64, mimeType, prompt);
    res.json({
      success: true,
      data: result,
      usage: req.usageInfo
        ? {
            current_usage: req.usageInfo.current_usage,
            limit: req.usageInfo.limit,
            remaining: req.usageInfo.remaining,
            reset_at: req.usageInfo.reset_at,
          }
        : undefined,
    });
  } catch (err) {
    next(err);
  }
};

export const generateQuizHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { topic, courseName, questionCount, difficulty } = generateQuizSchema.parse(req.body);
    const userId = req.user!.id;

    const quiz = await aiGateway.generateQuiz(userId, topic, courseName, questionCount, difficulty);
    res.json({
      success: true,
      data: quiz,
      usage: req.usageInfo
        ? {
            current_usage: req.usageInfo.current_usage,
            limit: req.usageInfo.limit,
            remaining: req.usageInfo.remaining,
            reset_at: req.usageInfo.reset_at,
          }
        : undefined,
    });
  } catch (err) {
    next(err);
  }
};

export const generateFlashcardsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { topic, courseName, cardCount } = generateFlashcardsSchema.parse(req.body);
    const userId = req.user!.id;

    const flashcards = await aiGateway.generateFlashcards(userId, topic, courseName, cardCount);
    res.json({
      success: true,
      data: flashcards,
      usage: req.usageInfo
        ? {
            current_usage: req.usageInfo.current_usage,
            limit: req.usageInfo.limit,
            remaining: req.usageInfo.remaining,
            reset_at: req.usageInfo.reset_at,
          }
        : undefined,
    });
  } catch (err) {
    next(err);
  }
};
