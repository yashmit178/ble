import 'package:ble/src/controllers/service/service_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  final storage = const FlutterSecureStorage();
  final ServiceRepository _serviceRepository;

  AuthRepository(this._serviceRepository);

  Future<void> deleteToken() async => await storage.delete(key: 'jwt_token');

  Future<void> persistToken(String token) async =>
      await storage.write(key: 'jwt_token', value: token);

  Future<String?> getToken() async => await storage.read(key: 'jwt_token');

  Future<bool> hasToken() async {
    String? value = await getToken();
    // TODO: check if token is still valid
    return (value != null) ? true : false;
  }

  Future<bool> login(String username, String password) async {
    final response = await _serviceRepository.login(username, password);
    if (response.status) {
      persistToken(response.data);
      return true;
    } else {
      return false;
    }
  }

  Future<void> logout() async {
    await deleteToken();
  }
}
