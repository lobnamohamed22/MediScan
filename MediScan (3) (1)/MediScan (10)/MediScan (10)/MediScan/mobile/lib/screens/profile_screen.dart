import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config.dart' as mediscan_config;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    try {
      final data = await ApiService.getProfile();

      setState(() {
        // If the API wraps the response in a 'data' key, extract it. Otherwise use the raw data.
        userData = data.containsKey('data') ? data['data'] : data;
      });
    } catch (e) {
      debugPrint("Error loading profile: $e");
      // Prevent infinite loading by setting an empty map
      setState(() {
        userData = {};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updatedData = await Navigator.pushNamed(
                context,
                '/edit-profile',
                arguments: userData,
              );

              if (updatedData != null) {
                loadData();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ===== HEADER =====
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[800]!, Colors.blue[600]!],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: userData?['profile_image'] != null
                        ? NetworkImage(
                            userData!['profile_image'].toString().startsWith('http')
                                ? userData!['profile_image'].toString()
                                : '${mediscan_config.Config.baseUrl}/${userData!['profile_image']}'
                          )
                        : null,
                    child: userData?['profile_image'] == null
                        ? const Icon(Icons.person, size: 50, color: Colors.blue)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    userData?['name'] ?? 'No Name',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    userData?['role'] ?? 'User',
                    style: GoogleFonts.roboto(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () async {
                      final updatedData = await Navigator.pushNamed(
                        context,
                        '/edit-profile',
                        arguments: userData,
                      );

                      if (updatedData != null) {
                        loadData();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text(
                      'Edit Profile',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatItem(
                          userData?['prescriptions_count']?.toString() ?? '0',
                          'Prescriptions'),
                      const SizedBox(width: 30),
                      _buildStatItem(
                          userData?['pharmacies_count']?.toString() ?? '0',
                          'Pharmacies'),
                      const SizedBox(width: 30),
                      _buildStatItem(userData?['accuracy']?.toString() ?? '0%',
                          'Accuracy'),
                    ],
                  ),
                ],
              ),
            ),

            // ===== BODY =====
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildProfileSection(
                    title: 'Personal Information',
                    icon: Icons.person_outline,
                    children: [
                      _buildInfoItem(
                        'Email',
                        (userData?['email'] == null ||
                                userData!['email'].toString().trim().isEmpty ||
                                userData!['email'].toString() == 'No Data')
                            ? '-'
                            : userData!['email'].toString(),
                      ),
                      _buildInfoItem(
                        'Phone',
                        (userData?['phone'] == null ||
                                userData!['phone'].toString().trim().isEmpty ||
                                userData!['phone'].toString() == 'No Data')
                            ? '-'
                            : userData!['phone'].toString(),
                      ),
                      _buildInfoItem(
                        'Date of Birth',
                        (userData?['date_of_birth'] == null ||
                                userData!['date_of_birth']
                                    .toString()
                                    .trim()
                                    .isEmpty ||
                                userData!['date_of_birth'].toString() ==
                                    'No Data')
                            ? '-'
                            : userData!['date_of_birth'].toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildProfileSection(
                    title: 'Account',
                    icon: Icons.manage_accounts,
                    children: [
                      _buildSettingsItem(
                        icon: Icons.settings,
                        title: 'App Settings',
                        onTap: () async {
                          await Navigator.pushNamed(context, '/settings');
                          loadData();
                        },
                      ),
                      _buildSettingsItem(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Wallet & Rewards',
                        onTap: () => Navigator.pushNamed(context, '/wallet'),
                      ),
                      _buildSettingsItem(
                        icon: Icons.notifications,
                        title: 'Notifications',
                        onTap: () =>
                            Navigator.pushNamed(context, '/notifications'),
                      ),
                      _buildSettingsItem(
                        icon: Icons.lock,
                        title: 'Change Password',
                        onTap: () =>
                            Navigator.pushNamed(context, '/forgot-password'),
                      ),
                      _buildSettingsItem(
                        icon: Icons.support_agent,
                        title: 'Contact Us',
                        onTap: () => Navigator.pushNamed(context, '/contact'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Version 1.0.0',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== HELPERS =====

  static Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label,
            style: GoogleFonts.roboto(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  static Widget _buildProfileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 10),
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  static Widget _buildInfoItem(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: GoogleFonts.roboto(color: Colors.grey)),
          Text(v, style: GoogleFonts.roboto(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  static Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  static void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Delete the stored JWT token
              await AuthService().logout();

              // Clear the navigation stack and go to Welcome Screen
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                  context, '/welcome', (_) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
