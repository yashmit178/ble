import 'dart:async';
import 'dart:ui';

import 'package:ble/src/controllers/auth/auth_repository.dart';
import 'package:ble/src/controllers/ble/ble_repository.dart';
import 'package:ble/src/controllers/schedule/schedule_repository.dart';
import 'package:ble/src/controllers/service/local_services.dart';
import 'package:ble/src/models/abstract_device.dart';
import 'package:ble/src/models/esp32_classroom/esp32_classroom.dart'; // <-- FIX: Import ESP32 model
import 'package:ble/src/models/lesson_schedule.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// --- FIX: Define Notification Plugin as a global/static variable ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Notification Channel
const String notificationChannelId = 'classroom_automation_service';
const int notificationId = 888;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // --- 1. Configure Notifications ---
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    notificationChannelId,
    'Classroom Automation Service',
    description: 'This channel is used for the automation service.',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // --- 2. Configure the Service ---
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Classroom Automation',
      // --- FIX: Parameter name is 'initialNotificationContent' ---
      initialNotificationContent: 'Service is starting...',
      foregroundServiceNotificationId: notificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

// --- 3. iOS Background Entrypoint ---
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// --- 4. Main Background Service Entrypoint ---
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // --- 5. Initialize Repositories ---
  await Firebase.initializeApp();

  final authRepo = AuthRepository();
  final scheduleRepo = ScheduleRepository();
  final bleRepo = BleRepository(LocalServices());

  // --- 6. Service State Variables ---
  LessonSchedule? _activeLesson;
  AbstractDevice? _connectedDevice;
  StreamSubscription<AbstractDevice>? _scanSubscription; // <-- FIX: Stream is of AbstractDevice
  bool _isConnecting = false;
  String _currentStatus = "Service initialized. Waiting for login.";

  // --- 7. Service Notification Helper (No changes) ---
  void updateNotification(String title, String body) {
    flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          notificationChannelId,
          'Classroom Automation Service',
          importance: Importance.low,
          ongoing: true,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
    service.invoke('update', {'status': title, 'body': body});
  }

  updateNotification('Classroom Automation', 'Service is running.');

  // --- 8. Core Automation Logic ---
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    final professorId = await authRepo.getProfessorId();
    if (professorId == null) {
      _currentStatus = "User is not logged in. Paused.";
      updateNotification('Automation Paused', 'Please log in to the app.');
      _scanSubscription?.cancel();
      _scanSubscription = null;
      _connectedDevice?.disconnect();
      _connectedDevice = null;
      return;
    }

    const classroomId = "classroom_a";
    _activeLesson = await scheduleRepo.getCurrentLesson(professorId, classroomId);

    if (_activeLesson != null) {
      // --- LESSON IS ACTIVE ---
      _currentStatus = "Lesson found: ${_activeLesson!.subjectName}.";

      if (_connectedDevice == null && !_isConnecting) {
        _currentStatus = "Scanning for $classroomId...";
        updateNotification('Active Lesson', _currentStatus);

        if (_scanSubscription == null) {
          // --- FIX: Call is startDiscovering() ---
          _scanSubscription = bleRepo.startDiscovering().listen(
                  (device) async {
                if (_isConnecting) return;
                _isConnecting = true;
                await _scanSubscription?.cancel();
                _scanSubscription = null;

                _currentStatus = "Connecting to ${device.name}...";
                updateNotification('Classroom Found', _currentStatus);

                try {
                  // --- FIX: Pass the required callback function ---
                  await bleRepo.connect(device, (disconnectedDevice, state) {
                    if (state == BluetoothConnectionState.disconnected) {
                      _connectedDevice = null;
                      updateNotification('Device Disconnected', 'Will re-scan if lesson is active.');
                    }
                  });

                  _connectedDevice = device;

                  // --- G. THIS IS YOUR AUTOMATION ---
                  // --- FIX: Cast to ESP32Classroom and check getter ---
                  if (_connectedDevice is ESP32Classroom) {
                    _currentStatus = "Connected! Setting up classroom...";
                    updateNotification('Connected', _currentStatus);
                    await (_connectedDevice as ESP32Classroom).setupClassroom(_activeLesson!.durationInMinutes);
                    _currentStatus = "Classroom is ready.";
                    updateNotification('Setup Complete', _currentStatus);
                  } else {
                    _currentStatus = "Connected to unknown device type.";
                    updateNotification('Error', _currentStatus);
                  }
                  // --- END OF FIX ---

                } catch (e) {
                  _currentStatus = "Connection failed. Retrying...";
                  updateNotification('Connection Error', _currentStatus);
                  _connectedDevice = null;
                } finally {
                  _isConnecting = false;
                }
              },
              // Add onError to handle scan failures
              onError: (e) {
                print("Scan error: $e");
                _scanSubscription?.cancel();
                _scanSubscription = null;
                _isConnecting = false;
              },
              onDone: () {
                _scanSubscription = null;
              }
          );
        }
      } else if (_connectedDevice != null) {
        _currentStatus = "Classroom is ready.";
        updateNotification('Setup Complete', _currentStatus);
      }
    } else {
      // --- NO ACTIVE LESSON ---
      _currentStatus = "No active lesson. Scanning paused.";
      updateNotification('Automation Paused', _currentStatus);

      await _scanSubscription?.cancel();
      _scanSubscription = null;

      if (_connectedDevice != null) {
        _currentStatus = "Lesson ended. Shutting down classroom.";
        updateNotification('Lesson Ended', _currentStatus);
        try {
          // --- FIX: Cast to ESP32Classroom ---
          if (_connectedDevice is ESP32Classroom) {
            await (_connectedDevice as ESP32Classroom).shutdownClassroom();
          }
        } catch (e) {
          print("Error shutting down: $e");
        }
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }
    }
  });
}