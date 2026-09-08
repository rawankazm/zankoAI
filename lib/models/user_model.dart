enum UserRole {
  student,
  teacher,
  admin,
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? universityName;
  final String? departmentName;
  final String? cityName;
  final double? gpa;
  final List<double> gpaHistory;
  final bool isVip;
  final String? photoUrl;
  final String vipStatus; // 'none' | 'pending' | 'active' | 'rejected' | 'expired'
  final DateTime? vipExpiry;
  final String status; // 'active' | 'suspended' | 'deleted' | 'pending'

  bool get isSuspended => status.toLowerCase() == 'suspended';
  bool get isGuest =>
      id.startsWith('guest_') ||
      email.startsWith('guest_') ||
      email == 'guest@zanko.edu' ||
      name == 'مێوان' ||
      name == 'مێڤان' ||
      name == 'زائر' ||
      name.toLowerCase() == 'guest';
  bool get isPendingVip => vipStatus == 'pending';
  bool get isNeedsSetup =>
      !isGuest &&
      (name.trim().isEmpty ||
          name.trim().toLowerCase() == 'student' ||
          universityName == null ||
          universityName!.trim().isEmpty);

  int get vipDaysLeft {
    if (!isVip) return 0;
    if (vipExpiry == null) return 30;
    final diff = vipExpiry!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : (isVip ? 1 : 0);
  }

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.universityName,
    this.departmentName,
    this.cityName,
    this.gpa,
    this.gpaHistory = const [],
    this.isVip = false,
    this.photoUrl,
    this.vipStatus = 'none',
    this.vipExpiry,
    this.status = 'active',
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? universityName,
    String? departmentName,
    String? cityName,
    double? gpa,
    List<double>? gpaHistory,
    bool? isVip,
    String? photoUrl,
    String? vipStatus,
    DateTime? vipExpiry,
    String? status,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      universityName: universityName ?? this.universityName,
      departmentName: departmentName ?? this.departmentName,
      cityName: cityName ?? this.cityName,
      gpa: gpa ?? this.gpa,
      gpaHistory: gpaHistory ?? this.gpaHistory,
      isVip: isVip ?? this.isVip,
      photoUrl: photoUrl ?? this.photoUrl,
      vipStatus: vipStatus ?? this.vipStatus,
      vipExpiry: vipExpiry ?? this.vipExpiry,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'isVip': isVip,
      'vipStatus': vipStatus,
      'vip_expiry': vipExpiry?.toIso8601String(),
      'role': role.toString().split('.').last,
      'universityName': universityName,
      'departmentName': departmentName,
      'cityName': cityName,
      'gpa': gpa,
      'gpaHistory': gpaHistory,
      'photoUrl': photoUrl,
      'status': status,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final rawRole = (map['role'] ?? 'student').toString().toLowerCase();
    final roleVal = UserRole.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == rawRole,
      orElse: () => UserRole.student,
    );

    final rawIsVip = map['is_vip'] ?? map['isVip'];
    final rawVipStatus = (map['vip_status'] ?? map['vipStatus'] ?? '').toString().toLowerCase();
    final rawPlan = (map['plan'] ?? '').toString().toLowerCase();
    final rawSubTier = (map['subscription_tier'] ?? map['subscriptionTier'] ?? '').toString().toUpperCase();

    // Comprehensive VIP evaluation across all database columns and admin roles
    final bool isVipCalculated = rawIsVip == true ||
        rawIsVip == 1 ||
        rawIsVip?.toString().toLowerCase() == 'true' ||
        rawIsVip?.toString() == '1' ||
        rawVipStatus == 'active' ||
        rawVipStatus == 'approved' ||
        rawPlan == 'premium' ||
        rawPlan == 'vip_unlimited' ||
        rawPlan == 'vip' ||
        rawSubTier == 'VIP' ||
        roleVal == UserRole.admin; // Platform Admins automatically receive VIP privileges!

    DateTime? parsedVipExpiry;
    final rawExpiry = map['vip_expiry'] ?? map['vipExpiry'] ?? map['expiresAt'];
    if (rawExpiry is DateTime) {
      parsedVipExpiry = rawExpiry;
    } else if (rawExpiry is String && rawExpiry.isNotEmpty) {
      parsedVipExpiry = DateTime.tryParse(rawExpiry);
    }

    return UserModel(
      id: map['id']?.toString() ?? '',
      name: (map['full_name'] ?? map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      isVip: isVipCalculated,
      vipStatus: (map['vip_status'] ?? map['vipStatus'] ?? (isVipCalculated ? 'active' : 'none')).toString(),
      vipExpiry: parsedVipExpiry,
      role: roleVal,
      universityName: map['university_name']?.toString() ?? map['universityName']?.toString(),
      departmentName: map['department_name']?.toString() ?? map['departmentName']?.toString(),
      cityName: map['city_name']?.toString() ?? map['cityName']?.toString(),
      gpa: (map['gpa'] as num?)?.toDouble(),
      gpaHistory: map['gpa_history'] != null
          ? List<double>.from((map['gpa_history'] as List).map((x) => (x as num).toDouble()))
          : (map['gpaHistory'] != null ? List<double>.from((map['gpaHistory'] as List).map((x) => (x as num).toDouble())) : const []),
      photoUrl: map['avatar_url']?.toString() ?? map['photoUrl']?.toString(),
      status: (map['status'] ?? 'active').toString(),
    );
  }
}

