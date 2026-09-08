import '../core/network/api_client.dart';
import '../models/user_model.dart';

/// User profile and usage quota service connecting to the DigitalOcean backend.
class UserService {
  final ApiClient _client;

  UserService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  static final UserService instance = UserService();

  /// Fetches the authenticated user's profile from the backend.
  Future<UserModel> getProfile() async {
    final response = await _client.get<Map<String, dynamic>>('/auth/profile');
    final data =
        response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
    return UserModel.fromJson(data);
  }

  /// Updates the authenticated user's profile information.
  Future<UserModel> updateProfile({
    String? fullName,
    String? universityName,
    String? departmentName,
    String? cityName,
    String? bio,
    String? avatarUrl,
  }) async {
    final payload = <String, dynamic>{
      'full_name': ?fullName,
      'university_name': ?universityName,
      'department_name': ?departmentName,
      'city_name': ?cityName,
      'bio': ?bio,
      'avatar_url': ?avatarUrl,
    };

    final response = await _client.put<Map<String, dynamic>>(
      '/auth/profile',
      data: payload,
    );
    final data =
        response.data?['data'] as Map<String, dynamic>? ?? response.data ?? {};
    return UserModel.fromJson(data);
  }

  /// Fetches the current user's AI quota and daily usage stats.
  Future<Map<String, dynamic>> getUsageQuota() async {
    final response = await _client.get<Map<String, dynamic>>('/usage/status');
    return response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        {};
  }
}
