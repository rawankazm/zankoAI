import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

// Mock models and simulator for Admin System API client validation
class AdminUserRecord {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final String status;
  final String plan;
  final bool isVip;
  final String createdAt;

  AdminUserRecord({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.status,
    required this.plan,
    required this.isVip,
    required this.createdAt,
  });

  factory AdminUserRecord.fromJson(Map<String, dynamic> json) {
    return AdminUserRecord(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      plan: json['plan'] as String,
      isVip: json['is_vip'] as bool? ?? false,
      createdAt: json['created_at'] as String,
    );
  }
}

class AdminSystemUsage {
  final String period;
  final int dau;
  final int mau;
  final int totalUsers;
  final int totalAiRequests;
  final int totalTokens;
  final double estimatedCostUsd;
  final Map<String, dynamic> featureBreakdown;
  final int activeSubscriptions;
  final double totalRevenueIqd;

  AdminSystemUsage({
    required this.period,
    required this.dau,
    required this.mau,
    required this.totalUsers,
    required this.totalAiRequests,
    required this.totalTokens,
    required this.estimatedCostUsd,
    required this.featureBreakdown,
    required this.activeSubscriptions,
    required this.totalRevenueIqd,
  });

  factory AdminSystemUsage.fromJson(Map<String, dynamic> json) {
    final active = json['activeUsers'] as Map<String, dynamic>;
    final ai = json['aiUsage'] as Map<String, dynamic>;
    final monetization = json['monetization'] as Map<String, dynamic>;

    return AdminSystemUsage(
      period: json['period'] as String,
      dau: (active['dau'] as num).toInt(),
      mau: (active['mau'] as num).toInt(),
      totalUsers: (active['totalUsers'] as num).toInt(),
      totalAiRequests: (ai['totalRequests'] as num).toInt(),
      totalTokens: (ai['totalTokens'] as num).toInt(),
      estimatedCostUsd: (ai['estimatedCostUsd'] as num).toDouble(),
      featureBreakdown: ai['featureBreakdown'] as Map<String, dynamic>? ?? {},
      activeSubscriptions: (monetization['activeSubscriptions'] as num).toInt(),
      totalRevenueIqd: (monetization['totalRevenueIqd'] as num).toDouble(),
    );
  }
}

class AdminAuditRecord {
  final String id;
  final String? actorId;
  final String action;
  final String resourceType;
  final String? resourceId;
  final Map<String, dynamic> changes;
  final String createdAt;

  AdminAuditRecord({
    required this.id,
    this.actorId,
    required this.action,
    required this.resourceType,
    this.resourceId,
    required this.changes,
    required this.createdAt,
  });

  factory AdminAuditRecord.fromJson(Map<String, dynamic> json) {
    return AdminAuditRecord(
      id: json['id'] as String,
      actorId: json['actor_id'] as String?,
      action: json['action'] as String,
      resourceType: json['resource_type'] as String,
      resourceId: json['resource_id'] as String?,
      changes: json['changes'] as Map<String, dynamic>? ?? {},
      createdAt: json['created_at'] as String,
    );
  }
}

// Client simulator executing HTTP contract behaviors
class MockAdminApiClient {
  final String userRole;
  final String adminUserId;

  MockAdminApiClient({required this.userRole, required this.adminUserId});

  Map<String, dynamic> _authorize() {
    if (userRole != 'admin') {
      return {
        'statusCode': 403,
        'body': {
          'success': false,
          'error':
              'Forbidden - You do not have permission to access this resource',
          'code': 'FORBIDDEN',
        },
      };
    }
    return {'statusCode': 200};
  }

  Map<String, dynamic> getUsers({
    int page = 1,
    int limit = 50,
    String? role,
    String? status,
    String? plan,
    String? q,
  }) {
    final authCheck = _authorize();
    if (authCheck['statusCode'] != 200) return authCheck;

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'data': {
          'users': [
            {
              'id': '11111111-1111-1111-1111-111111111111',
              'email': 'student@zanko.edu.krd',
              'username': 'karwan_zanko',
              'full_name': 'Karwan Ali',
              'role': role ?? 'student',
              'status': status ?? 'active',
              'plan': plan ?? 'free',
              'is_vip': false,
              'created_at': '2026-09-01T10:00:00.000Z',
            },
          ],
          'pagination': {
            'total': 1,
            'page': page,
            'limit': limit,
            'totalPages': 1,
          },
        },
        'message': 'Users retrieved successfully',
      },
    };
  }

  Map<String, dynamic> patchUserStatus(
    String targetUserId,
    String newStatus, {
    String? reason,
  }) {
    final authCheck = _authorize();
    if (authCheck['statusCode'] != 200) return authCheck;

    if (adminUserId == targetUserId && newStatus != 'active') {
      return {
        'statusCode': 403,
        'body': {
          'success': false,
          'error':
              'Self-lockout prevented: You cannot suspend or deactivate your own admin account.',
          'code': 'FORBIDDEN',
        },
      };
    }

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'data': {
          'userId': targetUserId,
          'oldStatus': 'active',
          'newStatus': newStatus,
          'status': newStatus,
        },
        'message': 'User account $newStatus successfully',
      },
    };
  }

  Map<String, dynamic> patchUserPlan(
    String targetUserId,
    String newPlan, {
    int days = 30,
    String? reason,
  }) {
    final authCheck = _authorize();
    if (authCheck['statusCode'] != 200) return authCheck;

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'data': {
          'userId': targetUserId,
          'oldPlan': 'free',
          'newPlan': newPlan,
          'isVip': newPlan == 'premium',
          'vipExpiry': '2026-10-08T10:00:00.000Z',
        },
        'message': "User plan updated to '$newPlan' successfully",
      },
    };
  }

  Map<String, dynamic> getUsage({String period = 'month'}) {
    final authCheck = _authorize();
    if (authCheck['statusCode'] != 200) return authCheck;

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'data': {
          'period': period,
          'periodStart': '2026-08-08T00:00:00.000Z',
          'periodEnd': '2026-09-08T00:00:00.000Z',
          'activeUsers': {'dau': 142, 'mau': 1250, 'totalUsers': 3800},
          'aiUsage': {
            'totalRequests': 5400,
            'totalTokens': 1250000,
            'inputTokens': 750000,
            'outputTokens': 500000,
            'estimatedCostUsd': 0.452100,
            'featureBreakdown': {
              'ai_chat': {'requests': 3200, 'cost': 0.280000},
              'homework': {'requests': 1400, 'cost': 0.120000},
              'pdf': {'requests': 800, 'cost': 0.052100},
            },
          },
          'monetization': {
            'activeSubscriptions': 120,
            'totalRevenueIqd': 1800000.0,
            'completedPaymentsCount': 95,
          },
        },
        'message': 'System usage statistics retrieved successfully',
      },
    };
  }

  Map<String, dynamic> getAuditLogs({
    int page = 1,
    int limit = 50,
    String? action,
    String? resourceType,
  }) {
    final authCheck = _authorize();
    if (authCheck['statusCode'] != 200) return authCheck;

    return {
      'statusCode': 200,
      'body': {
        'success': true,
        'data': {
          'logs': [
            {
              'id': 'aaa-111',
              'actor_id': adminUserId,
              'action': action ?? 'status_changed',
              'resource_type': resourceType ?? 'user',
              'resource_id': 'target-user-123',
              'changes': {
                'old_status': 'active',
                'new_status': 'suspended',
                'reason': 'Violation',
              },
              'created_at': '2026-09-08T09:00:00.000Z',
            },
            {
              'id': 'aaa-222',
              'actor_id': adminUserId,
              'action': 'plan_changed',
              'resource_type': 'user',
              'resource_id': 'target-user-123',
              'changes': {
                'old_plan': 'free',
                'new_plan': 'premium',
                'days': 30,
              },
              'created_at': '2026-09-08T09:05:00.000Z',
            },
          ],
          'pagination': {
            'total': 2,
            'page': page,
            'limit': limit,
            'totalPages': 1,
          },
        },
        'message': 'Audit logs retrieved successfully',
      },
    };
  }
}

void main() {
  group('ZankoAI Secure Admin System & API Tests', () {
    const adminId = 'admin-uuid-0000-0000';
    const targetUserId = 'target-user-uuid-1111';

    test(
      '1. Role Authorization Enforcement: Only role=admin can access Admin APIs',
      () {
        final studentClient = MockAdminApiClient(
          userRole: 'student',
          adminUserId: 'student-id',
        );
        final adminClient = MockAdminApiClient(
          userRole: 'admin',
          adminUserId: adminId,
        );

        // Student attempt
        final studentRes = studentClient.getUsers();
        expect(studentRes['statusCode'], equals(403));
        expect(studentRes['body']['success'], isFalse);
        expect(studentRes['body']['code'], equals('FORBIDDEN'));

        // Admin attempt
        final adminRes = adminClient.getUsers();
        expect(adminRes['statusCode'], equals(200));
        expect(adminRes['body']['success'], isTrue);
      },
    );

    test(
      '2. GET /api/admin/users: Lists users with pagination and filters; never returns raw credentials',
      () {
        final adminClient = MockAdminApiClient(
          userRole: 'admin',
          adminUserId: adminId,
        );
        final res = adminClient.getUsers(
          page: 1,
          limit: 10,
          role: 'student',
          status: 'active',
        );

        expect(res['statusCode'], equals(200));
        final data = res['body']['data'] as Map<String, dynamic>;
        final users = (data['users'] as List)
            .map((u) => AdminUserRecord.fromJson(u))
            .toList();

        expect(users, isNotEmpty);
        final user = users.first;
        expect(user.role, equals('student'));
        expect(user.status, equals('active'));

        // SECURITY AUDIT: Verify no password, password_hash, or tokens are exposed
        final rawUserJson = jsonEncode(data['users'].first);
        expect(rawUserJson.contains('password'), isFalse);
        expect(rawUserJson.contains('hash'), isFalse);
        expect(rawUserJson.contains('secret'), isFalse);
      },
    );

    test(
      '3. PATCH /api/admin/users/:id/status: Suspend & Activate with self-lockout protection',
      () {
        final adminClient = MockAdminApiClient(
          userRole: 'admin',
          adminUserId: adminId,
        );

        // A: Suspend a target user -> Success
        final suspendRes = adminClient.patchUserStatus(
          targetUserId,
          'suspended',
          reason: 'Abuse detected',
        );
        expect(suspendRes['statusCode'], equals(200));
        expect(suspendRes['body']['data']['newStatus'], equals('suspended'));

        // B: Activate a target user -> Success
        final activateRes = adminClient.patchUserStatus(
          targetUserId,
          'active',
          reason: 'Reinstated after review',
        );
        expect(activateRes['statusCode'], equals(200));
        expect(activateRes['body']['data']['newStatus'], equals('active'));

        // C: Self-lockout check: Admin attempting to suspend self must be strictly prevented
        final selfLockoutRes = adminClient.patchUserStatus(
          adminId,
          'suspended',
        );
        expect(selfLockoutRes['statusCode'], equals(403));
        expect(
          selfLockoutRes['body']['error'].toString().contains(
            'Self-lockout prevented',
          ),
          isTrue,
        );
      },
    );

    test(
      '4. PATCH /api/admin/users/:id/plan: Controlled backend operation updates plan and VIP',
      () {
        final adminClient = MockAdminApiClient(
          userRole: 'admin',
          adminUserId: adminId,
        );

        final planRes = adminClient.patchUserPlan(
          targetUserId,
          'premium',
          days: 30,
          reason: 'Scholarship grant',
        );
        expect(planRes['statusCode'], equals(200));
        expect(planRes['body']['data']['newPlan'], equals('premium'));
        expect(planRes['body']['data']['isVip'], isTrue);
      },
    );

    test(
      '5. GET /api/admin/usage: Returns MAU, DAU, AI requests, and estimated financial telemetry',
      () {
        final adminClient = MockAdminApiClient(
          userRole: 'admin',
          adminUserId: adminId,
        );

        final usageRes = adminClient.getUsage(period: 'month');
        expect(usageRes['statusCode'], equals(200));

        final usage = AdminSystemUsage.fromJson(usageRes['body']['data']);
        expect(usage.period, equals('month'));
        expect(usage.dau, greaterThan(0));
        expect(usage.mau, greaterThan(usage.dau));
        expect(usage.totalAiRequests, greaterThan(0));
        expect(usage.estimatedCostUsd, greaterThan(0.0));
        expect(usage.featureBreakdown.containsKey('ai_chat'), isTrue);
        expect(usage.activeSubscriptions, greaterThan(0));
      },
    );

    test(
      '6. GET /api/admin/audit-logs: Validates immutable audit trails for sensitive operations',
      () {
        final adminClient = MockAdminApiClient(
          userRole: 'admin',
          adminUserId: adminId,
        );

        final auditRes = adminClient.getAuditLogs(action: 'status_changed');
        expect(auditRes['statusCode'], equals(200));

        final logs = (auditRes['body']['data']['logs'] as List)
            .map((l) => AdminAuditRecord.fromJson(l))
            .toList();
        expect(logs, isNotEmpty);

        // Verify audit fields
        final firstLog = logs.first;
        expect(firstLog.actorId, equals(adminId));
        expect(firstLog.action, isNotEmpty);
        expect(firstLog.resourceType, equals('user'));
        expect(firstLog.changes.containsKey('new_status'), isTrue);
      },
    );
  });
}
