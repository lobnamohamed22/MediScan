import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  int _rewardPoints = 0;
  List<dynamic> _transactions = [];
  String _rewardLevel = 'Bronze';

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final walletRes = await ApiService.getWallet();
      final txRes = await ApiService.getWalletTransactions();

      if (mounted) {
        if (walletRes['success'] == true && txRes['success'] == true) {
          setState(() {
            _rewardPoints = int.tryParse(walletRes['data']['reward_points'].toString()) ?? 0;
            _rewardLevel = walletRes['data']['reward_level']?.toString() ?? 'Bronze';
            _transactions = txRes['data'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = walletRes['message'] ?? txRes['message'] ?? 'Failed to load wallet data';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred while loading wallet';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet & Rewards'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchWalletData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchWalletData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== WALLET BALANCE CARD =====
                        _buildWalletCard(),
                        const SizedBox(height: 24),
                        // ===== CONVERSION NOTICE =====
                        _buildNoticeBox(),
                        const SizedBox(height: 28),
                        // ===== TRANSACTION LOGS =====
                        Text(
                          'Transaction History',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildTransactionsList(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildWalletCard() {
    Color levelColor;
    String nextLevelName = '';
    int nextLevelPoints = 0;

    switch (_rewardLevel.toLowerCase()) {
      case 'platinum':
        levelColor = const Color(0xFFE5E5E5); // Platinum
        break;
      case 'gold':
        levelColor = const Color(0xFFFFD700); // Gold
        nextLevelName = 'Platinum';
        nextLevelPoints = 1501;
        break;
      case 'silver':
        levelColor = const Color(0xFFC0C0C0); // Silver
        nextLevelName = 'Gold';
        nextLevelPoints = 501;
        break;
      default:
        levelColor = const Color(0xFFCD7F32); // Bronze
        nextLevelName = 'Silver';
        nextLevelPoints = 101;
    }

    double progress = 1.0;
    if (nextLevelName.isNotEmpty) {
      int prevThreshold = 0;
      if (_rewardLevel.toLowerCase() == 'silver') prevThreshold = 100;
      if (_rewardLevel.toLowerCase() == 'gold') prevThreshold = 500;
      progress = (_rewardPoints - prevThreshold) / (nextLevelPoints - prevThreshold);
      if (progress < 0.0) progress = 0.0;
      if (progress > 1.0) progress = 1.0;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1F4068), Color(0xFF162447)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MediScan Loyalty Club',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: levelColor, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.military_tech, color: levelColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      _rewardLevel.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            '$_rewardPoints Points',
            style: GoogleFonts.poppins(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          if (nextLevelName.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${nextLevelPoints - _rewardPoints} points to unlock $nextLevelName level',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ] else ...[
            Text(
              'You have reached Platinum, the highest level!',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: Colors.white60,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticeBox() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to Earn Points',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              _buildEarnRow(Icons.shopping_bag_outlined, 'Purchasing & Reserving', 'Earn points when purchasing or reserving medicines.'),
              const Divider(height: 20),
              _buildEarnRow(Icons.share_outlined, 'Referring & Sharing', 'Earn bonus points when sharing the app or referring friends.'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _shareAndEarn,
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text('Share App & Get 50 Points', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEarnRow(IconData icon, String title, String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _shareAndEarn() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.shareApp();
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thank you for sharing! +50 Loyalty Points added to your account.'),
              backgroundColor: Colors.green,
            ),
          );
          _fetchWalletData();
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to share app.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error sharing application.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTransactionsList() {
    final filteredTransactions = _transactions.where((tx) {
      final desc = (tx['description'] ?? '').toString().toLowerCase();
      return !desc.contains('delivery') && !desc.contains('motorcycle') && !desc.contains('route');
    }).toList();

    if (filteredTransactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              Icon(Icons.history_toggle_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                'No transactions recorded yet',
                style: GoogleFonts.roboto(color: Colors.grey, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredTransactions.length,
      itemBuilder: (context, index) {
        final tx = filteredTransactions[index];
        final type = tx['type'] ?? 'earn';
        final points = tx['points'] ?? 0;
        final desc = tx['description'] ?? 'Points transaction';
        final isEarn = type == 'earn' || points > 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isEarn
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              child: Icon(
                isEarn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                color: isEarn ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              desc,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              tx['created_at'] != null
                  ? tx['created_at'].toString().split('T')[0]
                  : '',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            trailing: Text(
              '${isEarn ? "+" : ""}$points Points',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: isEarn ? Colors.green : Colors.red,
                fontSize: 15,
              ),
            ),
          ),
        );
      },
    );
  }
}
