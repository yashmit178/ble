import 'package:ble/src/models/lesson_schedule.dart';
import 'package:firebase_database/firebase_database.dart';

class ScheduleRepository {
  final _dbRef = FirebaseDatabase.instance.ref();

  // Get current lesson for a professor in a specific classroom
  Future<LessonSchedule?> getCurrentLesson(String professorId,
      String classroomId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(Duration(days: 1));

      final snapshot = await _dbRef
          .child('lessons')
          .orderByChild('professorId')
          .equalTo(professorId)
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(
            snapshot.value as Map<dynamic, dynamic>);

        for (var entry in data.entries) {
          final lessonData = Map<String, dynamic>.from(
              entry.value as Map<dynamic, dynamic>);
          final lesson = LessonSchedule.fromMap(entry.key, lessonData);

          // Check if lesson is for this classroom and is currently active or starts soon
          if (lesson.classroomId == classroomId &&
              (lesson.isCurrentlyActive || lesson.startsWithin15Minutes)) {
            return lesson;
          }
        }
      }
      return null;
    } catch (e) {
      print('Error getting current lesson: $e');
      return null;
    }
  }

  // Get all lessons for a professor today
  Future<List<LessonSchedule>> getTodayLessons(String professorId) async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(Duration(days: 1));

      final snapshot = await _dbRef
          .child('lessons')
          .orderByChild('professorId')
          .equalTo(professorId)
          .get();

      List<LessonSchedule> lessons = [];

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(
            snapshot.value as Map<dynamic, dynamic>);

        for (var entry in data.entries) {
          final lessonData = Map<String, dynamic>.from(
              entry.value as Map<dynamic, dynamic>);
          final lesson = LessonSchedule.fromMap(entry.key, lessonData);

          // Filter lessons for today
          if (lesson.startTime.isAfter(todayStart) &&
              lesson.startTime.isBefore(todayEnd)) {
            lessons.add(lesson);
          }
        }
      }

      // Sort by start time
      lessons.sort((a, b) => a.startTime.compareTo(b.startTime));
      return lessons;
    } catch (e) {
      print('Error getting today lessons: $e');
      return [];
    }
  }

  // Get next lesson for a professor
  Future<LessonSchedule?> getNextLesson(String professorId) async {
    try {
      final now = DateTime.now();
      final snapshot = await _dbRef
          .child('lessons')
          .orderByChild('professorId')
          .equalTo(professorId)
          .get();

      LessonSchedule? nextLesson;

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(
            snapshot.value as Map<dynamic, dynamic>);

        for (var entry in data.entries) {
          final lessonData = Map<String, dynamic>.from(
              entry.value as Map<dynamic, dynamic>);
          final lesson = LessonSchedule.fromMap(entry.key, lessonData);

          // Find next lesson (starts after now)
          if (lesson.startTime.isAfter(now) && lesson.isActive) {
            if (nextLesson == null ||
                lesson.startTime.isBefore(nextLesson.startTime)) {
              nextLesson = lesson;
            }
          }
        }
      }

      return nextLesson;
    } catch (e) {
      print('Error getting next lesson: $e');
      return null;
    }
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
  Future<void> logClassroomAccess(String professorId, String classroomId,
      String action) async {
    try {
      final logRef = _dbRef.child('access_logs').push();
      await logRef.set({
        'professorId': professorId,
        'classroomId': classroomId,
        'action': action, // 'unlock', 'lock', 'setup', 'shutdown'
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging classroom access: $e');
    }
  }
}