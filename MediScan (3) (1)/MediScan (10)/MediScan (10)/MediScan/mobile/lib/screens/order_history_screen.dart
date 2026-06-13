import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'order_tracking_screen.dart';
import 'order_details_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<OrderItem> _orders = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await ApiService.getOrders();
      debugPrint('[OrderHistoryScreen] ApiService.getOrders result: $result');

      if (!mounted) return;

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _orders = data.map((json) => OrderItem.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load orders';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('[OrderHistoryScreen] Error loading orders: $e');
      debugPrint('[OrderHistoryScreen] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Unexpected error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'ready':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(_errorMessage,
                      style: const TextStyle(color: Colors.red)))
              : _orders.isEmpty
                  ? const Center(child: Text('No orders yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, i) {
                        final order = _orders[i];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                /// Header
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Order #${order.id}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(order.status)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        order.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _statusColor(order.status),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),
                                Text('Pharmacy: ${order.pharmacy}'),
                                Text('Date: ${order.date}'),
                                Text(
                                    'Total: ${order.total.toStringAsFixed(2)} EGP'),

                                const SizedBox(height: 10),

                                /// Medicines
                                Wrap(
                                  spacing: 6,
                                  children: order.medicines
                                      .map((m) => Chip(label: Text(m)))
                                      .toList(),
                                ),

                                const SizedBox(height: 12),

                                /// View Details
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.receipt_long),
                                    label: const Text('View Details'),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => OrderDetailsScreen(
                                            orderId: order.id,
                                            pharmacy: order.pharmacy,
                                            pharmacyId: order.pharmacyId,
                                            date: order.date,
                                            status: order.status,
                                            medicines: order.medicines,
                                            total: order.total,
                                          ),
                                        ),
                                      );
                                      _loadOrders();
                                    },
                                  ),
                                ),

                                const SizedBox(height: 8),

                                /// Track Order
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.local_shipping),
                                    label: const Text('Track Order'),
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => OrderTrackingScreen(
                                            orderId: order.id,
                                            pharmacyName: order.pharmacy,
                                            medicines: order.medicines,
                                            status: order.status,
                                          ),
                                        ),
                                      );
                                      _loadOrders();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class OrderItem {
  final String id;
  final String pharmacy;
  final String? pharmacyId;
  final String date;
  final String status;
  final List<String> medicines;
  final double total;

  OrderItem({
    required this.id,
    required this.pharmacy,
    this.pharmacyId,
    required this.date,
    required this.status,
    required this.medicines,
    required this.total,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    List<String> meds = [];
    if (json['medicines'] != null) {
      if (json['medicines'] is String) {
        meds = (json['medicines'] as String)
            .split('\n')
            .where((m) => m.trim().isNotEmpty)
            .toList();
      } else if (json['medicines'] is List) {
        meds = List<String>.from(json['medicines']);
      }
    }

    return OrderItem(
      id: json['order_id']?.toString() ?? json['id']?.toString() ?? '',
      pharmacy: json['pharmacy_name'] ?? json['pharmacy'] ?? 'Unknown Pharmacy',
      pharmacyId: json['pharmacy_id']?.toString(),
      date: json['created_at']?.toString().split('T').first ?? '',
      status: json['status'] ?? 'pending',
      medicines: meds,
      total: double.tryParse(json['total_price']?.toString() ?? '0') ?? 0.0,
    );
  }
}
