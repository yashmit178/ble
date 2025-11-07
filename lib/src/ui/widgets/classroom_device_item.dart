import 'package:ble/src/controllers/schedule/schedule_repository.dart';
import 'package:ble/src/models/esp32_classroom/esp32_classroom.dart';
import 'package:ble/src/models/lesson_schedule.dart';
import 'package:flutter/material.dart';

class ClassroomDeviceItem extends StatefulWidget {
  final ESP32Classroom device;
  final String? professorId;
  final String? classroomId;

  const ClassroomDeviceItem({
    Key? key,
    required this.device,
    this.professorId,
    this.classroomId,
  }) : super(key: key);

  @override
  State<ClassroomDeviceItem> createState() => _ClassroomDeviceItemState();
}

class _ClassroomDeviceItemState extends State<ClassroomDeviceItem> {
  final ScheduleRepository _scheduleRepository = ScheduleRepository();
  LessonSchedule? _currentLesson;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentLesson();
  }

  Future<void> _checkCurrentLesson() async {
    if (widget.professorId != null && widget.classroomId != null) {
      setState(() => _isLoading = true);
      final lesson = await _scheduleRepository.getCurrentLesson(
        widget.professorId!,
        widget.classroomId!,
      );
      setState(() {
        _currentLesson = lesson;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.school,
                  color: Colors.blue,
                  size: 24,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.device.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Classroom ID: ${widget.classroomId ?? "Unknown"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildConnectionStatus(),
              ],
            ),
            SizedBox(height: 16),
            _buildLessonInfo(),
            SizedBox(height: 16),
            _buildClassroomStatus(),
            /*SizedBox(height: 16),
            _buildControlButtons(),*/
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Connected',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLessonInfo() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_currentLesson == null) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'No active lesson found',
              style: TextStyle(color: Colors.orange[800]),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currentLesson!.subjectName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Time: ${_formatTime(_currentLesson!.startTime)} - ${_formatTime(
                _currentLesson!.endTime)}',
            style: TextStyle(fontSize: 14),
          ),
          Text(
            'Remaining: ${_currentLesson!.remainingMinutes} minutes',
            style: TextStyle(fontSize: 14, color: Colors.green[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildClassroomStatus() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusItem(
            'Door',
            widget.device.isDoorUnlocked ? 'Unlocked' : 'Locked',
            widget.device.isDoorUnlocked ? Colors.green : Colors.red,
            widget.device.isDoorUnlocked ? Icons.lock_open : Icons.lock,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatusItem(
            'Projector',
            widget.device.isProjectorOn ? 'On' : 'Off',
            widget.device.isProjectorOn ? Colors.blue : Colors.grey,
            widget.device.isProjectorOn ? Icons.videocam : Icons.videocam_off,
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _buildStatusItem(
            'Timer',
            '${widget.device.remainingMinutes}m',
            widget.device.remainingMinutes > 0 ? Colors.orange : Colors.grey,
            Icons.timer,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(String label, String value, Color color,
      IconData icon) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }

 /* Widget _buildControlButtons() {
    if (_currentLesson == null) {
      return Text(
        'Classroom controls unavailable without active lesson',
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      );
    }

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _setupClassroom,
            icon: Icon(Icons.play_circle),
            label: Text('Setup Classroom'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _shutdownClassroom,
            icon: Icon(Icons.stop_circle),
            label: Text('Shutdown'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }*/

  /*Future<void> _setupClassroom() async {
    if (_currentLesson == null) return;

    try {
      setState(() => _isLoading = true);
      await widget.device.setupClassroom(_currentLesson!.durationMinutes);

      // Log the action
      if (widget.professorId != null && widget.classroomId != null) {
        await _scheduleRepository.logClassroomAccess(
          widget.professorId!,
          widget.classroomId!,
          'setup',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Classroom setup completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to setup classroom: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }*/

  /*Future<void> _shutdownClassroom() async {
    try {
      setState(() => _isLoading = true);
      await widget.device.shutdownClassroom();

      // Log the action
      if (widget.professorId != null && widget.classroomId != null) {
        await _scheduleRepository.logClassroomAccess(
          widget.professorId!,
          widget.classroomId!,
          'shutdown',
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Classroom shutdown completed successfully!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to shutdown classroom: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }*/

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute
        .toString()
        .padLeft(2, '0')}';
  }
}