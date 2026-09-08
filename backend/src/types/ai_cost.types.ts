export type AiPlanTier = 'free' | 'premium';

export interface AiCostLimits {
  plan: AiPlanTier;
  max_request_chars: number;
  max_tokens: number;
  max_daily_cost_usd: number;
  max_monthly_cost_usd: number;
  max_concurrent_jobs: number;
  rate_limit_per_min: number;
  description?: string;
  updated_at?: string;
}

export type AiRequestStatus = 'success' | 'failed' | 'timeout' | 'blocked';

export interface AiRequestLogData {
  user_id: string;
  feature: string;
  provider: string;
  model: string;
  input_tokens: number;
  output_tokens: number;
  estimated_cost: number;
  duration: number;
  status: AiRequestStatus;
  created_at: string;
  completed_at?: string;
  error_message?: string | null;
}

export interface AiUsageSummaryResponse {
  total_requests: number;
  success_requests: number;
  failed_requests: number;
  timeout_requests: number;
  blocked_requests: number;
  total_tokens: number;
  total_input_tokens: number;
  total_output_tokens: number;
  avg_duration_ms: number;
  breakdown_by_feature: Record<string, { requests: number; tokens: number; cost_usd: number }>;
  breakdown_by_provider: Record<string, { requests: number; tokens: number; cost_usd: number }>;
  breakdown_by_model: Record<string, { requests: number; tokens: number; cost_usd: number }>;
  breakdown_by_tier: Record<string, { requests: number; tokens: number; cost_usd: number }>;
  top_users: Array<{
    user_id: string;
    request_count: number;
    total_tokens: number;
    total_cost: number;
  }>;
  recent_requests: Array<AiRequestLogData & { id: string }>;
  timeframe: {
    period?: string;
    startDate?: string;
    endDate?: string;
  };
}

export interface AiCostSummaryResponse {
  total_cost_usd: number;
  period_cost_usd: number;
  daily_average_cost_usd: number;
  projected_monthly_cost_usd: number;
  cost_by_provider: Record<string, number>;
  cost_by_feature: Record<string, number>;
  cost_by_tier: {
    free: number;
    premium: number;
  };
  daily_trend: Array<{
    date: string;
    cost_usd: number;
    request_count: number;
    tokens: number;
  }>;
  top_spenders: Array<{
    user_id: string;
    plan: string;
    daily_cost: number;
    monthly_cost: number;
    total_cost: number;
  }>;
  active_alerts: Array<AiSpendingAlert>;
  timeframe: {
    period?: string;
    startDate?: string;
    endDate?: string;
  };
}

export interface AiSpendingAlert {
  id: string;
  user_id?: string | null;
  alert_type: string;
  threshold_value: number;
  current_value: number;
  severity: 'info' | 'warning' | 'critical';
  message: string;
  metadata: Record<string, any>;
  acknowledged: boolean;
  acknowledged_by?: string | null;
  acknowledged_at?: string | null;
  created_at: string;
}

export interface UserAiBudgetStatus {
  userId: string;
  plan: AiPlanTier;
  dailyCost: number;
  dailyBudget: number;
  dailyRemaining: number;
  monthlyCost: number;
  monthlyBudget: number;
  monthlyRemaining: number;
  activeConcurrentJobs: number;
  maxConcurrentJobs: number;
}
