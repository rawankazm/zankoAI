import '../core/network/api_client.dart';

class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;

  _CacheEntry(this.data, Duration ttl) : expiresAt = DateTime.now().add(ttl);

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

/// Service managing universities, departments, courses, and student enrollments.
/// Incorporates client-side TTL memory caching to eliminate duplicate API calls.
class CourseService {
  final ApiClient _client;
  static const Duration _defaultTtl = Duration(minutes: 5);

  final Map<String, _CacheEntry<dynamic>> _cache = {};

  CourseService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  static final CourseService instance = CourseService();

  /// Clears in-memory catalog cache.
  void clearCache() {
    _cache.clear();
  }

  /// Lists courses with optional department, university, and search query filters.
  Future<List<Map<String, dynamic>>> listCourses({
    String? departmentId,
    String? universityId,
    String? search,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'courses:${departmentId ?? ""}:${universityId ?? ""}:${search ?? ""}';
    if (!forceRefresh && _cache[cacheKey]?.isValid == true) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data as List);
    }

    final response = await _client.get<Map<String, dynamic>>(
      '/courses',
      queryParameters: {
        'department_id': ?departmentId,
        'university_id': ?universityId,
        'search': ?search,
      },
    );
    final data = response.data?['data'];
    final items = data is Map
        ? (data['items'] as List<dynamic>? ?? [])
        : (data as List<dynamic>? ?? []);
    final result = items.whereType<Map<String, dynamic>>().toList();

    _cache[cacheKey] = _CacheEntry(result, _defaultTtl);
    return result;
  }

  /// Fetches single course details.
  Future<Map<String, dynamic>> getCourse(String courseId, {bool forceRefresh = false}) async {
    final cacheKey = 'course:$courseId';
    if (!forceRefresh && _cache[cacheKey]?.isValid == true) {
      return Map<String, dynamic>.from(_cache[cacheKey]!.data as Map);
    }

    final response = await _client.get<Map<String, dynamic>>(
      '/courses/$courseId',
    );
    final result = response.data?['data'] as Map<String, dynamic>? ?? {};
    _cache[cacheKey] = _CacheEntry(result, _defaultTtl);
    return result;
  }

  /// Enrolls the current student into a course.
  Future<bool> enrollCourse(String courseId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/courses/$courseId/enroll',
    );
    _cache.remove('course:$courseId');
    _cache.remove('members:$courseId');
    return response.statusCode == 200 || response.statusCode == 201;
  }

  /// Unenrolls the current student from a course.
  Future<bool> unenrollCourse(String courseId) async {
    final response = await _client.delete<Map<String, dynamic>>(
      '/courses/$courseId/enroll',
    );
    _cache.remove('course:$courseId');
    _cache.remove('members:$courseId');
    return response.statusCode == 200 || response.statusCode == 204;
  }

  /// Lists enrolled members of a course.
  Future<List<Map<String, dynamic>>> getCourseMembers(String courseId, {bool forceRefresh = false}) async {
    final cacheKey = 'members:$courseId';
    if (!forceRefresh && _cache[cacheKey]?.isValid == true) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data as List);
    }

    final response = await _client.get<Map<String, dynamic>>(
      '/courses/$courseId/members',
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    final result = data.whereType<Map<String, dynamic>>().toList();
    _cache[cacheKey] = _CacheEntry(result, const Duration(minutes: 2));
    return result;
  }

  /// Lists all accredited universities in the Kurdistan region.
  Future<List<Map<String, dynamic>>> listUniversities({bool forceRefresh = false}) async {
    const cacheKey = 'universities';
    if (!forceRefresh && _cache[cacheKey]?.isValid == true) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data as List);
    }

    final response = await _client.get<Map<String, dynamic>>('/universities');
    final data = response.data?['data'];
    final items = data is Map
        ? (data['items'] as List<dynamic>? ?? [])
        : (data as List<dynamic>? ?? []);
    final result = items.whereType<Map<String, dynamic>>().toList();

    _cache[cacheKey] = _CacheEntry(result, _defaultTtl);
    return result;
  }

  /// Lists departments, optionally filtered by university.
  Future<List<Map<String, dynamic>>> listDepartments({
    String? universityId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'departments:${universityId ?? ""}';
    if (!forceRefresh && _cache[cacheKey]?.isValid == true) {
      return List<Map<String, dynamic>>.from(_cache[cacheKey]!.data as List);
    }

    final response = await _client.get<Map<String, dynamic>>(
      '/departments',
      queryParameters: {
        'university_id': ?universityId,
      },
    );
    final data = response.data?['data'];
    final items = data is Map
        ? (data['items'] as List<dynamic>? ?? [])
        : (data as List<dynamic>? ?? []);
    final result = items.whereType<Map<String, dynamic>>().toList();

    _cache[cacheKey] = _CacheEntry(result, _defaultTtl);
    return result;
  }
}
