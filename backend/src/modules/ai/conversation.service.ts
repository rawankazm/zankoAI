import { supabaseAdmin } from '../../config/supabase.js';
import { NotFoundError, ForbiddenError } from '../../utils/apiError.js';
import { logger } from '../../config/logger.js';

export interface ConversationSummary {
  id: string;
  title: string;
  created_at: string;
  updated_at: string;
  message_count?: number;
  last_message?: string;
}

export interface ConversationDetail extends ConversationSummary {
  messages: Array<{
    id: string;
    role: 'user' | 'assistant' | 'system';
    content: string;
    tokens: number;
    created_at: string;
  }>;
}

export class ConversationService {
  /**
   * Retrieves an existing conversation ensuring user ownership, or creates a new one
   */
  async getOrCreateConversation(
    userId: string,
    conversationId?: string,
    initialPrompt?: string
  ): Promise<{ id: string; title: string }> {
    if (conversationId) {
      const { data, error } = await supabaseAdmin
        .from('conversations')
        .select('id, title, user_id')
        .eq('id', conversationId)
        .maybeSingle();

      if (error || !data) {
        throw new NotFoundError('گفتوگۆ نەدۆزرایەوە');
      }

      if (data.user_id !== userId) {
        throw new ForbiddenError('دەستگەیشتن بەم گفتوگۆیە ڕێگەپێنەدراوە');
      }

      return { id: data.id, title: data.title };
    }

    // Auto-generate title from first prompt (max 40 chars)
    let autoTitle = 'گفتوگۆی نوێ';
    if (initialPrompt && initialPrompt.trim().length > 0) {
      const clean = initialPrompt.trim().replace(/\n/g, ' ');
      autoTitle = clean.length > 40 ? `${clean.substring(0, 40)}...` : clean;
    }

    const { data: newConv, error: createError } = await supabaseAdmin
      .from('conversations')
      .insert({
        user_id: userId,
        title: autoTitle,
      })
      .select('id, title')
      .single();

    if (createError || !newConv) {
      logger.error('Failed to create conversation in database:', createError);
      throw new Error('دروستکردنی گفتوگۆی نوێ سەرکەوتوو نەبوو');
    }

    return { id: newConv.id, title: newConv.title };
  }

  /**
   * Fetches recent message history for context preservation
   */
  async getConversationHistory(
    conversationId: string,
    limit: number = 20
  ): Promise<Array<{ role: 'user' | 'assistant'; content: string }>> {
    const { data, error } = await supabaseAdmin
      .from('conversation_messages')
      .select('role, content')
      .eq('conversation_id', conversationId)
      .in('role', ['user', 'assistant'])
      .order('created_at', { ascending: true })
      .limit(limit);

    if (error || !data) {
      logger.warn(`Could not load history for conversation ${conversationId}:`, error);
      return [];
    }

    return data.map((m) => ({
      role: m.role as 'user' | 'assistant',
      content: m.content,
    }));
  }

  /**
   * Saves a message to conversation_messages and touches conversations.updated_at
   */
  async saveMessage(
    conversationId: string,
    userId: string,
    role: 'user' | 'assistant' | 'system',
    content: string,
    tokens: number = 0
  ): Promise<{ id: string; role: string; content: string; created_at: string }> {
    const { data, error } = await supabaseAdmin
      .from('conversation_messages')
      .insert({
        conversation_id: conversationId,
        user_id: userId,
        role,
        content,
        tokens,
      })
      .select('id, role, content, created_at')
      .single();

    if (error || !data) {
      logger.error(`Failed to save message to conversation ${conversationId}:`, error);
      throw new Error('پاشەکەوتکردنی پەیام سەرکەوتوو نەبوو');
    }

    // Update conversation timestamp
    await supabaseAdmin
      .from('conversations')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', conversationId);

    return data;
  }

  /**
   * Lists conversations for a user with pagination
   */
  async listConversations(
    userId: string,
    limit: number = 20,
    offset: number = 0
  ): Promise<{ conversations: ConversationSummary[]; total: number }> {
    const { data, error, count } = await supabaseAdmin
      .from('conversations')
      .select('id, title, created_at, updated_at', { count: 'exact' })
      .eq('user_id', userId)
      .order('updated_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (error) {
      logger.error('Failed to list conversations:', error);
      throw new Error('هێنانەوەی گفتوگۆکان سەرکەوتوو نەبوو');
    }

    return {
      conversations: (data || []) as ConversationSummary[],
      total: count ?? (data?.length || 0),
    };
  }

  /**
   * Fetches full conversation details and chronological message thread
   */
  async getConversationWithMessages(conversationId: string, userId: string): Promise<ConversationDetail> {
    const { data: conv, error: convError } = await supabaseAdmin
      .from('conversations')
      .select('id, title, created_at, updated_at, user_id')
      .eq('id', conversationId)
      .maybeSingle();

    if (convError || !conv) {
      throw new NotFoundError('گفتوگۆ نەدۆزرایەوە');
    }

    if (conv.user_id !== userId) {
      throw new ForbiddenError('دەستگەیشتن بەم گفتوگۆیە ڕێگەپێنەدراوە');
    }

    const { data: messages, error: msgError } = await supabaseAdmin
      .from('conversation_messages')
      .select('id, role, content, tokens, created_at')
      .eq('conversation_id', conversationId)
      .order('created_at', { ascending: true });

    if (msgError) {
      logger.error(`Failed to fetch messages for conversation ${conversationId}:`, msgError);
      throw new Error('هێنانەوەی پەیامەکان سەرکەوتوو نەبوو');
    }

    return {
      id: conv.id,
      title: conv.title,
      created_at: conv.created_at,
      updated_at: conv.updated_at,
      messages: (messages || []) as any,
    };
  }

  /**
   * Deletes a conversation and cascades to its messages
   */
  async deleteConversation(conversationId: string, userId: string): Promise<boolean> {
    const { data: conv, error: checkError } = await supabaseAdmin
      .from('conversations')
      .select('id, user_id')
      .eq('id', conversationId)
      .maybeSingle();

    if (checkError || !conv) {
      throw new NotFoundError('گفتوگۆ نەدۆزرایەوە');
    }

    if (conv.user_id !== userId) {
      throw new ForbiddenError('دەستگەیشتن بەم گفتوگۆیە ڕێگەپێنەدراوە');
    }

    const { error: deleteError } = await supabaseAdmin
      .from('conversations')
      .delete()
      .eq('id', conversationId);

    if (deleteError) {
      logger.error(`Failed to delete conversation ${conversationId}:`, deleteError);
      throw new Error('سڕینەوەی گفتوگۆ سەرکەوتوو نەبوو');
    }

    return true;
  }
}

export const conversationService = new ConversationService();
