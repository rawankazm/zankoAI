-- ==============================================================================
-- ZankoAI Migration: Production-Ready AI Chat, Conversations, and AI Request Audit
-- Migration Version: 20260907000008_ai_chat_and_conversations.sql
-- ==============================================================================

-- 1. Conversations Table
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL DEFAULT 'گفتوگۆی نوێ',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.conversations IS 'Tracks persistent AI chat sessions and conversation threads for university students.';

-- Indexes for lightning fast conversation listing and sorting
CREATE INDEX IF NOT EXISTS idx_conversations_user_updated 
    ON public.conversations (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_created_at 
    ON public.conversations (created_at DESC);

-- 2. Conversation Messages Table
CREATE TABLE IF NOT EXISTS public.conversation_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    tokens INTEGER NOT NULL DEFAULT 0,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.conversation_messages IS 'Contains individual prompt and reply history within a given conversation.';

-- Indexes for rapid message history reconstruction
CREATE INDEX IF NOT EXISTS idx_conv_messages_conv_created 
    ON public.conversation_messages (conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_conv_messages_user_id 
    ON public.conversation_messages (user_id);

-- 3. Detailed AI Requests & Cost Auditing Table
CREATE TABLE IF NOT EXISTS public.ai_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    feature VARCHAR(50) NOT NULL DEFAULT 'ai_chat',
    provider VARCHAR(50) NOT NULL, -- 'google', 'openai', 'anthropic'
    model VARCHAR(100) NOT NULL,   -- e.g. 'gemini-2.5-flash', 'gpt-4o-mini', 'claude-3-5-haiku-20241022'
    status VARCHAR(50) NOT NULL CHECK (status IN ('success', 'failed', 'timeout')),
    tokens INTEGER NOT NULL DEFAULT 0,
    prompt_tokens INTEGER NOT NULL DEFAULT 0,
    completion_tokens INTEGER NOT NULL DEFAULT 0,
    estimated_cost NUMERIC(10, 6) NOT NULL DEFAULT 0.000000, -- in USD ($)
    duration INTEGER NOT NULL, -- elapsed latency in milliseconds
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    completed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

COMMENT ON TABLE public.ai_requests IS 'Comprehensive log of all AI inferences with provider, model, latency, tokens, and USD cost.';

-- Indexes for AI requests auditing and cost monitoring
CREATE INDEX IF NOT EXISTS idx_ai_requests_user_created 
    ON public.ai_requests (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_requests_feature_date 
    ON public.ai_requests (feature, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_requests_provider_model 
    ON public.ai_requests (provider, model);
CREATE INDEX IF NOT EXISTS idx_ai_requests_status 
    ON public.ai_requests (status);

-- 4. Row Level Security (RLS) Policies
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_requests ENABLE ROW LEVEL SECURITY;

-- Conversations RLS: Users can only see and manage their own conversations
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can manage their own conversations" ON public.conversations;
    CREATE POLICY "Users can manage their own conversations"
        ON public.conversations
        FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);
END $$;

-- Conversation Messages RLS: Users can only see and insert their own messages
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can manage their own conversation messages" ON public.conversation_messages;
    CREATE POLICY "Users can manage their own conversation messages"
        ON public.conversation_messages
        FOR ALL
        TO authenticated
        USING (auth.uid() = user_id)
        WITH CHECK (auth.uid() = user_id);
END $$;

-- AI Requests RLS: Users can view their own AI requests; Service Role has full access
DO $$ 
BEGIN
    DROP POLICY IF EXISTS "Users can view their own ai requests" ON public.ai_requests;
    CREATE POLICY "Users can view their own ai requests"
        ON public.ai_requests
        FOR SELECT
        TO authenticated
        USING (auth.uid() = user_id);
END $$;
