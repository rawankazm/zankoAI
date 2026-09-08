import '../core/network/api_client.dart';

/// Lecture retrieval and authorized presigned storage upload service.
class LectureService {
  final ApiClient _client;

  LectureService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  static final LectureService instance = LectureService();

  /// Lists all lectures belonging to an enrolled course.
  Future<List<Map<String, dynamic>>> listLectures(String courseId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/courses/$courseId/lectures',
    );
    final data = response.data?['data'];
    final items = data is Map
        ? (data['items'] as List<dynamic>? ?? [])
        : (data as List<dynamic>? ?? []);
    return items.whereType<Map<String, dynamic>>().toList();
  }

  /// Fetches a single lecture by ID.
  Future<Map<String, dynamic>> getLecture(String lectureId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/lectures/$lectureId',
    );
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Requests a secure, authorized pre-signed upload ticket for lecture materials.
  /// (e.g. PDF slides, audio recordings, documents)
  Future<Map<String, dynamic>> requestUploadTicket({
    required String category,
    required String filename,
    required String contentType,
    required int sizeBytes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/storage/upload-ticket',
      data: {
        'category': category,
        'filename': filename,
        'content_type': contentType,
        'size_bytes': sizeBytes,
      },
    );
    return response.data?['data'] as Map<String, dynamic>? ?? {};
  }

  /// Obtains a temporary signed download URL for private course materials.
  Future<String?> getSignedUrl({
    required String bucket,
    required String filePath,
    int expiresInSeconds = 3600,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      '/storage/signed-url',
      data: {
        'bucket': bucket,
        'file_path': filePath,
        'expires_in': expiresInSeconds,
      },
    );
    return response.data?['data']?['signed_url'] as String?;
  }
}
