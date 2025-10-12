import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final _dbRef = FirebaseDatabase.instance.ref().child('users');
  static const _authKey = 'is_authenticated';
  static const _professorIdKey = 'professor_id';
  static const _professorNameKey = 'professor_name';
  static const _usernameKey = 'username';

  Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
    await prefs.remove(_professorIdKey);
    await prefs.remove(_professorNameKey);
    await prefs.remove(_usernameKey);
  }

  Future<void> persistToken(String username,
      [String? professorId, String? professorName]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_authKey, true);
    await prefs.setString(_usernameKey, username);
    if (professorId != null) {
      await prefs.setString(_professorIdKey, professorId);
    }
    if (professorName != null) {
      await prefs.setString(_professorNameKey, professorName);
    }
  }

  Future<bool> hasToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_authKey) ?? false;
  }

  Future<String?> getProfessorId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_professorIdKey);
  }

  Future<String?> getProfessorName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_professorNameKey);
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  Future<bool> login(String username, String password) async {
    final DataSnapshot snapshot = await _dbRef.child(username).get();
    if (snapshot.exists) {
      final data =
          Map<String, dynamic>.from(snapshot.value as Map<dynamic, dynamic>);
      if (data['password'] == password) {
        // Store professor information if available
        final professorId = data['professorId'] as String?;
        final professorName = data['name'] as String?;
        await persistToken(username, professorId, professorName);
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

  // Get full professor profile
  Future<Map<String, dynamic>?> getProfessorProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString(_usernameKey);
    final professorId = prefs.getString(_professorIdKey);
    final professorName = prefs.getString(_professorNameKey);

    if (username != null) {
      return {
        'username': username,
        'professorId': professorId,
        'professorName': professorName,
      };
    }
    return null;
  }
}
