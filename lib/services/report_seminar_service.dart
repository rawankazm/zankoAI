// ==============================================================================
// ZankoAI Report & Seminar Service — DigitalOcean Backend API + Supabase
// ==============================================================================

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';
import '../models/academic_report_seminar_model.dart';

class ReportSeminarService {
  final Dio? _customDio;
  ReportSeminarService({Dio? dio}) : _customDio = dio;
  ReportSeminarService._() : _customDio = null;
  static final ReportSeminarService instance = ReportSeminarService._();

  Dio get _dio => _customDio ?? ApiClient().dio;

  static const String _localReportsCacheKey = 'local_saved_academic_reports_cache';
  static const String _localSeminarsCacheKey = 'local_saved_academic_seminars_cache';

  // ─── Reports API ──────────────────────────────────────────────────────────

  /// Create a new report via DigitalOcean backend API (which stores in Supabase)
  Future<AcademicReportRecord> createReport({
    required String title,
    String? subject,
    required String language,
    String? topic,
    String? description,
    String? content,
    String status = 'completed',
    List<AcademicSectionModel>? sections,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      if (subject != null) 'subject': subject.trim(),
      'language': language,
      if (topic != null) 'topic': topic.trim(),
      if (description != null) 'description': description.trim(),
      'content': ?content,
      'status': status,
      if (sections != null && sections.isNotEmpty)
        'sections': sections.map((s) => s.toJson()).toList(),
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/reports',
        data: payload,
      );

      final data = response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
      final record = AcademicReportRecord.fromJson(data);
      await _cacheReportLocally(record);
      return record;
    } catch (e) {
      debugPrint('[ReportSeminarService] API createReport failed, checking offline fallback: $e');
      // Create local fallback record
      final fallback = AcademicReportRecord(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'offline_user',
        title: title,
        subject: subject,
        language: language,
        topic: topic,
        description: description,
        content: content,
        status: status,
        sections: sections ?? const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _cacheReportLocally(fallback);
      return fallback;
    }
  }

  /// Get list of reports for the authenticated user
  Future<List<AcademicReportRecord>> getReports({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      };

      final response = await _dio.get<Map<String, dynamic>>(
        '/reports',
        queryParameters: queryParams,
      );

      final data = response.data?['data'];
      final List<dynamic> items;
      if (data is Map<String, dynamic> && data['reports'] is List) {
        items = data['reports'] as List<dynamic>;
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }

      final records = items
          .whereType<Map<String, dynamic>>()
          .map((e) => AcademicReportRecord.fromJson(e))
          .toList();

      if (records.isNotEmpty) {
        await _updateAllReportsCache(records);
      }
      return records;
    } catch (e) {
      debugPrint('[ReportSeminarService] API getReports failed, reading from local cache: $e');
      return _getLocalCachedReports();
    }
  }

  /// Get single report by ID
  Future<AcademicReportRecord?> getReportById(String reportId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/reports/$reportId',
      );
      final data = response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
      return AcademicReportRecord.fromJson(data);
    } catch (e) {
      debugPrint('[ReportSeminarService] getReportById error: $e');
      final local = await _getLocalCachedReports();
      try {
        return local.firstWhere((r) => r.id == reportId);
      } catch (_) {
        return null;
      }
    }
  }

  /// Update existing report
  Future<AcademicReportRecord?> updateReport(
    String reportId, {
    String? title,
    String? topic,
    String? description,
    String? content,
    String? status,
    List<AcademicSectionModel>? sections,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (topic != null) 'topic': topic.trim(),
      if (description != null) 'description': description.trim(),
      'content': ?content,
      'status': ?status,
      if (sections != null)
        'sections': sections.map((s) => s.toJson()).toList(),
    };

    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/reports/$reportId',
        data: payload,
      );
      final data = response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
      final record = AcademicReportRecord.fromJson(data);
      await _cacheReportLocally(record);
      return record;
    } catch (e) {
      debugPrint('[ReportSeminarService] updateReport error: $e');
      return null;
    }
  }

  /// Delete report by ID
  Future<bool> deleteReport(String reportId) async {
    try {
      await _dio.delete('/reports/$reportId');
      await _removeReportFromCache(reportId);
      return true;
    } catch (e) {
      debugPrint('[ReportSeminarService] deleteReport error: $e');
      await _removeReportFromCache(reportId);
      return false;
    }
  }

  // ─── Seminars API ─────────────────────────────────────────────────────────

  /// Create a new seminar presentation via DigitalOcean backend API
  Future<AcademicSeminarRecord> createSeminar({
    required String title,
    String? subject,
    required String language,
    String? topic,
    String? description,
    String? content,
    String status = 'completed',
    List<AcademicSectionModel>? sections,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      if (subject != null) 'subject': subject.trim(),
      'language': language,
      if (topic != null) 'topic': topic.trim(),
      if (description != null) 'description': description.trim(),
      'content': ?content,
      'status': status,
      if (sections != null && sections.isNotEmpty)
        'sections': sections.map((s) => s.toJson()).toList(),
    };

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/seminars',
        data: payload,
      );

      final data = response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
      final record = AcademicSeminarRecord.fromJson(data);
      await _cacheSeminarLocally(record);
      return record;
    } catch (e) {
      debugPrint('[ReportSeminarService] API createSeminar failed, checking offline fallback: $e');
      final fallback = AcademicSeminarRecord(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        userId: 'offline_user',
        title: title,
        subject: subject,
        language: language,
        topic: topic,
        description: description,
        content: content,
        status: status,
        sections: sections ?? const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _cacheSeminarLocally(fallback);
      return fallback;
    }
  }

  /// Get list of seminars for the authenticated user
  Future<List<AcademicSeminarRecord>> getSeminars({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      };

      final response = await _dio.get<Map<String, dynamic>>(
        '/seminars',
        queryParameters: queryParams,
      );

      final data = response.data?['data'];
      final List<dynamic> items;
      if (data is Map<String, dynamic> && data['seminars'] is List) {
        items = data['seminars'] as List<dynamic>;
      } else if (data is List) {
        items = data;
      } else {
        items = [];
      }

      final records = items
          .whereType<Map<String, dynamic>>()
          .map((e) => AcademicSeminarRecord.fromJson(e))
          .toList();

      if (records.isNotEmpty) {
        await _updateAllSeminarsCache(records);
      }
      return records;
    } catch (e) {
      debugPrint('[ReportSeminarService] API getSeminars failed, reading from local cache: $e');
      return _getLocalCachedSeminars();
    }
  }

  /// Get single seminar by ID
  Future<AcademicSeminarRecord?> getSeminarById(String seminarId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/seminars/$seminarId',
      );
      final data = response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
      return AcademicSeminarRecord.fromJson(data);
    } catch (e) {
      debugPrint('[ReportSeminarService] getSeminarById error: $e');
      final local = await _getLocalCachedSeminars();
      try {
        return local.firstWhere((s) => s.id == seminarId);
      } catch (_) {
        return null;
      }
    }
  }

  /// Update existing seminar
  Future<AcademicSeminarRecord?> updateSeminar(
    String seminarId, {
    String? title,
    String? topic,
    String? description,
    String? content,
    String? status,
    List<AcademicSectionModel>? sections,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (topic != null) 'topic': topic.trim(),
      if (description != null) 'description': description.trim(),
      'content': ?content,
      'status': ?status,
      if (sections != null)
        'sections': sections.map((s) => s.toJson()).toList(),
    };

    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/seminars/$seminarId',
        data: payload,
      );
      final data = response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
      final record = AcademicSeminarRecord.fromJson(data);
      await _cacheSeminarLocally(record);
      return record;
    } catch (e) {
      debugPrint('[ReportSeminarService] updateSeminar error: $e');
      return null;
    }
  }

  /// Delete seminar by ID
  Future<bool> deleteSeminar(String seminarId) async {
    try {
      await _dio.delete('/seminars/$seminarId');
      await _removeSeminarFromCache(seminarId);
      return true;
    } catch (e) {
      debugPrint('[ReportSeminarService] deleteSeminar error: $e');
      await _removeSeminarFromCache(seminarId);
      return false;
    }
  }

  // ─── Local Caching / Offline Sync Helpers ──────────────────────────────────

  Future<List<AcademicReportRecord>> _getLocalCachedReports() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localReportsCacheKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => AcademicReportRecord.fromJson(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _cacheReportLocally(AcademicReportRecord report) async {
    try {
      final current = await _getLocalCachedReports();
      final idx = current.indexWhere((r) => r.id == report.id);
      if (idx >= 0) {
        current[idx] = report;
      } else {
        current.insert(0, report);
      }
      final trimmed = current.take(50).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localReportsCacheKey,
        jsonEncode(trimmed.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _updateAllReportsCache(List<AcademicReportRecord> reports) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localReportsCacheKey,
        jsonEncode(reports.take(50).map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _removeReportFromCache(String id) async {
    try {
      final current = await _getLocalCachedReports();
      current.removeWhere((r) => r.id == id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localReportsCacheKey,
        jsonEncode(current.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<List<AcademicSeminarRecord>> _getLocalCachedSeminars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localSeminarsCacheKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => AcademicSeminarRecord.fromJson(e))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _cacheSeminarLocally(AcademicSeminarRecord seminar) async {
    try {
      final current = await _getLocalCachedSeminars();
      final idx = current.indexWhere((s) => s.id == seminar.id);
      if (idx >= 0) {
        current[idx] = seminar;
      } else {
        current.insert(0, seminar);
      }
      final trimmed = current.take(50).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localSeminarsCacheKey,
        jsonEncode(trimmed.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _updateAllSeminarsCache(List<AcademicSeminarRecord> seminars) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localSeminarsCacheKey,
        jsonEncode(seminars.take(50).map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> _removeSeminarFromCache(String id) async {
    try {
      final current = await _getLocalCachedSeminars();
      current.removeWhere((s) => s.id == id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localSeminarsCacheKey,
        jsonEncode(current.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }
}
