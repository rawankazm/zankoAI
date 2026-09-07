// ==============================================================================
// ZankoAI AI Homework Solver Types
// ==============================================================================

export type HomeworkDifficulty = 'easy' | 'medium' | 'hard' | 'advanced';

export interface HomeworkStep {
  stepNumber: number;
  title: string;
  content: string;
}

export interface HomeworkSolutionData {
  id: string;
  subject: string;
  course?: string | null;
  difficulty: HomeworkDifficulty;
  answer: string;
  explanation: string;
  stepByStepReasoning: HomeworkStep[];
  mistakesIdentified: string[];
  hints: string[];
  relatedConcepts: string[];
  language: string;
  hasImage: boolean;
  createdAt: string;
}

export interface HomeworkRequestPayload {
  text?: string;
  imageBase64?: string;
  imageMimeType?: string;
  subject: string;
  course?: string;
  difficulty?: HomeworkDifficulty;
  language?: string;
}

export interface HomeworkRecord {
  id: string;
  user_id: string;
  subject: string;
  course?: string | null;
  difficulty: HomeworkDifficulty;
  has_image: boolean;
  image_mime_type?: string | null;
  text_prompt_length: number;
  language: string;
  answer: string;
  explanation: string;
  step_by_step: HomeworkStep[];
  mistakes_identified: string[];
  hints: string[];
  related_concepts: string[];
  duration_ms: number;
  tokens_used: number;
  idempotency_key?: string | null;
  created_at: string;
  updated_at: string;
}

export interface HomeworkProviderResult {
  answer: string;
  explanation: string;
  stepByStepReasoning: HomeworkStep[];
  mistakesIdentified: string[];
  hints: string[];
  relatedConcepts: string[];
  tokensUsed?: number;
}
