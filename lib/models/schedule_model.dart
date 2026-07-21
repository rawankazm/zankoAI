class ScheduleModel {
  final String id;
  final String courseName;
  final String time;      // e.g. "09:00 - 10:30"
  final String location;  // e.g. "هۆڵی ٣، بەشی کۆمپیوتەر"
  final String dayName;   // e.g. "شەممە", "یەکشەممە"
  final String teacherName;

  ScheduleModel({
    required this.id,
    required this.courseName,
    required this.time,
    required this.location,
    required this.dayName,
    required this.teacherName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'courseName': courseName,
      'time': time,
      'location': location,
      'dayName': dayName,
      'teacherName': teacherName,
    };
  }

  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      id: map['id'] ?? '',
      courseName: map['courseName'] ?? '',
      time: map['time'] ?? '',
      location: map['location'] ?? '',
      dayName: map['dayName'] ?? '',
      teacherName: map['teacherName'] ?? '',
    );
  }
}
