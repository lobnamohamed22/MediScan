import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import 'medicine_search_screen.dart';
import 'prescription_history_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'chatbot_screen.dart';
import 'pharmacy_search_screen.dart';
import 'prescription_scan_screen.dart';
import 'order_delivery_screen.dart';

import '../widgets/chatbot_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _notificationCount = 0;
  int _chatbotNotificationCount = 2;

  static final List<Widget> _pages = [
    const DashboardPage(),
    const MedicineSearchScreen(),
    const PrescriptionHistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fetchNotificationCount();
  }

  Future<void> _fetchNotificationCount() async {
    try {
      final result = await ApiService.getUnreadNotificationsCount();
      if (result['success'] == true && mounted) {
        final countData = result['data'];
        final count = countData is Map ? (countData['count'] as int? ?? 0) : 0;
        setState(() {
          _notificationCount = count;
        });
      } else {
        final fallbackResult = await ApiService.getNotifications();
        if (fallbackResult['success'] == true && mounted) {
          final List<dynamic> data = fallbackResult['data'] ?? [];
          final count = data
              .where((json) => json['read'] != true && json['is_read'] != true)
              .length;
          setState(() {
            _notificationCount = count;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching unread notification count: $e");
    }
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'MediScan',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2196F3),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF2196F3),
                  size: 28,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  ).then((result) {
                    if (result is int && mounted) {
                      setState(() {
                        _notificationCount = result;
                      });
                    }
                    Future.delayed(const Duration(milliseconds: 300), () {
                      _fetchNotificationCount();
                    });
                  });
                },
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 10,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _notificationCount > 9
                          ? '9+'
                          : _notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: ChatbotButton(
        notificationCount: _chatbotNotificationCount,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ChatbotScreen(),
            ),
          );
          setState(() {
            _chatbotNotificationCount = 0;
          });
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFF2196F3),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _recentPrescription;

  @override
  void initState() {
    super.initState();
    _fetchRecentPrescription();
  }

  Future<void> _fetchRecentPrescription() async {
    try {
      final response = await ApiService.getPrescriptionHistory();

      // Check if authentication is required
      if (response['requiresLogin'] == true) {
        if (mounted) {
          // Navigate to login
          Navigator.of(context)
              .pushNamedAndRemoveUntil('/login', (route) => false);
        }
        return;
      }

      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> data = response['data'];
        if (data.isNotEmpty) {
          if (mounted) {
            setState(() {
              _recentPrescription = data[0]; // Get the latest one
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      // Error fetching recent prescription
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchRecentPrescription,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Actions',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    context,
                    icon: Icons.camera_alt,
                    title: 'Scan Prescription',
                    subtitle: 'Upload & digitize',
                    color: const Color(0xFF2196F3),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrescriptionScanScreen(),
                        ),
                      ).then((_) => _fetchRecentPrescription());
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.local_pharmacy,
                    title: 'Find Pharmacy',
                    subtitle: 'Nearby locations',
                    color: const Color(0xFF4CAF50),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PharmacySearchScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.local_shipping,
                    title: 'Delivery',
                    subtitle: 'Track orders',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrderDeliveryScreen(),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.history,
                    title: 'Prescription History',
                    subtitle: 'View all',
                    color: Colors.deepPurple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const PrescriptionHistoryScreen(),
                        ),
                      ).then((_) => _fetchRecentPrescription());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Text(
                'Recent Prescriptions',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_recentPrescription != null)
                _buildRecentPrescriptionCard(
                  context: context,
                  id: _recentPrescription!['id'].toString(),
                  date: (_recentPrescription!['uploaded_at'] ?? _recentPrescription!['created_at']) != null
                      ? (_recentPrescription!['uploaded_at'] ?? _recentPrescription!['created_at'])
                          .toString()
                          .substring(0, 10)
                      : 'Unknown Date',
                  medications: _extractMeds(_recentPrescription!['medicines']),
                  status: _recentPrescription!['status'] ?? 'Unknown',
                  statusColor: ['processed', 'verified', 'delivered', 'filled', 'reserved'].contains(_recentPrescription!['status'])
                      ? Colors.green
                      : Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrescriptionHistoryScreen(),
                      ),
                    ).then((_) => _fetchRecentPrescription());
                  },
                )
              else
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                      child: Column(
                    children: [
                      Icon(Icons.history, color: Colors.grey[400], size: 40),
                      const SizedBox(height: 8),
                      Text("No recent prescriptions.",
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  )),
                )),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _extractMeds(dynamic medsData) {
    if (medsData == null) return [];
    if (medsData is List) {
      return List<String>.from(medsData.map((e) {
        if (e is Map) {
          return e['medicine_name']?.toString() ?? 'Unknown';
        }
        return e.toString();
      }));
    }
    if (medsData is String) {
      return medsData.split('\n').where((m) => m.trim().isNotEmpty).toList();
    }
    return [];
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.roboto(fontSize: 14)),
              Text(
                subtitle,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPrescriptionCard({
    required BuildContext context,
    required String id,
    required String date,
    required List<String> medications,
    required String status,
    required Color statusColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.description, color: statusColor),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prescription #$id',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      date,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (medications.isEmpty)
                      const Text("No medicines detected",
                          style: TextStyle(
                              fontStyle: FontStyle.italic, color: Colors.grey))
                    else
                      Wrap(
                        spacing: 6,
                        children: medications
                            .map((m) => Chip(label: Text(m)))
                            .toList(),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
