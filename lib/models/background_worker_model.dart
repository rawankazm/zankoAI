// ==============================================================================
// ZankoAI Background Worker & Redis Job Models
// ==============================================================================

/// The 5 official background processing queues in ZankoAI
enum BackgroundQueueType { pdf, ocr, audio, ai, notifications }

extension BackgroundQueueTypeExt on BackgroundQueueType {
  String get queueName {
    switch (this) {
      case BackgroundQueueType.pdf:
        return 'pdf';
      case BackgroundQueueType.ocr:
        return 'ocr';
      case BackgroundQueueType.audio:
        return 'audio';
      case BackgroundQueueType.ai:
        return 'ai';
      case BackgroundQueueType.notifications:
        return 'notifications';
    }
  }

  static BackgroundQueueType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pdf':
      case 'pdf-processing':
      case 'pdf-ai-processing':
        return BackgroundQueueType.pdf;
      case 'ocr':
      case 'ocr-processing':
        return BackgroundQueueType.ocr;
      case 'audio':
      case 'audio-transcription':
        return BackgroundQueueType.audio;
      case 'ai':
        return BackgroundQueueType.ai;
      case 'notifications':
        return BackgroundQueueType.notifications;
      default:
        return BackgroundQueueType.ai;
    }
  }
}

/// The 4 official job lifecycle states
enum BackgroundJobState { queued, processing, completed, failed }

extension BackgroundJobStateExt on BackgroundJobState {
  String get value {
    switch (this) {
      case BackgroundJobState.queued:
        return 'queued';
      case BackgroundJobState.processing:
        return 'processing';
      case BackgroundJobState.completed:
        return 'completed';
      case BackgroundJobState.failed:
        return 'failed';
    }
  }

  static BackgroundJobState fromString(String value) {
    switch (value.toLowerCase()) {
      case 'queued':
      case 'waiting':
        return BackgroundJobState.queued;
      case 'processing':
      case 'active':
        return BackgroundJobState.processing;
      case 'completed':
        return BackgroundJobState.completed;
      case 'failed':
        return BackgroundJobState.failed;
      default:
        return BackgroundJobState.queued;
    }
  }
}

/// Detailed metadata tracking the full lifecycle of a background job
class BackgroundJobMetadata {
  final String jobId;
  final BackgroundQueueType queueName;
  final String jobName;
  final BackgroundJobState state;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? failedAt;
  final int attempts;
  final int maxAttempts;
  final String? idempotencyKey;
  final String? errorMessage;
  final int? executionDurationMs;
  final Map<String, dynamic>? data;
  final dynamic result;

  const BackgroundJobMetadata({
    required this.jobId,
    required this.queueName,
    required this.jobName,
    required this.state,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.failedAt,
    this.attempts = 0,
    this.maxAttempts = 3,
    this.idempotencyKey,
    this.errorMessage,
    this.executionDurationMs,
    this.data,
    this.result,
  });

  bool get isTerminal =>
      state == BackgroundJobState.completed ||
      state == BackgroundJobState.failed;

  bool get canRetry =>
      state == BackgroundJobState.failed && attempts < maxAttempts;

  Duration? get duration {
    if (startedAt == null) return null;
    final end = completedAt ?? failedAt ?? DateTime.now();
    return end.difference(startedAt!);
  }

  factory BackgroundJobMetadata.fromJson(Map<String, dynamic> json) {
    return BackgroundJobMetadata(
      jobId: (json['job_id'] ?? json['jobId'] ?? '').toString(),
      queueName: BackgroundQueueTypeExt.fromString(
        (json['queue_name'] ?? json['queueName'] ?? 'ai').toString(),
      ),
      jobName: (json['job_name'] ?? json['jobName'] ?? 'unnamed').toString(),
      state: BackgroundJobStateExt.fromString(
        (json['state'] ?? 'queued').toString(),
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString())
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      failedAt: json['failed_at'] != null
          ? DateTime.tryParse(json['failed_at'].toString())
          : null,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 3,
      idempotencyKey: json['idempotency_key']?.toString(),
      errorMessage: json['error_message']?.toString(),
      executionDurationMs: (json['execution_duration_ms'] as num?)?.toInt(),
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null,
      result: json['result'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_id': jobId,
      'queue_name': queueName.queueName,
      'job_name': jobName,
      'state': state.value,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'failed_at': failedAt?.toIso8601String(),
      'attempts': attempts,
      'max_attempts': maxAttempts,
      'idempotency_key': idempotencyKey,
      'error_message': errorMessage,
      'execution_duration_ms': executionDurationMs,
      'data': data,
      'result': result,
    };
  }
}

/// Metrics for an individual BullMQ queue
class QueueMetrics {
  final int waiting;
  final int active;
  final int completed;
  final int failed;
  final int delayed;
  final bool paused;

  const QueueMetrics({
    this.waiting = 0,
    this.active = 0,
    this.completed = 0,
    this.failed = 0,
    this.delayed = 0,
    this.paused = false,
  });

  int get totalInFlight => waiting + active + delayed;

  factory QueueMetrics.fromJson(Map<String, dynamic> json) {
    return QueueMetrics(
      waiting: (json['waiting'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      delayed: (json['delayed'] as num?)?.toInt() ?? 0,
      paused: json['paused'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waiting': waiting,
      'active': active,
      'completed': completed,
      'failed': failed,
      'delayed': delayed,
      'paused': paused,
    };
  }
}

/// Complete worker health report from GET /api/health/worker
class WorkerHealthStatusReport {
  final String status;
  final bool redisConnected;
  final int uptimeSeconds;
  final int activeWorkers;
  final Map<String, QueueMetrics> queues;
  final int deadLetterCount;
  final DateTime timestamp;

  const WorkerHealthStatusReport({
    required this.status,
    required this.redisConnected,
    required this.uptimeSeconds,
    required this.activeWorkers,
    required this.queues,
    required this.deadLetterCount,
    required this.timestamp,
  });

  bool get isHealthy => status == 'healthy' && redisConnected;

  factory WorkerHealthStatusReport.fromJson(Map<String, dynamic> json) {
    final rawQueues = json['queues'] as Map<String, dynamic>? ?? {};
    final parsedQueues = <String, QueueMetrics>{};

    rawQueues.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        parsedQueues[key] = QueueMetrics.fromJson(value);
      }
    });

    return WorkerHealthStatusReport(
      status: (json['status'] ?? 'unknown').toString(),
      redisConnected: json['redis_connected'] == true,
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt() ?? 0,
      activeWorkers: (json['active_workers'] as num?)?.toInt() ?? 0,
      queues: parsedQueues,
      deadLetterCount: (json['dead_letter_count'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'redis_connected': redisConnected,
      'uptime_seconds': uptimeSeconds,
      'active_workers': activeWorkers,
      'queues': queues.map((key, value) => MapEntry(key, value.toJson())),
      'dead_letter_count': deadLetterCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Helper for calculating exponential backoff delays across retries
class ExponentialBackoffCalculator {
  const ExponentialBackoffCalculator._();

  /// Calculates backoff delay in milliseconds for a given attempt.
  /// Formula: baseDelayMs * (2 ^ (attempt - 1))
  /// Capped at maxDelayMs (default 60 seconds).
  static int calculateDelayMs({
    required int attempt,
    int baseDelayMs = 2000,
    int maxDelayMs = 60000,
  }) {
    if (attempt <= 1) return baseDelayMs;
    // 2 ^ (attempt - 1)
    final factor = 1 << (attempt - 1);
    final calculated = baseDelayMs * factor;
    return calculated > maxDelayMs ? maxDelayMs : calculated;
  }
}
