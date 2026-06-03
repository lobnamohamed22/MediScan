import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class AuthService {
  // Base URL for the Flask backend. 
  static String get baseUrl => Config.authBaseUrl;

  /// Logs in the user and stores the JWT token securely.
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        return {'success': false, 'message': 'Invalid server response'};
      }

      final hasToken =
          data['token'] != null && data['token'].toString().isNotEmpty;

      if (data['success'] == true || hasToken) {
        if (hasToken) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['token']);
          if (data['user'] != null && data['user']['role'] != null) {
            await prefs.setString('user_role', data['user']['role']);
          }
        }
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  /// Registers a new user and stores the JWT token securely.
  Future<Map<String, dynamic>> register(
      String name, String email, String password, String phone, String role) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'phone': phone,
              'role': role,
            }),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        return {'success': false, 'message': 'Invalid server response'};
      }

      final hasToken =
          data['token'] != null && data['token'].toString().isNotEmpty;

      if (data['success'] == true || hasToken) {
        if (hasToken) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['token']);
          if (data['user'] != null && data['user']['role'] != null) {
            await prefs.setString('user_role', data['user']['role']);
          }
        }
        return {'success': true, 'data': data};
      }
      return {
        'success': false,
        'message': data['message'] ?? 'Registration failed'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  /// Retrieves the stored JWT token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// Logs out the user by deleting the stored token
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
  }

  /// Retrieves the stored user role
  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }
}
