import 'dart:async';
import 'dart:ui';

import 'package:ble/src/controllers/auth/auth_repository.dart';
import 'package:ble/src/controllers/ble/ble_repository.dart';
import 'package:ble/src/controllers/schedule/schedule_repository.dart';
import 'package:ble/src/controllers/service/local_services.dart';
import 'package:ble/src/models/abstract_device.dart';
import 'package:ble/src/models/esp32_classroom/esp32_classroom.dart';
import 'package:ble/src/models/lesson_schedule.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

// Notification Plugin as global variable
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

// Notification Channel
const String notificationChannelId = 'classroom_automation_service';
const int notificationId = 888;

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  // Configure Notifications
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

  // Configure the Service
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      notificationChannelId: notificationChannelId,
      initialNotificationTitle: 'Classroom Automation',
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

// iOS Background Entrypoint
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

// Main Background Service Entrypoint
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  void updateNotification(String title, String body) {
    print("BackgroundService: $title - $body");
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

  // Skip permission checks in background service - they should be granted from main app
  print(
      "BackgroundService: Starting without permission checks (assuming already granted)");
  updateNotification('Classroom Automation', 'Service is starting...');

  // Initialize Firebase with better error handling
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "dummy",
        appId: "dummy",
        messagingSenderId: "dummy",
        projectId: "dummy",
        databaseURL:
            "https://classroom-6206e-default-rtdb.europe-west1.firebasedatabase.app/",
      ),
    );
    print("BackgroundService: Firebase initialized successfully");
  } catch (e) {
    print("BackgroundService: Firebase initialization failed: $e");
    updateNotification('Firebase Error', 'Unable to connect to database');
    // Continue anyway - we can still try BLE operations
  }

  // Initialize Repositories with better error handling
  final authRepo = AuthRepository();
  final scheduleRepo = ScheduleRepository();
  final bleRepo = BleRepository(LocalServices());

  // Service State Variables
  LessonSchedule? _activeLesson;
  AbstractDevice? _connectedDevice;
  StreamSubscription<AbstractDevice>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  bool _isConnecting = false;
  String _currentStatus = "Service initialized. Checking authentication...";
  int updateCounter = 0;

  updateNotification('Classroom Automation', 'Service is running.');

  // Core Automation Logic
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    try {
      print("BackgroundService: Running automation cycle...");
      updateNotification('Service Active', 'Checking for active lessons...');

      // === DEBUG: BLE SCANNING TEST ===
      if (updateCounter == 0) {
        // Only run once
        print("BackgroundService: === RUNNING BLE DEBUG TEST ===");
        try {
          final adapterState = await FlutterBluePlus.adapterState.first;
          print("BackgroundService: BLE Adapter State: $adapterState");

          if (adapterState == BluetoothAdapterState.on) {
            print("BackgroundService: Starting debug scan for ALL devices...");
            await FlutterBluePlus.stopScan();

            // Try different scanning approach for background service
            print(
                "BackgroundService: Attempting scan without timeout first...");
            FlutterBluePlus.startScan();

            // Use stream subscription to get results
            bool foundDevices = false;
            StreamSubscription? debugScanSub;

            debugScanSub = FlutterBluePlus.scanResults.listen((results) {
              if (results.isNotEmpty && !foundDevices) {
                foundDevices = true;
                print(
                    "BackgroundService: Debug scan found ${results.length} devices");
                for (var r in results) {
                  print(
                      "BackgroundService: Found: ${r.device.platformName} (${r.device.remoteId.str}) RSSI: ${r.rssi}");
                }
              }
            });

            // Wait for scan results
            await Future.delayed(Duration(seconds: 8));

            await debugScanSub?.cancel();
            await FlutterBluePlus.stopScan();

            print(
                "BackgroundService: Debug scan complete. Found devices: $foundDevices");

            // If no devices found, Android might be blocking background BLE scanning
            if (!foundDevices) {
              updateNotification('BLE Debug',
                  'No devices found - Android may be blocking background BLE');
            } else {
              updateNotification(
                  'BLE Debug', 'BLE scanning works - found devices');
            }
          }
        } catch (e) {
          print("BackgroundService: Debug scan error: $e");
          updateNotification('BLE Error', 'Scan failed: $e');
        }
        print("BackgroundService: === BLE DEBUG TEST COMPLETE ===");
      }
      // === END DEBUG TEST ===

      // Check if user is authenticated - use simpler approach for background service
      bool hasToken = false;
      String? professorId;
      String? username;

      try {
        hasToken = await authRepo.hasToken();
        professorId = await authRepo.getProfessorId();
        username = await authRepo.getUsername();
      } catch (e) {
        print("BackgroundService: Auth check failed: $e");
        _currentStatus = "Authentication check failed. Service paused.";
        updateNotification('Auth Error', 'Cannot verify login status.');
        return;
      }

      print(
          "BackgroundService: Auth status - hasToken: $hasToken, professorId: $professorId, username: $username");

      if (!hasToken || professorId == null) {
        _currentStatus = "User is not logged in. Service paused.";
        updateNotification('Automation Paused', 'Please log in to the app.');

        // Clean up connections
        await _scanSubscription?.cancel();
        _scanSubscription = null;
        await _connectedDevice?.disconnect();
        _connectedDevice = null;
        await _connectionSubscription?.cancel();
        _connectionSubscription = null;
        return;
      }

      print("BackgroundService: User authenticated as $professorId");

      // Check for active lesson in classroom A
      const classroomId = "classroom_a";
      try {
        _activeLesson =
            await scheduleRepo.getCurrentLesson(professorId, classroomId);
      } catch (e) {
        print("BackgroundService: Error checking lessons: $e");
        updateNotification('Database Error', 'Cannot check lesson schedule');
        return;
      }

      print(
          "BackgroundService: Active lesson check result: ${_activeLesson?.subjectName ?? 'None'}");

      if (_activeLesson != null) {
        // LESSON IS ACTIVE
        _currentStatus = "Lesson found: ${_activeLesson!.subjectName}.";
        print(
            "BackgroundService: Active lesson found: ${_activeLesson!.subjectName}");

        if (_connectedDevice == null && !_isConnecting) {
          _currentStatus = "Scanning for Classroom A...";
          updateNotification('Active Lesson', _currentStatus);
          print("BackgroundService: Starting scan for classroom device...");

          _scanSubscription ??= bleRepo.startScanning().listen((device) async {
            if (_isConnecting || _connectedDevice != null) {
              print(
                  "BackgroundService: Already connecting or connected, ignoring device");
              return;
            }

            _isConnecting = true;
            print(
                "BackgroundService: Found device: ${device.name} (${device.uuid})");

            await _scanSubscription?.cancel();
            _scanSubscription = null;

            _currentStatus = "Connecting to ${device.name}...";
              updateNotification('Classroom Found', _currentStatus);

              try {
                // Set up connection state listener
                _connectionSubscription =
                    bleRepo.listenToConnection(device, (state) {
                      print(
                          "BackgroundService: Connection state changed: $state");
                      if (state == BluetoothConnectionState.disconnected) {
                        print("BackgroundService: Device disconnected");
                        _connectedDevice = null;
                        _connectionSubscription?.cancel();
                        _connectionSubscription = null;
                        updateNotification('Device Disconnected',
                            'Will re-scan if lesson is active.');
                      }
                    });

                // Connect to device
                await bleRepo.connect(device, (disconnectedDevice, state) {
                  if (state == BluetoothConnectionState.disconnected) {
                    print(
                        "BackgroundService: Device disconnected via callback");
                    _connectedDevice = null;
                    _connectionSubscription?.cancel();
                    _connectionSubscription = null;
                    updateNotification('Device Disconnected',
                        'Will re-scan if lesson is active.');
                  }
                });

                _connectedDevice = device;
                print("BackgroundService: Successfully connected to ${device
                    .name}");

                // Set up classroom if it's an ESP32 classroom device
                if (_connectedDevice is ESP32Classroom) {
                  _currentStatus = "Connected! Setting up classroom...";
                  updateNotification('Connected', _currentStatus);

                  final classroom = _connectedDevice as ESP32Classroom;
                  await classroom.setupClassroom(
                      _activeLesson!.durationMinutes);

                  _currentStatus =
                  "Classroom is ready for ${_activeLesson!.subjectName}";
                  updateNotification('Setup Complete', _currentStatus);
                  print("BackgroundService: Classroom setup completed");
                } else {
                  _currentStatus = "Connected to unknown device type.";
                  updateNotification('Warning', _currentStatus);
                  print(
                      "BackgroundService: WARNING - Connected device is not ESP32Classroom type");
                }
              } catch (e) {
                print("BackgroundService: Connection failed - $e");
                _currentStatus = "Connection failed. Retrying in next cycle...";
                updateNotification('Connection Error', _currentStatus);
                _connectedDevice = null;
                _connectionSubscription?.cancel();
                _connectionSubscription = null;
              } finally {
                _isConnecting = false;
              }
            },
              onError: (e) {
                print("BackgroundService: Scan error - $e");
                _scanSubscription?.cancel();
                _scanSubscription = null;
                _isConnecting = false;
                updateNotification('Scan Error', 'Will retry in next cycle...');
              },
              onDone: () {
                print("BackgroundService: Scan completed");
                _scanSubscription = null;
                _isConnecting = false;
              }
          );
        } else if (_connectedDevice != null) {
          _currentStatus =
          "Classroom is ready for ${_activeLesson!.subjectName}";
          // Only update notification every few cycles to avoid spam
          updateCounter++;
          if (updateCounter % 10 ==
              0) { // Update every 5 minutes (10 * 30 seconds)
            updateNotification('Classroom Ready', _currentStatus);
          }
        }
      } else {
        // NO ACTIVE LESSON
        print("BackgroundService: No active lesson found");
        _currentStatus = "No active lesson. Scanning paused.";
        updateNotification('Automation Paused', 'No active lesson scheduled.');

        // Clean up scanning
        await _scanSubscription?.cancel();
        _scanSubscription = null;

        // Shutdown classroom if connected
        if (_connectedDevice != null) {
          _currentStatus = "Lesson ended. Shutting down classroom.";
          updateNotification('Lesson Ended', _currentStatus);
          print("BackgroundService: Shutting down classroom...");

          try {
            if (_connectedDevice is ESP32Classroom) {
              await (_connectedDevice as ESP32Classroom).shutdownClassroom();
              print("BackgroundService: Classroom shutdown completed");
            }
          } catch (e) {
            print("BackgroundService: Error shutting down classroom - $e");
          }

          await _connectedDevice!.disconnect();
          _connectedDevice = null;
          await _connectionSubscription?.cancel();
          _connectionSubscription = null;
        }
      }
    } catch (e) {
      print("BackgroundService: Error in automation cycle - $e");
      updateNotification('Service Error', 'Error: $e');
    }
  });
}