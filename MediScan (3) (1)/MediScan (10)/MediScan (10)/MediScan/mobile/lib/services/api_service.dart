import 'dart:convert';
import '../main.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'auth_guard.dart';
import '../config.dart';

class ApiService {
  static String get baseUrl => Config.apiBaseUrl;

  static Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService().getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> _timedGet(String url) async {
    return await http
        .get(Uri.parse(url), headers: await _getHeaders())
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> _timedPost(String url, dynamic body) async {
    return await http
        .post(Uri.parse(url),
            headers: await _getHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> _timedPatch(String url, dynamic body) async {
    return await http
        .patch(Uri.parse(url),
            headers: await _getHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> _timedPut(String url, dynamic body) async {
    return await http
        .put(Uri.parse(url),
            headers: await _getHeaders(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
  }

  static Future<http.Response> _timedDelete(String url) async {
    return await http
        .delete(Uri.parse(url), headers: await _getHeaders())
        .timeout(const Duration(seconds: 15));
  }

  static Future<void> _validateAuthentication() async {
    try {
      await AuthGuard.getAuthenticatedToken();
    } catch (e) {
      debugPrint('[API] Authentication validation failed: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _handleResponseStatus(
    int statusCode,
    String responseBody,
  ) {
    if (statusCode == 401 || statusCode == 403) {
      debugPrint('[API] Unauthorized ($statusCode) - Redirecting to login');
      AuthService().logout(); // Clear token
      MediScanApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/login', (route) => false);
      return {
        'success': false,
        'message': 'Session expired. Please login again.',
        'requiresLogin': true,
      };
    }
    return {};
  }

// ================= PROFILE =================
  static Future<Map<String, dynamic>> getProfile() async {
    try {
      await _validateAuthentication();

      final response = await _timedGet('$baseUrl/users/profile');

      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }

      throw Exception("Failed to load profile");
    } catch (e) {
      return {'success': false, 'message': 'Error fetching profile'};
    }
  }

  static Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> data) async {
    try {
      await _validateAuthentication();

      final response = await _timedPatch('$baseUrl/users/profile', data);

      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }

      return {'success': false, 'message': 'Failed to update profile'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      await _validateAuthentication();
      final response = await _timedDelete('$baseUrl/users/account');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to delete account'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= MEDICINES =================
  static Future<Map<String, dynamic>> searchMedicines(String query) async {
    try {
      await _validateAuthentication();

      final response = await _timedGet('$baseUrl/medicines/search?q=$query');

      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }

      return {'success': false, 'message': 'Failed to search medicines'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= PRESCRIPTIONS =================
  static Future<Map<String, dynamic>> getPrescriptionHistory() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/prescriptions/history');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {
        'success': false,
        'message': 'Failed to fetch prescription history'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> verifyPrescription(
      String id, List<String> medicines) async {
    try {
      await _validateAuthentication();
      final response = await _timedPut(
          '$baseUrl/prescriptions/$id/verify', {'medicines': medicines});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to verify prescription'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= UPLOAD =================
  static Future<Map<String, dynamic>> uploadPrescription(
      List<int> bytes, String filename) async {
    try {
      await _validateAuthentication();

      final token = await AuthService().getToken();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/prescriptions/upload'),
      );

      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: filename),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      return {'success': false, 'message': 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= UPLOAD PROFILE IMAGE =================
  static Future<Map<String, dynamic>> uploadProfileImage(List<int> bytes, String filename) async {
    try {
      await _validateAuthentication();
      final token = await AuthService().getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/users/upload-image'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: filename),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= DELETE PROFILE IMAGE =================
  static Future<Map<String, dynamic>> deleteProfileImage() async {
    try {
      await _validateAuthentication();
      final response = await _timedDelete('$baseUrl/users/profile-image');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Network error'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= PHARMACY OWNER DASHBOARD & INVENTORY =================
  static Future<Map<String, dynamic>> getPharmacyIncomingOrders() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/orders/pharmacy/incoming');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to load pharmacy orders'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getPharmacyInventory() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/pharmacies/my-pharmacy/inventory');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to load inventory'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> updateInventoryItem(Map<String, dynamic> data) async {
    try {
      await _validateAuthentication();
      final response = await _timedPost('$baseUrl/pharmacies/my-pharmacy/inventory', data);
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to update inventory'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> deleteInventoryItem(String inventoryId) async {
    try {
      await _validateAuthentication();
      final response = await _timedDelete('$baseUrl/pharmacies/my-pharmacy/inventory/$inventoryId');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to remove from inventory'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= FAMILY MEMBERS =================
  static Future<Map<String, dynamic>> getFamilyMembers() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/users/family');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to load family members'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> addFamilyMember(Map<String, dynamic> data) async {
    try {
      await _validateAuthentication();
      final response = await _timedPost('$baseUrl/users/family', data);
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to add family member'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> updateFamilyMember(String memberId, Map<String, dynamic> data) async {
    try {
      await _validateAuthentication();
      final response = await _timedPut('$baseUrl/users/family/$memberId', data);
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to update family member'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> deleteFamilyMember(String memberId) async {
    try {
      await _validateAuthentication();
      final response = await _timedDelete('$baseUrl/users/family/$memberId');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to delete family member'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= PHARMACIES =================
  static Future<Map<String, dynamic>> searchPharmacies(String name,
      {double? lat, double? lng}) async {
    try {
      await _validateAuthentication();
      String url = '$baseUrl/pharmacies/search?name=$name';
      if (lat != null && lng != null) {
        url += '&lat=$lat&lng=$lng';
      }
      final response = await _timedGet(url);
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to search pharmacies'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getNearbyPharmacies(
      double lat, double lng,
      {String? medicine, double radius = 10}) async {
    try {
      await _validateAuthentication();
      String url =
          '$baseUrl/pharmacies/nearby?lat=$lat&lng=$lng&radius=$radius';
      if (medicine != null && medicine.isNotEmpty) {
        url += '&medicine=${Uri.encodeComponent(medicine)}';
      }
      final response = await _timedGet(url);
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to get nearby pharmacies'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getFallbackPharmacies() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/pharmacies/fallback');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to get fallback pharmacies'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getPharmacyInventoryById(String pharmacyId) async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/pharmacies/$pharmacyId/inventory');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to load pharmacy inventory'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> resolvePrices(List<String> names, {String? pharmacyId}) async {
    try {
      await _validateAuthentication();
      final response = await _timedPost('$baseUrl/medicines/resolve_prices', {
        'names': names,
        if (pharmacyId != null) 'pharmacy_id': pharmacyId,
      });
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to resolve prices'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= NOTIFICATIONS =================
  static Future<Map<String, dynamic>> getNotifications() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/notifications');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to fetch notifications'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> markNotificationAsRead(String id) async {
    try {
      await _validateAuthentication();
      final response = await _timedPatch('$baseUrl/notifications/$id/read', {});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {
        'success': false,
        'message': 'Failed to mark notification as read'
      };
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    try {
      await _validateAuthentication();
      final response = await _timedPatch('$baseUrl/notifications/read-all', {});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to mark all as read'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getUnreadNotificationsCount() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/notifications/unread-count');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to fetch unread count'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> deleteNotification(String id) async {
    try {
      await _validateAuthentication();
      final response = await _timedDelete('$baseUrl/notifications/$id');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to delete notification'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ================= ORDERS =================
  static Future<Map<String, dynamic>> getOrders() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/orders');

      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Failed to parse orders'};
        }
      }
      return {'success': false, 'message': 'Failed to fetch orders'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getDeliveryAssignedOrders() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/orders/delivery/assigned');

      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Failed to parse orders'};
        }
      }
      return {'success': false, 'message': 'Failed to fetch assigned orders'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    try {
      await _validateAuthentication();
      final response = await _timedPatch(
          '$baseUrl/orders/$orderId/status', {'status': status});

      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Failed to parse response'};
        }
      }
      return {'success': false, 'message': 'Failed to update order status'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= CHATBOT =================
  static Future<Map<String, dynamic>> sendChatMessage(String message) async {
    try {
      await _validateAuthentication();
      final response =
          await _timedPost('$baseUrl/chatbot/message', {'message': message});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to send message'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= DELIVERY TRACKING =================
  static Future<Map<String, dynamic>> getDeliveryTracking(
      String orderId) async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/orders/$orderId/tracking');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to fetch tracking data'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> updateDriverLocation(
      String orderId, double lat, double lng) async {
    try {
      await _validateAuthentication();
      final response = await _timedPatch(
          '$baseUrl/orders/$orderId/location', {'lat': lat, 'lng': lng});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to update location'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> simulateDelivery(String orderId, {double? customerLat, double? customerLng}) async {
    try {
      await _validateAuthentication();
      final response =
          await _timedPost('$baseUrl/orders/$orderId/simulate', {
            if (customerLat != null) 'customer_lat': customerLat,
            if (customerLng != null) 'customer_lng': customerLng,
          });
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to start simulation'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= ORDER CHAT =================
  static Future<Map<String, dynamic>> getOrderChat(String orderId) async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/orders/$orderId/chat');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to fetch chat messages'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> sendOrderMessage(
      String orderId, String message) async {
    try {
      await _validateAuthentication();
      final response = await _timedPost(
          '$baseUrl/orders/$orderId/chat', {'message': message});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 201) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to send message'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= CART =================
  static Future<Map<String, dynamic>> getCart() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/cart');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to fetch cart'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> addToCart(String medicineId,
      {int quantity = 1}) async {
    try {
      await _validateAuthentication();
      final response = await _timedPost('$baseUrl/cart/add',
          {'medicine_id': medicineId, 'quantity': quantity});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to add to cart'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> updateCartItem(
      String cartItemId, int quantity) async {
    try {
      await _validateAuthentication();
      final response = await _timedPut(
          '$baseUrl/cart/update/$cartItemId', {'quantity': quantity});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to update cart'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> removeCartItem(String cartItemId) async {
    try {
      await _validateAuthentication();
      final response = await _timedDelete('$baseUrl/cart/remove/$cartItemId');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to remove item'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> checkoutCart({int redeemPoints = 0}) async {
    try {
      await _validateAuthentication();
      final response = await _timedPost('$baseUrl/cart/checkout', {
        'redeem_points': redeemPoints,
      });
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to checkout cart'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getWallet() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/wallet');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to get wallet info'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getWalletTransactions() async {
    try {
      await _validateAuthentication();
      final response = await _timedGet('$baseUrl/wallet/transactions');
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to get transactions'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> shareApp() async {
    try {
      await _validateAuthentication();
      final response = await _timedPost('$baseUrl/wallet/share', {});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to share app'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  static Future<Map<String, dynamic>> getCheckoutPreview(int redeemPoints) async {
    try {
      await _validateAuthentication();
      final response = await _timedPost('$baseUrl/cart/checkout/preview', {
        'redeem_points': redeemPoints,
      });
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {'success': false, 'message': 'Failed to get checkout preview'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

// ================= CREATE ORDER =================
  static Future<Map<String, dynamic>> createOrder({
    required String pharmacyId,
    required int quantity,
    required double totalPrice,
  }) async {
    try {
      await _validateAuthentication();
      final response = await _timedPost('$baseUrl/orders/', {
        'pharmacy_id': pharmacyId,
        'quantity': quantity,
        'total_price': totalPrice,
      });
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 201) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to create order'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }

  // ================= REORDER =================
  static Future<Map<String, dynamic>> reorder(String orderId) async {
    try {
      await _validateAuthentication();
      final response = await _timedPost('$baseUrl/orders/$orderId/reorder', {});
      final handled = _handleResponseStatus(response.statusCode, response.body);
      if (handled.isNotEmpty) return handled;

      if (response.statusCode == 201) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          return {'success': false, 'message': 'Invalid server response'};
        }
      }
      return {'success': false, 'message': 'Failed to reorder'};
    } catch (e) {
      return {'success': false, 'message': 'Network error'};
    }
  }
}

