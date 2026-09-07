import { Request, Response, NextFunction } from 'express';
import { aiGateway } from './ai.service.js';
import { conversationService } from './conversation.service.js';
import {
  chatSchema,
  listConversationsSchema,
  conversationIdParamSchema,
} from './validators/chat.validator.js';
import { z } from 'zod';

export const chatHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rawMessage = req.body.message ?? req.body.prompt;
    const { message, conversationId } = chatSchema.parse({
      message: rawMessage,
      conversationId: req.body.conversationId,
    });
    const userId = req.user!.id;

    // 1. Get or create conversation ensuring user ownership
    const conversation = await conversationService.getOrCreateConversation(
      userId,
      conversationId,
      message
    );

    // 2. Fetch recent conversation history for context preservation
    const history = await conversationService.getConversationHistory(conversation.id, 20);

    // 3. Save user message to database
    const approxUserTokens = Math.ceil(message.length / 4);
    await conversationService.saveMessage(
      conversation.id,
      userId,
      'user',
      message,
      approxUserTokens
    );

    // 4. Execute AI completion via provider orchestrator (with timeout, retry, failover)
    const result = await aiGateway.chatWithTeacher(userId, message, history);

    // 5. Save assistant reply to database
    const assistantMessage = await conversationService.saveMessage(
      conversation.id,
      userId,
      'assistant',
      result.text,
      result.completionTokens
    );

    // 6. Return clean structured JSON response
    res.json({
      success: true,
      data: {
        conversationId: conversation.id,
        message: {
          id: assistantMessage.id,
          role: assistantMessage.role,
          content: assistantMessage.content,
          createdAt: assistantMessage.created_at,
        },
        provider: result.provider,
        model: result.model,
        usage: {
          promptTokens: result.promptTokens,
          completionTokens: result.completionTokens,
          totalTokens: result.totalTokens,
          estimatedCost: result.estimatedCost,
          durationMs: result.durationMs,
          remaining: req.usageInfo?.remaining,
          limit: req.usageInfo?.limit,
          resetAt: req.usageInfo?.reset_at,
        },
      },
    });
  } catch (err) {
    next(err);
  }
};

export const listConversationsHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { limit, offset } = listConversationsSchema.parse(req.query);
    const userId = req.user!.id;

    const result = await conversationService.listConversations(userId, limit, offset);
    res.json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

export const getConversationHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = conversationIdParamSchema.parse(req.params);
    const userId = req.user!.id;

    const result = await conversationService.getConversationWithMessages(id, userId);
    res.json({
      success: true,
      data: result,
    });
  } catch (err) {
    next(err);
  }
};

export const deleteConversationHandler = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = conversationIdParamSchema.parse(req.params);
    const userId = req.user!.id;

    await conversationService.deleteConversation(id, userId);
    res.json({
      success: true,
      message: 'گفتوگۆکە بە سەرکەوتوویی سڕایەوە',
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
