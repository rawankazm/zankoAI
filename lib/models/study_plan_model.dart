class StudyPlanDayModel {
  final String dayName;
  final String taskDescription;

  StudyPlanDayModel({
    required this.dayName,
    required this.taskDescription,
  });

  Map<String, dynamic> toMap() {
    return {
      'dayName': dayName,
      'taskDescription': taskDescription,
    };
  }

  factory StudyPlanDayModel.fromMap(Map<String, dynamic> map) {
    return StudyPlanDayModel(
      dayName: map['dayName'] ?? '',
      taskDescription: map['taskDescription'] ?? '',
    );
  }
}
