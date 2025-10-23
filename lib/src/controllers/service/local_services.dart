import 'package:ble/src/controllers/service/service_repository.dart';
import 'package:ble/src/models/custom_response.dart';

class LocalServices extends ServiceRepository {
  @override
  Future<CustomResponse<List<String>>> getKnownDeviceUuid() {
    return Future.delayed(
      Duration.zero,
      () => CustomResponse(
        status: true,
        data: [
          "24:6F:28:7C:94:FE", // FIXED: Correct ESP32 MAC address
          // Original Smart Switch devices
          //"80:F5:B5:69:B8:64",
          //"C4:19:D1:06:C8:B9",
          // ESP32 Classroom devices - REPLACE WITH YOUR REAL MAC ADDRESSES
          // Example: "24:6F:28:12:34:56", // Your ESP32 Classroom A

          // PLACEHOLDER - Replace with your real ESP32 MAC
          //"24:6F:28:DD:EE:FF",
          // PLACEHOLDER - Replace if you have multiple ESP32s
          //"30:AE:A4:11:22:33",
          // PLACEHOLDER - Replace if you have multiple ESP32s
          // Add more ESP32 MAC addresses as needed for additional classrooms
        ],
      ),
    );
  }

  @override
  Future<CustomResponse<String>> login(String user, String password) {
    return Future.delayed(
      Duration(seconds: 2),
      () => CustomResponse(
        status: _validateLogin(user, password),
        data: 'mock_token',
      ),
    );
  }

  bool _validateLogin(String user, String password) {
    // Match your Firebase database structure
    final validCredentials = {
      'username1': 'abcd',
      'username2': '1234',
      'admin': 'admin', // Keep admin for testing
    };

    return validCredentials[user] == password;
  }

  // Get professor information (updated to match your database)
  Future<CustomResponse<Map<String, dynamic>>> getProfessorInfo(
      String username) {
    return Future.delayed(
      Duration.zero,
      () {
        // Match your Firebase user structure
        final professors = {
          'username1': {
            'id': 'prof_001',
            'name': 'Dr. John Smith',
            'department': 'Computer Science',
            'email': 'john.smith@university.edu',
          },
          'username2': {
            'id': 'prof_002',
            'name': 'Prof. Sarah Johnson',
            'department': 'Mathematics',
            'email': 'sarah.johnson@university.edu',
          },
          'admin': {
            'id': 'prof_admin',
            'name': 'System Administrator',
            'department': 'IT Services',
            'email': 'admin@university.edu',
          },
        };

        return CustomResponse(
          status: professors.containsKey(username),
          data: professors[username] ?? {},
        );
      },
    );
  }

  // Get classroom mapping for MAC addresses
  Future<CustomResponse<Map<String, String>>> getClassroomMapping() {
    return Future.delayed(
      Duration.zero,
      () => CustomResponse(
        status: true,
        data: {
          // ESP32 MAC Address -> Classroom ID mapping
          // TODO: Replace with your real ESP32 MAC addresses
          "24:6F:28:7C:94:FE": "classroom_a",
          // PLACEHOLDER - Replace with real MAC
          //"24:6F:28:DD:EE:FF": "classroom_b",
          // PLACEHOLDER - Replace with real MAC
          //"30:AE:A4:11:22:33": "classroom_c",
          // PLACEHOLDER - Replace with real MAC
          // Example of what it should look like with real MAC addresses:
          // "24:6F:28:12:34:56": "classroom_a", // Your real ESP32 in Room A-101
          // "30:AE:A4:78:9A:BC": "classroom_b", // Your real ESP32 in Room B-205
          // Smart Switch devices (for backward compatibility)
          "80:F5:B5:69:B8:64": "lab_room_1",
          "C4:19:D1:06:C8:B9": "lab_room_2",
        },
      ),
    );
  }

  // Helper method to get all classrooms info
  Future<CustomResponse<Map<String, dynamic>>> getClassroomsInfo() {
    return Future.delayed(
      Duration.zero,
      () => CustomResponse(
        status: true,
        data: {
          "classroom_a": {
            "name": "Room A-101",
            "building": "Computer Science Building",
            "capacity": 50,
            "hasProjector": true,
            "hasAC": true,
            "hasWhiteboard": true,
            "espMacAddress": "24:6F:28:7C:94:FE",
            "isActive": true
          }
          /*,"classroom_b": {
            "name": "Room B-205",
            "building": "Mathematics Building",
            "capacity": 40,
            "hasProjector": true,
            "hasAC": false,
            "hasWhiteboard": true,
            "espMacAddress": "24:6F:28:DD:EE:FF", // TODO: Replace with real MAC
            "isActive": true
          },
          "classroom_c": {
            "name": "Room C-301",
            "building": "Physics Building",
            "capacity": 35,
            "hasProjector": false,
            "hasAC": true,
            "hasWhiteboard": false,
            "espMacAddress": "30:AE:A4:11:22:33", // TODO: Replace with real MAC
            "isActive": true
          }*/
        },
      ),
    );
  }
}
