import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboarding_screen.dart';
import 'terms_conditions_screen.dart';
import 'privacy_policy_screen.dart';
import 'faq_screen.dart';
import 'about_us_screen.dart';
import 'contact_us_screen.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _selectedLanguage = 'English';
  bool _savePrescriptionHistory = true;
  bool _autoScanEnabled = true;

  final List<String> _languages = ['English', 'Arabic', 'French', 'Spanish'];

  @override
  void initState() {
    super.initState();
    _loadThemeValue();
  }

  Future<void> _loadThemeValue() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool('dark_mode') ?? false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() => _darkMode = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    if (!mounted) return;
    MediScanApp.of(context).changeTheme(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header('Account Settings'),
            _item(Icons.person, 'Profile', 'Update your information', () {
              Navigator.pushNamed(context, '/personal-info');
            }),
            _item(Icons.people, 'Family Members', 'Manage your family members list', () {
              Navigator.pushNamed(context, '/family-members');
            }),
            const SizedBox(height: 24),
            _header('App Preferences'),
            SwitchListTile(
              value: _notificationsEnabled,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
              title: const Text('Enable Notifications'),
              secondary: const Icon(Icons.notifications),
            ),
            SwitchListTile(
              value: _darkMode,
              onChanged: _toggleDarkMode,
              title: const Text('Dark Mode'),
              secondary: const Icon(Icons.dark_mode),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('Language'),
              subtitle: Text(_selectedLanguage),
              trailing: DropdownButton<String>(
                value: _selectedLanguage,
                onChanged: (v) => setState(() => _selectedLanguage = v!),
                items: _languages
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
              ),
            ),
            const SizedBox(height: 24),
            _header('Privacy & Data'),
            SwitchListTile(
              value: _savePrescriptionHistory,
              onChanged: (v) => setState(() => _savePrescriptionHistory = v),
              title: const Text('Save History'),
              secondary: const Icon(Icons.history),
            ),
            SwitchListTile(
              value: _autoScanEnabled,
              onChanged: (v) => setState(() => _autoScanEnabled = v),
              title: const Text('Auto Scan Enhancement'),
              secondary: const Icon(Icons.auto_awesome),
            ),
            _item(Icons.security, 'Privacy Policy', 'View policy', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              );
            }),
            _item(Icons.description, 'Terms & Conditions', 'View terms', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TermsConditionsScreen(),
                ),
              );
            }),
            const SizedBox(height: 24),
            _header('Support'),
            _item(Icons.menu_book, 'App Guide', 'View onboarding', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(),
                ),
              );
            }),
            _item(Icons.help_outline, 'FAQ', 'Common questions', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FAQScreen(),
                ),
              );
            }),
            _item(Icons.contact_phone, 'Contact Us', 'Reach support', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ContactUsScreen(),
                ),
              );
            }),
            _item(Icons.feedback, 'Send Feedback', 'Email us', _sendFeedback),
            _item(Icons.star, 'Rate App', 'Open store', _rateApp),
            const SizedBox(height: 24),
            _header('About'),
            _item(Icons.info_outline, 'About Us', 'About the app', () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AboutUsScreen(),
                ),
              );
            }),
            const ListTile(
              leading: Icon(Icons.info),
              title: Text('App Version'),
              subtitle: Text('1.0.0'),
            ),
            _item(Icons.code, 'Licenses', 'Open source', _showLicensesDialog),
            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: _logoutDialog,
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _deleteDialog,
                child: const Text(
                  'Delete Account',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      );

  Widget _item(IconData i, String t, String s, VoidCallback tap) {
    return ListTile(
      leading: Icon(i),
      title: Text(t),
      subtitle: Text(s),
      trailing: const Icon(Icons.chevron_right),
      onTap: tap,
    );
  }

  Future<void> _launchURL(String url) async {
    await launchUrl(Uri.parse(url));
  }

  void _sendFeedback() {
    launchUrl(Uri(
      scheme: 'mailto',
      path: 'feedback@mediscan.com',
      queryParameters: {'subject': 'MediScan Feedback'},
    ));
  }

  void _rateApp() {
    _launchURL(
        'https://play.google.com/store/apps/details?id=com.mediscan.app');
  }

  void _showLicensesDialog() {
    showLicensePage(
      context: context,
      applicationName: 'MediScan',
      applicationVersion: '1.0.0',
    );
  }

  void _logoutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Confirm logout'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              },
              child: const Text('Logout')),
        ],
      ),
    );
  }

  void _deleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Permanent action'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Delete')),
        ],
      ),
    );
  }
}
