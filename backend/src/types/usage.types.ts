// ==============================================================================
// ZankoAI Usage & Subscription Types
// ==============================================================================

export type PlanType = 'free' | 'premium';

export type FeatureName =
  | 'ai_chat'
  | 'pdf'
  | 'ocr'
  | 'audio'
  | 'homework'
  | 'quiz'
  | 'flashcards'
  | 'storage'
  | string;

export type PeriodType = 'daily' | 'monthly';

export interface PlanLimit {
  id: string;
  plan: PlanType;
  feature: FeatureName;
  period_type: PeriodType;
  limit_value: number;
  fair_use_limit?: number | null;
  is_active: boolean;
  description?: string | null;
  created_at: string;
  updated_at: string;
}

export interface UsageRecord {
  id: string;
  user_id: string;
  feature: FeatureName;
  period_type: PeriodType;
  period_start: string;
  period_end: string;
  usage_count: number;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
}

export interface QuotaCheckResult {
  allowed: boolean;
  code?: string;
  plan: PlanType;
  feature: string;
  current_usage: number;
  limit: number;
  remaining: number;
  reset_at: string;
  period_type: PeriodType;
  is_idempotent_replay?: boolean;
}

export interface FeatureUsageStatus {
  feature: string;
  period_type: PeriodType;
  current_usage: number;
  limit: number;
  remaining: number;
  reset_at: string;
  description?: string;
}

export interface UserUsageSummaryResponse {
  plan: PlanType;
  is_vip: boolean;
  features: Record<string, FeatureUsageStatus>;
  queried_at: string;
}

export interface UpdatePlanLimitDto {
  limit_value?: number;
  fair_use_limit?: number;
  is_active?: boolean;
  description?: string;
}

export interface CreatePlanLimitDto {
  plan: PlanType;
  feature: FeatureName;
  period_type: PeriodType;
  limit_value: number;
  fair_use_limit?: number;
  is_active?: boolean;
  description?: string;
}
