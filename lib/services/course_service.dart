import '../core/network/api_client.dart';

/// Service managing universities, departments, courses, and student enrollments.
class CourseService {
  final ApiClient _client;

  CourseService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  static final CourseService instance = CourseService();

  /// Lists courses with optional department, university, and search query filters.
  Future<List<Map<String, dynamic>>> listCourses({
    String? departmentId,
    String? universityId,
    String? search,
  }) async {
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
    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// Fetches single course details.
  Future<Map<String, dynamic>> getCourse(String courseId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/courses/$courseId',
    );
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Enrolls the current student into a course.
  Future<bool> enrollCourse(String courseId) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/courses/$courseId/enroll',
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  /// Unenrolls the current student from a course.
  Future<bool> unenrollCourse(String courseId) async {
    final response = await _client.delete<Map<String, dynamic>>(
      '/courses/$courseId/enroll',
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  /// Lists enrolled members of a course.
  Future<List<Map<String, dynamic>>> getCourseMembers(String courseId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/courses/$courseId/members',
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  /// Lists all accredited universities in the Kurdistan region.
  Future<List<Map<String, dynamic>>> listUniversities() async {
    final response = await _client.get<Map<String, dynamic>>('/universities');
    final data = response.data?['data'];
    final items = data is Map
        ? (data['items'] as List<dynamic>? ?? [])
        : (data as List<dynamic>? ?? []);
    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// Lists departments, optionally filtered by university.
  Future<List<Map<String, dynamic>>> listDepartments({
    String? universityId,
  }) async {
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
    return items.whereType<Map<String, dynamic>>().toList();
  }
}
