//import 'package:flutter/material.dart';
import 'auth_service.dart';

/// Exception thrown when authentication is required but user is not authenticated
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);

  @override
  String toString() => message;
}

/// AuthGuard is a navigation helper that checks for a valid token
/// and redirects to login if necessary
class AuthGuard {
  static final AuthService _authService = AuthService();

  /// Check if user is authenticated (has a valid token)
  static Future<bool> isAuthenticated() async {
    try {
      final token = await _authService.getToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the token, throwing UnauthorizedException if not found
  static Future<String> getAuthenticatedToken() async {
    final token = await _authService.getToken();
    if (token == null || token.isEmpty) {
      throw UnauthorizedException(
        'Authentication required. Please login again.',
      );
    }
    return token;
  }

  /// Logout the user
  static Future<void> logout() async {
    await _authService.logout();
  }
}
