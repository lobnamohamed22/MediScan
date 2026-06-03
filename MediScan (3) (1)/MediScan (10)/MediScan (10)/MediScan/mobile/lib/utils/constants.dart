import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'MediScan';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Digital Prescription Management System';

  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF64B5F6);
  static const Color accentColor = Color(0xFFFF9800);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFF44336);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF2196F3);

  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);

  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFFF5F5F5);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFFEEEEEE);

  static const double defaultPadding = 16.0;
  static const double defaultMargin = 16.0;
  static const double defaultRadius = 12.0;
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double inputRadius = 12.0;

  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration snackbarDuration = Duration(seconds: 3);

  static const String apiBaseUrl = 'https://api.mediscan.com/v1';
  static const String prescriptionsEndpoint = '/prescriptions';
  static const String medicinesEndpoint = '/medicines';
  static const String pharmaciesEndpoint = '/pharmacies';
  static const String usersEndpoint = '/users';
  static const String ordersEndpoint = '/orders';
  static const String authEndpoint = '/auth';

  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String themeModeKey = 'theme_mode';
  static const String languageKey = 'app_language';

  static const List<String> medicineTypes = [
    'Antibiotic',
    'Pain Reliever',
    'Antihistamine',
    'Antidepressant',
    'Antiviral',
    'Antifungal',
    'Supplement',
    'Vitamin',
    'NSAID',
    'Steroid',
    'PPI',
    'Diuretic',
    'Bronchodilator',
    'Anticoagulant',
    'Antidiabetic',
  ];

  static const List<String> prescriptionStatuses = [
    'Active',
    'Completed',
    'Expired',
    'Cancelled',
    'Pending',
  ];

  static const Map<String, String> statusColors = {
    'Active': '#4CAF50',
    'Completed': '#2196F3',
    'Expired': '#9E9E9E',
    'Cancelled': '#F44336',
    'Pending': '#FF9800',
  };

  static const List<String> deliveryOptions = [
    'Standard Delivery',
    'Express Delivery',
    'Pharmacy Pickup',
  ];

  static const List<String> paymentMethods = [
    'Credit/Debit Card',
    'Cash on Delivery',
    'Digital Wallet',
    'Mobile Payment',
  ];
}
