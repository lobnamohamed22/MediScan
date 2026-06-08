import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mediscan/l10n/app_localizations.dart';

import 'screens/welcome_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/start_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/home_screen.dart';

import 'screens/prescription_scan_screen.dart';
import 'screens/prescription_history_screen.dart';

import 'screens/pharmacy_search_screen.dart';
import 'screens/medicine_search_screen.dart';

import 'screens/order_delivery_screen.dart';
import 'screens/order_tracking_screen.dart';
import 'screens/order_history_screen.dart';
import 'screens/order_details_screen.dart';

import 'screens/profile_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/personal_info_screen.dart';
import 'screens/family_members_screen.dart';
import 'screens/wallet_screen.dart';

import 'screens/chatbot_screen.dart';
import 'screens/notifications_screen.dart';

import 'screens/settings_screen.dart';
import 'screens/terms_conditions_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/about_us_screen.dart';
import 'screens/contact_us_screen.dart';

import 'screens/admin_dashboard_screen.dart';
import 'screens/delivery_dashboard_screen.dart';
import 'screens/pharmacy_dashboard_screen.dart';
import 'screens/pharmacy_incoming_orders_screen.dart';
import 'screens/pharmacy_inventory_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MediScanApp());
}

class MediScanApp extends StatefulWidget {
  const MediScanApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ignore: library_private_types_in_public_api
  static _MediScanAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_MediScanAppState>()!;

  @override
  State<MediScanApp> createState() => _MediScanAppState();
}

class _MediScanAppState extends State<MediScanApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _copySampleImage();
  }

  Future<void> _copySampleImage() async {
    try {
      final file = File('/storage/emulated/0/Download/prescription.jpg');

      if (!await file.exists()) {
        final byteData = await rootBundle.load(
          'assets/images/prescription.jpg',
        );

        await file.writeAsBytes(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        );
      }
    } catch (e) {
      // Failed to copy sample image
    }
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    final isDark = prefs.getBool('dark_mode') ?? false;

    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> changeTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('dark_mode', isDark);

    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2D5A7E);

    return MaterialApp(
      navigatorKey: MediScanApp.navigatorKey,

      themeMode: _themeMode,

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('fr'),
      ],

      localeResolutionCallback: (locale, supportedLocales) {
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale?.languageCode) {
            return supportedLocale;
          }
        }

        return const Locale('en');
      },

      title: 'MediScan',
      debugShowCheckedModeBanner: false,

      // ================= LIGHT THEME =================

      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        fontFamily: 'Poppins',
        colorScheme: const ColorScheme.light(
          primary: primaryBlue,
          secondary: primaryBlue,
          surface: Colors.white,
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          centerTitle: true,
          elevation: 2,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // ================= DARK THEME =================

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        fontFamily: 'Poppins',
        colorScheme: const ColorScheme.dark(
          primary: primaryBlue,
          secondary: primaryBlue,
          surface: Color(0xFF1E1E1E),
          onPrimary: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          centerTitle: true,
          elevation: 2,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          hintStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
        ),
      ),

      initialRoute: '/start',

      routes: {
        '/': (context) => const StartScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/start': (context) => const StartScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const HomeScreen(),
        '/scan': (context) => const PrescriptionScanScreen(),
        '/history': (context) => const PrescriptionHistoryScreen(),
        '/pharmacy': (context) => const PharmacySearchScreen(),
        '/medicine': (context) => const MedicineSearchScreen(),
        '/order': (context) => const OrderDeliveryScreen(),
        '/order-history': (context) => const OrderHistoryScreen(),
        '/order-tracking': (context) => const OrderTrackingScreen(
              orderId: 'ORD-1001',
              pharmacyName: 'Al-Salam Pharmacy',
              medicines: ['Amoxicillin', 'Paracetamol'],
              status: 'confirmed',
            ),
        '/order-details': (context) => const OrderDetailsScreen(
              orderId: 'ORD-1001',
              pharmacy: 'Al-Salam Pharmacy',
              date: '2026-01-01',
              status: 'confirmed',
              medicines: ['Amoxicillin'],
              total: 100,
            ),
        '/profile': (context) => const ProfileScreen(),
        '/edit-profile': (context) => const EditProfileScreen(),
        '/personal-info': (context) => const PersonalInfoScreen(),
        '/family-members': (context) => const FamilyMembersScreen(),
        '/wallet': (context) => const WalletScreen(),
        '/chatbot': (context) => const ChatbotScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/terms': (context) => const TermsConditionsScreen(),
        '/privacy': (context) => const PrivacyPolicyScreen(),
        '/faq': (context) => const FAQScreen(),
        '/about': (context) => const AboutUsScreen(),
        '/contact': (context) => const ContactUsScreen(),
        '/admin-dashboard': (context) => const AdminDashboardScreen(),
        '/delivery-dashboard': (context) => const DeliveryDashboardScreen(),
        '/pharmacy-dashboard': (context) => const PharmacyDashboardScreen(),
        '/pharmacy-orders': (context) => const PharmacyIncomingOrdersScreen(),
        '/pharmacy-inventory': (context) => const PharmacyInventoryScreen(),
      },
    );
  }
}
