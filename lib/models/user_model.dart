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

  bool get isGuest => id.startsWith('guest_user') || email == 'guest@zanko.edu';

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'isVip': isVip,
      'role': role.toString().split('.').last,
      'universityName': universityName,
      'departmentName': departmentName,
      'cityName': cityName,
      'gpa': gpa,
      'gpaHistory': gpaHistory,
      'photoUrl': photoUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => UserRole.student,
      ),
      universityName: map['universityName'],
      departmentName: map['departmentName'],
      cityName: map['cityName'],
      gpa: map['gpa']?.toDouble(),
      gpaHistory: map['gpaHistory'] != null 
          ? List<double>.from(map['gpaHistory'].map((x) => x.toDouble())) 
          : const [],
      photoUrl: map['photoUrl'],
    );
  }
}

