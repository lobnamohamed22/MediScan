import 'package:flutter/material.dart';
import 'cart_screen.dart';
import '../services/cart_service.dart';
import '../services/api_service.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String pharmacy;
  final String? pharmacyId;
  final String date;
  final String status;
  final List<String> medicines;
  final double total;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.pharmacy,
    this.pharmacyId,
    required this.date,
    required this.status,
    required this.medicines,
    required this.total,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isAddingToCart = false;
  bool _isReordering = false;
  List<Map<String, dynamic>> _resolvedMedicines = [];
  double _calculatedTotal = 0.0;
  bool _isLoadingPrices = true;

  String? get _resolvedPharmacyId => widget.pharmacyId ?? (widget.orderId.startsWith('RES-') ? widget.orderId.substring(4) : null);

  @override
  void initState() {
    super.initState();
    if ((widget.status == 'preview' || widget.status == 'pending') && _resolvedPharmacyId != null) {
      _fetchPharmacyInventory();
    } else {
      _fetchPrices();
    }
  }

  Future<void> _fetchPharmacyInventory() async {
    setState(() => _isLoadingPrices = true);
    try {
      final res = await ApiService.getPharmacyInventoryById(_resolvedPharmacyId!);
      if (res['success'] == true) {
        final List data = res['data'] ?? [];
        setState(() {
          _resolvedMedicines = data.map<Map<String, dynamic>>((item) {
            final String medName = item['medicine_name'] ?? '';
            int qty = 0;
            bool isInPassed = false;
            for (var m in widget.medicines) {
              String name = m;
              int mq = 1;
              if (m.contains(" x") && RegExp(r' x\d+$').hasMatch(m)) {
                final parts = m.split(RegExp(r' x(?=\d+$)'));
                if (parts.length == 2) {
                  name = parts[0];
                  mq = int.tryParse(parts[1]) ?? 1;
                }
              }
              if (name.toLowerCase().trim() == medName.toLowerCase().trim()) {
                qty = mq;
                isInPassed = true;
                break;
              }
            }

            return {
              'original_name': medName,
              'name': medName,
              'medicine_image': item['medicine_image'] ?? '',
              'quantity': isInPassed ? qty : 0,
              'price': double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0,
              'matched': true,
              'available': (item['stock_quantity'] ?? 0) > 0,
              'stock': item['stock_quantity'] ?? 0,
            };
          }).toList();

          if (_resolvedMedicines.isEmpty) {
            _fallbackToDefaults();
          } else {
            // Sort so that pre-selected medicines (quantity > 0) are at the top
            _resolvedMedicines.sort((a, b) {
              final int qa = a['quantity'] ?? 0;
              final int qb = b['quantity'] ?? 0;
              if (qa > 0 && qb == 0) return -1;
              if (qa == 0 && qb > 0) return 1;
              final String na = a['name'] ?? '';
              final String nb = b['name'] ?? '';
              return na.compareTo(nb);
            });

            // Recalculate total price
            double newTotal = 0.0;
            for (var m in _resolvedMedicines) {
              final price = m['price'] ?? 0.0;
              final q = m['quantity'] ?? 0;
              if (m['available'] == true) {
                newTotal += price * q;
              }
            }
            _calculatedTotal = newTotal;
            _isLoadingPrices = false;
          }
        });
      } else {
        _fallbackToDefaults();
      }
    } catch (e) {
      _fallbackToDefaults();
    }
  }

  Future<void> _fetchPrices() async {
    if (widget.medicines.isEmpty) {
      setState(() {
        _resolvedMedicines = [];
        _calculatedTotal = 0.0;
        _isLoadingPrices = false;
      });
      return;
    }

    setState(() => _isLoadingPrices = true);
    try {
      final res = await ApiService.resolvePrices(widget.medicines, pharmacyId: _resolvedPharmacyId);
      if (res['success'] == true) {
        final List data = res['data'] ?? [];
        setState(() {
          _resolvedMedicines = List<Map<String, dynamic>>.from(data);
          _calculatedTotal = double.tryParse(res['total_price']?.toString() ?? '0.0') ?? 0.0;
          _isLoadingPrices = false;
        });
      } else {
        _fallbackToDefaults();
      }
    } catch (e) {
      _fallbackToDefaults();
    }
  }

  void _fallbackToDefaults() {
    setState(() {
      _resolvedMedicines = widget.medicines.map((m) {
        String name = m;
        int qty = 1;
        if (m.contains(" x") && RegExp(r' x\d+$').hasMatch(m)) {
          final parts = m.split(RegExp(r' x(?=\d+$)'));
          if (parts.length == 2) {
            name = parts[0];
            qty = int.tryParse(parts[1]) ?? 1;
          }
        }
        return {
          'original_name': m,
          'name': name,
          'quantity': qty,
          'price': 0.0,
          'matched': false,
          'available': true
        };
      }).toList();
      _calculatedTotal = widget.total;
      _isLoadingPrices = false;
    });
  }

  void _updateQuantity(int index, int newQty) {
    setState(() {
      _resolvedMedicines[index]['quantity'] = newQty;
      
      // Recalculate total price dynamically
      double newTotal = 0.0;
      for (var m in _resolvedMedicines) {
        final price = double.tryParse(m['price']?.toString() ?? '0.0') ?? 0.0;
        final qty = m['quantity'] ?? 0;
        final available = m['available'] ?? false;
        if (available) {
          newTotal += price * qty;
        }
      }
      _calculatedTotal = newTotal;
    });
  }

  Future<void> _addToCart() async {
    setState(() => _isAddingToCart = true);
    
    final List<String> serializeMedicines = _resolvedMedicines
        .where((m) => (m['quantity'] ?? 0) > 0)
        .map((m) {
      final name = m['name'] ?? '';
      final qty = m['quantity'] ?? 1;
      return '$name x$qty';
    }).toList();

    if (serializeMedicines.isEmpty) {
      setState(() => _isAddingToCart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one medicine to reserve.')),
      );
      return;
    }

    final result = await CartService().bulkAddByNames(serializeMedicines, pharmacyId: _resolvedPharmacyId);
    
    if (!mounted) return;
    
    setState(() => _isAddingToCart = false);
    
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Medicines added to cart successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CartScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Failed to add to cart')),
      );
    }
  }

  Future<void> _reorder() async {
    setState(() => _isReordering = true);
    
    final result = await ApiService.reorder(widget.orderId);
    
    if (!mounted) return;
    
    setState(() => _isReordering = false);
    
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order reordered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Failed to reorder'),
          backgroundColor: Colors.red,
        ),
      );
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
        title: const Text('Order Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.status.toLowerCase() == 'delivered' || widget.status.toLowerCase() == 'completed')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✔ Delivered Successfully',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'This order has been completed and received.',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (widget.status == 'preview' || widget.status == 'pending')
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserving from ${widget.pharmacy}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Pickup Date:', style: TextStyle(color: Colors.grey)),
                          Text(widget.date, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            else
              /// Order Info Card (Only show for actual placed/completed orders)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Order ID', widget.orderId),
                      _row('Pharmacy', widget.pharmacy),
                      _row('Date', widget.date),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Status'),
                          Chip(
                            label: Text(widget.status.toUpperCase()),
                            backgroundColor:
                                _statusColor(widget.status).withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: _statusColor(widget.status),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            /// Medicines Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Medicines',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    if (_isLoadingPrices)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_resolvedMedicines.isEmpty)
                      const Text('No medicines found', style: TextStyle(color: Colors.grey))
                    else
                      ...List.generate(_resolvedMedicines.length, (index) {
                        final m = _resolvedMedicines[index];
                        final originalName = m['original_name'] ?? m['name'] ?? '';
                        final name = m['name'] ?? '';
                        final qty = m['quantity'] ?? 0;
                        final price = double.tryParse(m['price']?.toString() ?? '0.0') ?? 0.0;
                        final matched = m['matched'] ?? false;
                        final isSelected = qty > 0;

                        String displayTitle = originalName.trim();
                        if (displayTitle.contains(" x") && RegExp(r' x\d+$').hasMatch(displayTitle)) {
                          displayTitle = displayTitle.split(RegExp(r' x(?=\d+$)'))[0].trim();
                        }

                        final isDifferentMatch = matched && name.toLowerCase().trim() != displayTitle.toLowerCase().trim();

                        return Opacity(
                          opacity: isSelected ? 1.0 : 0.5,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 48,
                                height: 48,
                                color: Colors.grey[200],
                                child: m['medicine_image'] != null &&
                                        m['medicine_image'].toString().isNotEmpty
                                    ? Image.network(
                                        m['medicine_image'].toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.medication,
                                              color: Colors.blueGrey,
                                            ),
                                      )
                                    : const Icon(
                                        Icons.medication,
                                        color: Colors.blueGrey,
                                      ),
                              ),
                            ),
                            title: Text(
                              displayTitle,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (widget.status == 'preview' || widget.status == 'pending') ...[
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          qty > 1 ? Icons.remove_circle_outline : Icons.delete_outline,
                                          size: 20,
                                          color: isSelected ? Colors.red : Colors.grey,
                                        ),
                                        onPressed: isSelected
                                            ? () => _updateQuantity(index, qty - 1)
                                            : null,
                                      ),
                                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green),
                                        onPressed: () {
                                          _updateQuantity(index, qty + 1);
                                        },
                                      ),
                                    ] else ...[
                                      Text('Qty: $qty • ${price.toStringAsFixed(2)} EGP per item', style: const TextStyle(color: Colors.grey)),
                                    ],
                                  ],
                                ),
                                if (isDifferentMatch)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'System Match: $name',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              '${(price * qty).toStringAsFixed(2)} EGP',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            /// Total Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: Text(
                  (widget.status.toLowerCase() == 'delivered' || widget.status.toLowerCase() == 'completed')
                      ? 'Total Amount Paid'
                      : 'Total',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '${_calculatedTotal.toStringAsFixed(2)} EGP',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: (widget.status.toLowerCase() == 'delivered' || widget.status.toLowerCase() == 'completed')
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
                child: SizedBox(
                  height: 55,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.replay),
                    label: _isReordering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Reorder',
                            style: TextStyle(fontSize: 16),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isReordering ? null : _reorder,
                  ),
                ),
              ),
            )
          : (widget.status.toLowerCase() == 'preview' || widget.status.toLowerCase() == 'pending')
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.shopping_cart),
                        label: _isAddingToCart
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Add to Cart',
                                style: TextStyle(fontSize: 16),
                              ),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isAddingToCart ? null : _addToCart,
                      ),
                    ),
                  ),
                )
              : null,
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              v,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
