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
  final double? gpa;
  final List<double> gpaHistory;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.universityName,
    this.departmentName,
    this.gpa,
    this.gpaHistory = const [3.2, 3.4, 3.65, 3.8],
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? universityName,
    String? departmentName,
    double? gpa,
    List<double>? gpaHistory,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      universityName: universityName ?? this.universityName,
      departmentName: departmentName ?? this.departmentName,
      gpa: gpa ?? this.gpa,
      gpaHistory: gpaHistory ?? this.gpaHistory,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'universityName': universityName,
      'departmentName': departmentName,
      'gpa': gpa,
      'gpaHistory': gpaHistory,
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
      gpa: map['gpa']?.toDouble(),
      gpaHistory: map['gpaHistory'] != null 
          ? List<double>.from(map['gpaHistory'].map((x) => x.toDouble())) 
          : const [3.2, 3.4, 3.65, 3.8],
    );
  }
}
