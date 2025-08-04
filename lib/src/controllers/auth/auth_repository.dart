import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final _dbRef = FirebaseDatabase.instance.ref().child('users');
  static const _authKey = 'is_authenticated';

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
  }

  Future<void> persistToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, true);
  }

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }

  Future<bool> login(String username, String password) async {
    final DataSnapshot snapshot = await _dbRef.child(username).get();
    if (snapshot.exists) {
      final data =
          Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      if (data['password'] == password) {
        await persistToken();
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  }

  Future<void> logout() async {
    await deleteToken();
  }
}
