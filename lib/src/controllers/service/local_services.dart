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
          "80:F5:B5:69:B8:64",
          "C4:19:D1:06:C8:B9",
        ],
      ),
    );
  }

  @override
  Future<CustomResponse<String>> login(String user, String password) {
    return Future.delayed(
      Duration(seconds: 2),
      () => CustomResponse(
        status: (user == 'admin' && password == 'admin'),
        data: 'mock_token',
      ),
    );
  }
}
