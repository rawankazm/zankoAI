// ==============================================================================
// ZankoAI Background Worker Service — Client API Layer
// ==============================================================================

import 'package:dio/dio.dart';
import '../core/network/api_client.dart';
import '../models/background_worker_model.dart';

class WorkerBackendService {
  final Dio? _customDio;
  WorkerBackendService({Dio? dio}) : _customDio = dio;
  WorkerBackendService._() : _customDio = null;
  static final WorkerBackendService instance = WorkerBackendService._();

  Dio get _dio => _customDio ?? ApiClient().dio;

  /// Fetches worker health report from GET /api/health/worker
  Future<WorkerHealthStatusReport> getWorkerHealth() async {
    final response = await _dio.get<Map<String, dynamic>>('/health/worker');
    final body = response.data ?? {};
    final data = body['data'] as Map<String, dynamic>? ?? body;
    return WorkerHealthStatusReport.fromJson(data);
  }

  /// Verifies if a specific background queue is healthy and operational
  Future<bool> isQueueOperational(BackgroundQueueType queue) async {
    try {
      final report = await getWorkerHealth();
      if (!report.redisConnected || report.status == 'down') {
        return false;
      }
      final metrics = report.queues[queue.queueName];
      if (metrics == null) return false;
      return !metrics.paused;
    } catch (_) {
      return false;
    }
  }
}
