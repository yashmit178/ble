import 'package:equatable/equatable.dart';

class LessonSchedule extends Equatable {
  final String id;
  final String professorId;
  final String classroomId;
  final String subjectName;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;

  const LessonSchedule({
    required this.id,
    required this.professorId,
    required this.classroomId,
    required this.subjectName,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
  });

  // Create from Firebase data
  factory LessonSchedule.fromMap(String id, Map<String, dynamic> data) {
    return LessonSchedule(
      id: id,
      professorId: data['professorId'] ?? '',
      classroomId: data['classroomId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      startTime: DateTime.parse(data['startTime']),
      endTime: DateTime.parse(data['endTime']),
      isActive: data['isActive'] ?? true,
    );
  }

  // Convert to Firebase data
  Map<String, dynamic> toMap() {
    return {
      'professorId': professorId,
      'classroomId': classroomId,
      'subjectName': subjectName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'isActive': isActive,
    };
  }

  // Check if lesson is currently active (within time + 10 min buffer)
  bool get isCurrentlyActive {
    final now = DateTime.now();
    final endWithBuffer = endTime.add(Duration(minutes: 10));
    return now.isAfter(startTime) && now.isBefore(endWithBuffer) && isActive;
  }

  // Check if lesson starts soon (within 15 minutes)
  bool get startsWithin15Minutes {
    final now = DateTime.now();
    final startWithBuffer = startTime.subtract(Duration(minutes: 15));
    return now.isAfter(startWithBuffer) && now.isBefore(startTime);
  }

  // Get lesson duration in minutes
  int get durationMinutes {
    return endTime.difference(startTime).inMinutes;
  }

  // Get remaining lesson time in minutes
  int get remainingMinutes {
    final now = DateTime.now();
    if (now.isBefore(startTime)) return durationMinutes;
    if (now.isAfter(endTime)) return 0;
    return endTime.difference(now).inMinutes;
  }

  LessonSchedule copyWith({
    String? id,
    String? professorId,
    String? classroomId,
    String? subjectName,
    DateTime? startTime,
    DateTime? endTime,
    bool? isActive,
  }) {
    return LessonSchedule(
      id: id ?? this.id,
      professorId: professorId ?? this.professorId,
      classroomId: classroomId ?? this.classroomId,
      subjectName: subjectName ?? this.subjectName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        professorId,
        classroomId,
        subjectName,
        startTime,
        endTime,
        isActive,
      ];

  @override
  String toString() {
    return 'LessonSchedule{id: $id, subject: $subjectName, professor: $professorId, classroom: $classroomId, time: $startTime - $endTime}';
  }
}