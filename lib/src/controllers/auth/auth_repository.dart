import 'package:firebase_database/firebase_database.dart';

class AuthRepository {
  final _dbRef = FirebaseDatabase.instance.ref().child('users');

  Future<void> deleteToken() async {}

  Future<void> persistToken(String token) async {}

  Future<String?> getToken() async => null;

  Future<bool> hasToken() async => false;

  Future<bool> login(String username, String password) async {
    final DataSnapshot snapshot = await _dbRef.child(username).get();
    if (snapshot.exists) {
      final data =
          Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      return data['password'] == password;
    } else {
      return false;
    }
  }

  Future<void> logout() async {}
}
