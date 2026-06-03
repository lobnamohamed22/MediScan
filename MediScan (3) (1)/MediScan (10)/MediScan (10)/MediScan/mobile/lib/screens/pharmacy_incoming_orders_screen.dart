import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class PharmacyIncomingOrdersScreen extends StatefulWidget {
  const PharmacyIncomingOrdersScreen({super.key});

  @override
  State<PharmacyIncomingOrdersScreen> createState() => _PharmacyIncomingOrdersScreenState();
}

class _PharmacyIncomingOrdersScreenState extends State<PharmacyIncomingOrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    // Auto-refresh incoming orders feed every 8 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) => _fetchOrders(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOrders({bool silent = false}) async {
    try {
      final response = await ApiService.getPharmacyIncomingOrders();
      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _orders = response['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading pharmacy incoming orders: $e");
      if (!silent && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.updateOrderStatus(orderId, newStatus);
      if (result['success'] == true) {
        messenger.showSnackBar(
          SnackBar(content: Text('Order status updated successfully to $newStatus')),
        );
        _fetchOrders();
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to update order status')),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error communicating with server')),
      );
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber[700]!;
      case 'preparing':
      case 'assigned':
        return Colors.blue;
      case 'ready':
        return Colors.green;
      case 'picked_up':
      case 'in_transit':
        return Colors.orange;
      case 'delivered':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Orders'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchOrders(),
          ),
        ],
      ),
      body: _isLoading && _orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _fetchOrders(),
              child: _orders.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        final order = _orders[index];
                        return _buildOrderCard(order);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 85, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No Incoming Orders Yet',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              'Any new prescriptions and catalog orders\nwill appear here in real-time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status']?.toString() ?? 'assigned';
    final orderId = order['order_id']?.toString() ?? 'ORD-0000';
    final customerName = order['customer_name']?.toString() ?? 'Patient';
    final customerPhone = order['customer_phone']?.toString() ?? 'Unknown Phone';
    final totalPrice = (order['total_price'] as num?)?.toDouble() ?? 0.0;
    final quantity = order['quantity'] as int? ?? 0;
    final medicinesRaw = order['medicines'] ?? [];
    
    List<String> meds = [];
    if (medicinesRaw is List) {
      meds = medicinesRaw.map((e) => e.toString()).toList();
    }

    final createdAtStr = order['created_at'] != null 
        ? order['created_at'].toString().replaceAll('T', ' ').substring(0, 16) 
        : 'Recently';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID: #${orderId.substring(0, 8)}',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        createdAtStr,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Patient details
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  customerName,
                  style: GoogleFonts.roboto(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                const Icon(Icons.phone, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  customerPhone,
                  style: GoogleFonts.roboto(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Medicines List
            Text(
              'Medicines Summary:',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[400]),
            ),
            const SizedBox(height: 6),
            meds.isEmpty
                ? const Text(
                    'No catalog items described - check prescription attached.',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: meds.map((m) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.medication, size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                m,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
            const SizedBox(height: 12),

            // Price Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Items: $quantity',
                  style: const TextStyle(color: Colors.grey),
                ),
                Text(
                  '${totalPrice.toStringAsFixed(2)} EGP',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
            
            // Action Buttons
            if (['assigned', 'pending'].contains(status.toLowerCase())) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () => _updateStatus(orderId, 'rejected'),
                      child: const Text('Reject', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      onPressed: () => _updateStatus(orderId, 'preparing'),
                      child: const Text('Accept & Prepare'),
                    ),
                  ),
                ],
              ),
            ] else if (status.toLowerCase() == 'preparing') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  onPressed: () => _updateStatus(orderId, 'ready'),
                  child: const Text('Mark as Ready for Pickup'),
                ),
              ),
            ] else if (status.toLowerCase() == 'ready') ...[
              const SizedBox(height: 16),
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty, size: 16, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      'Ready - Waiting for Delivery Driver Pickup',
                      style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'In delivery processing (status: ${status.replaceAll('_', ' ')})',
                  style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
