import 'package:ble/src/models/custom_response.dart';

abstract class ServiceRepository {
  Future<CustomResponse<String>> login(String user, String password);
  Future<CustomResponse<List<String>>> getKnownDeviceUuid();
}
