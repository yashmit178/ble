import 'package:ble/src/models/lesson_schedule.dart';
import 'package:firebase_database/firebase_database.dart';

class ScheduleRepository {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  // Get current active lesson for a professor in a specific classroom
  Future<LessonSchedule?> getCurrentLesson(
      String professorId, String classroomId) async {
    try {
      print(
          "ScheduleRepository: Checking lessons for professor: $professorId, classroom: $classroomId");

      // Query all lessons from Firebase
      final DataSnapshot snapshot = await _dbRef.child('lessons').get();

      if (!snapshot.exists) {
        print("ScheduleRepository: No lessons found in database");
        return null;
      }

      final Map<dynamic, dynamic> lessonsData =
          snapshot.value as Map<dynamic, dynamic>;
      final DateTime now = DateTime.now();
      print("ScheduleRepository: Current time: $now");
      print(
          "ScheduleRepository: Found ${lessonsData.length} lessons in database");

      // Check each lesson
      for (var entry in lessonsData.entries) {
        final String lessonId = entry.key;
        final Map<String, dynamic> lessonData =
            Map<String, dynamic>.from(entry.value);

        print(
            "ScheduleRepository: Checking lesson $lessonId: ${lessonData['subjectName']}");
        print(
            "ScheduleRepository: Professor: ${lessonData['professorId']}, Classroom: ${lessonData['classroomId']}");

        // Check if this lesson matches professor and classroom
        if (lessonData['professorId'] == professorId &&
            lessonData['classroomId'] == classroomId &&
            lessonData['isActive'] == true) {
          final DateTime startTime = DateTime.parse(lessonData['startTime']);
          final DateTime endTime = DateTime.parse(lessonData['endTime']);

          print("ScheduleRepository: Lesson time: $startTime to $endTime");

          // Check if lesson is currently active (with 10 minute buffer after end)
          final DateTime endWithBuffer = endTime.add(Duration(minutes: 10));

          if (now.isAfter(startTime) && now.isBefore(endWithBuffer)) {
            print(
                "ScheduleRepository: Found active lesson: ${lessonData['subjectName']}");

            final lesson = LessonSchedule.fromMap(lessonId, lessonData);
            return lesson;
          } else {
            print(
                "ScheduleRepository: Lesson not active now. Current: $now, Start: $startTime, End: $endTime");
          }
        } else {
          print("ScheduleRepository: Lesson doesn't match criteria");
        }
      }

      print(
          "ScheduleRepository: No active lesson found for professor $professorId in classroom $classroomId");
      return null;
    } catch (e) {
      print("ScheduleRepository: Error getting current lesson: $e");
      return null;
    }
  }

  // Get all lessons for a professor
  Future<List<LessonSchedule>> getLessonsForProfessor(
      String professorId) async {
    try {
      final DataSnapshot snapshot = await _dbRef
          .child('lessons')
          .orderByChild('professorId')
          .equalTo(professorId)
          .get();

      if (!snapshot.exists) return [];

      final Map<dynamic, dynamic> lessonsData =
          snapshot.value as Map<dynamic, dynamic>;
      List<LessonSchedule> lessons = [];

      lessonsData.forEach((key, value) {
        final lessonData = Map<String, dynamic>.from(value);
        lessons.add(LessonSchedule.fromMap(key, lessonData));
      });

      return lessons;
    } catch (e) {
      print("Error getting lessons for professor: $e");
      return [];
    }
  }

  // Get lessons for today
  Future<List<LessonSchedule>> getTodaysLessons(String professorId) async {
    final allLessons = await getLessonsForProfessor(professorId);
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = startOfDay.add(Duration(days: 1));

    return allLessons.where((lesson) {
      return lesson.startTime.isAfter(startOfDay) &&
          lesson.startTime.isBefore(endOfDay) &&
          lesson.isActive;
    }).toList();
  }

  // Create a new lesson
  Future<bool> createLesson(LessonSchedule lesson) async {
    try {
      final newLessonRef = _dbRef.child('lessons').push();
      await newLessonRef.set(lesson.toMap());
      return true;
    } catch (e) {
      print('Error creating lesson: $e');
      return false;
    }
  }

  // Update lesson status
  Future<bool> updateLessonStatus(String lessonId, bool isActive) async {
    try {
      await _dbRef.child('lessons').child(lessonId).update(
          {'isActive': isActive});
      return true;
    } catch (e) {
      print('Error updating lesson status: $e');
      return false;
    }
  }

  // Get classroom information
  Future<Map<String, dynamic>?> getClassroomInfo(String classroomId) async {
    try {
      final snapshot = await _dbRef
          .child('classrooms')
          .child(classroomId)
          .get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(
            snapshot.value as Map<dynamic, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting classroom info: $e');
      return null;
    }
  }

  // Log classroom access
  Future<void> logClassroomAccess(
    String professorId,
    String classroomId,
    String action, {
    String? lessonId,
    int? duration,
  }) async {
    try {
      final logRef = _dbRef.child('access_logs').push();

      await logRef.set({
        'professorId': professorId,
        'classroomId': classroomId,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
        'lessonId': lessonId,
        'duration': duration,
      });

      print(
          "Classroom access logged: $action for $professorId in $classroomId");
    } catch (e) {
      print("Error logging classroom access: $e");
    }
  }
}