export type QueueName = 'pdf' | 'ocr' | 'audio' | 'ai' | 'notifications' | 'subscription-maintenance';

export type JobState = 'queued' | 'processing' | 'completed' | 'failed';

export interface JobMetadata {
  job_id: string;
  queue_name: QueueName;
  job_name: string;
  state: JobState;
  created_at: string;
  started_at?: string;
  completed_at?: string;
  failed_at?: string;
  attempts: number;
  max_attempts: number;
  idempotency_key?: string;
  error_message?: string;
  error_stack?: string;
  execution_duration_ms?: number;
  data?: any;
  result?: any;
}

export interface DeadLetterJob {
  job_id: string;
  queue_name: QueueName;
  job_name: string;
  attempts: number;
  max_attempts: number;
  failed_at: string;
  error_message: string;
  data: any;
  idempotency_key?: string;
}

export interface QueueHealthMetrics {
  waiting: number;
  active: number;
  completed: number;
  failed: number;
  delayed: number;
  paused: boolean;
}

export interface WorkerHealthReport {
  status: 'healthy' | 'degraded' | 'down';
  redis_connected: boolean;
  uptime_seconds: number;
  active_workers: number;
  queues: Record<QueueName, QueueHealthMetrics>;
  dead_letter_count: number;
  timestamp: string;
}

export interface UnifiedJobOptions {
  idempotencyKey?: string;
  timeoutMs?: number;
  attempts?: number;
  backoffDelayMs?: number;
  priority?: number;
  delay?: number;
}
