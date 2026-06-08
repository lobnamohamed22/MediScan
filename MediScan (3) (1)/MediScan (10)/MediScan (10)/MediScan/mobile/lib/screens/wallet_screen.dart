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
  double _walletBalance = 0.0;
  List<dynamic> _transactions = [];

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
            _walletBalance = double.tryParse(walletRes['data']['wallet_balance'].toString()) ?? 0.0;
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
                'MediScan Rewards',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Icon(
                Icons.stars_rounded,
                color: Colors.amber,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_rewardPoints pts',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Equivalent Discount Value',
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_walletBalance.toStringAsFixed(2)} EGP',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber[300],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoticeBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Conversion Rate: 10 Points = 1.00 EGP discount.\nPoints are earned automatically for purchases (1pt/10 EGP spent) and reservations (10pts/reservation).',
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black54,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    if (_transactions.isEmpty) {
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
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        final type = tx['type'] ?? 'earn';
        final points = tx['points'] ?? 0;
        final amount = double.tryParse(tx['amount'].toString()) ?? 0.0;
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
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isEarn ? "+" : ""}$points pts',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: isEarn ? Colors.green : Colors.red,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${isEarn ? "+" : "-"}${amount.toStringAsFixed(2)} EGP',
                  style: TextStyle(
                    fontSize: 11,
                    color: isEarn ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
