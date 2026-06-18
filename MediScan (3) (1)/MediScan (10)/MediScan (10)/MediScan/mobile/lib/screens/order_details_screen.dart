import 'package:flutter/material.dart';
import 'cart_screen.dart';
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

  String? get _resolvedPharmacyId =>
      widget.pharmacyId ??
      (widget.orderId.startsWith('RES-') ? widget.orderId.substring(4) : null);

  @override
  void initState() {
    super.initState();
    _fetchPrices();
  }

  int _min3(int a, int b, int c) {
    int m = a;
    if (b < m) m = b;
    if (c < m) m = c;
    return m;
  }

  int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.generate(t.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        v1[j + 1] = _min3(v1[j] + 1, v0[j + 1] + 1, v0[j] + cost);
      }
      v0 = List<int>.from(v1);
    }
    return v0[t.length];
  }

  double calculateSimilarity(String s1, String s2) {
    s1 = s1.toLowerCase().trim();
    s2 = s2.toLowerCase().trim();

    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Clean common suffixes/units (mg, g, ml, etc.) and strengths
    final cleanReg = RegExp(
        r'\b(?:\d+\.?\d*\s*)?(mg|g|ml|cream|gel|injection|inhaler|tablets|tablet|capsules|capsule)\b');
    String clean1 =
        s1.replaceAll(cleanReg, '').replaceAll(RegExp(r'\s+'), ' ').trim();
    String clean2 =
        s2.replaceAll(cleanReg, '').replaceAll(RegExp(r'\s+'), ' ').trim();

    if (clean1 == clean2) return 1.0;
    if (clean1.isEmpty || clean2.isEmpty) return 0.0;

    // Direct substring check on clean names
    if (clean1.contains(clean2) || clean2.contains(clean1)) {
      final int commonLen =
          clean1.length < clean2.length ? clean1.length : clean2.length;
      final int maxLen =
          clean1.length > clean2.length ? clean1.length : clean2.length;
      return commonLen / maxLen;
    }

    final int distance = _levenshteinDistance(clean1, clean2);
    final int maxLength =
        clean1.length > clean2.length ? clean1.length : clean2.length;
    double score = 1.0 - (distance / maxLength);

    // Try to find if raw strength matches (e.g. 90 vs 90)
    final numReg = RegExp(r'\d+');
    final m1 = numReg.firstMatch(s1)?.group(0);
    final m2 = numReg.firstMatch(s2)?.group(0);
    if (m1 != null && m2 != null && m1 == m2 && score >= 0.70) {
      score = score + 0.15; // Give strength bonus
      if (score > 1.0) score = 1.0;
    }
    return score;
  }

  String getImageUrl(String? imgPath) {
    if (imgPath == null || imgPath.isEmpty) {
      return '${ApiService.baseUrl.replaceAll("/api", "")}/uploads/medicines/generic_pill.png';
    }
    String path = imgPath.toString();
    if (path.contains('127.0.0.1') || path.contains('localhost')) {
      path = path
          .replaceAll('127.0.0.1', '10.0.2.2')
          .replaceAll('localhost', '10.0.2.2');
    } else if (!path.startsWith('http')) {
      final base = ApiService.baseUrl.replaceAll('/api', '');
      path = path.startsWith('/') ? '$base$path' : '$base/$path';
    }
    return path;
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
      final res = await ApiService.resolvePrices(widget.medicines,
          pharmacyId: _resolvedPharmacyId);
      if (res['success'] == true) {
        final List data = res['data'] ?? [];
        setState(() {
          _resolvedMedicines = List<Map<String, dynamic>>.from(data);
          _calculatedTotal =
              double.tryParse(res['total_price']?.toString() ?? '0.0') ?? 0.0;
          _isLoadingPrices = false;
        });
      } else {
        _fallbackToDefaults();
      }
    } catch (e, stackTrace) {
      print('[OrderDetailsScreen] Error in _fetchPrices: $e');
      print(stackTrace);
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
        newTotal += price * qty;
      }
      _calculatedTotal = newTotal;
    });
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    setState(() => _isAddingToCart = true);

    final List<String> serializeMedicines =
        _resolvedMedicines.where((m) => (m['quantity'] ?? 0) > 0).map((m) {
      final name = m['name'] ?? '';
      final qty = m['quantity'] ?? 1;
      return '$name x$qty';
    }).toList();

    if (serializeMedicines.isEmpty) {
      setState(() => _isAddingToCart = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select at least one medicine to reserve.')),
      );
      return;
    }

    final result = await ApiService.bulkAddByNames(serializeMedicines,
        pharmacyId: _resolvedPharmacyId);

    if (!mounted) return;

    setState(() => _isAddingToCart = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Medicines added to cart successfully!'),
            backgroundColor: Colors.green),
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
    if (_isReordering) return;
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
            if (widget.status.toLowerCase() == 'delivered' ||
                widget.status.toLowerCase() == 'completed')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3), width: 1.5),
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
                          const Text('Pickup Date:',
                              style: TextStyle(color: Colors.grey)),
                          Text(widget.date,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
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
                            backgroundColor: _statusColor(widget.status)
                                .withValues(alpha: 0.15),
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
                      const Text('No medicines found',
                          style: TextStyle(color: Colors.grey))
                    else
                      ...List.generate(_resolvedMedicines.length, (index) {
                        final m = _resolvedMedicines[index];
                        final originalName =
                            m['original_name'] ?? m['name'] ?? '';
                        final name = m['name'] ?? '';
                        final qty = m['quantity'] ?? 0;
                        final price =
                            double.tryParse(m['price']?.toString() ?? '0.0') ??
                                0.0;
                        final matched = m['matched'] ?? false;
                        final isSelected = qty > 0;

                        String displayTitle = originalName.trim();
                        if (displayTitle.contains(" x") &&
                            RegExp(r' x\d+$').hasMatch(displayTitle)) {
                          displayTitle = displayTitle
                              .split(RegExp(r' x(?=\d+$)'))[0]
                              .trim();
                        }

                        final isDifferentMatch = matched &&
                            name.toLowerCase().trim() !=
                                displayTitle.toLowerCase().trim();

                        return Opacity(
                          opacity: isSelected ? 1.0 : 0.5,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              matched ? name : displayTitle,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Unit Price: ${price.toStringAsFixed(2)} EGP',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isDifferentMatch)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      'Scanned as: $displayTitle',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                if (widget.status == 'preview' ||
                                    widget.status == 'pending')
                                  Row(
                                    children: [
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          qty > 1
                                              ? Icons.remove_circle_outline
                                              : Icons.delete_outline,
                                          size: 22,
                                          color: isSelected
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        onPressed: isSelected
                                            ? () =>
                                                _updateQuantity(index, qty - 1)
                                            : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('$qty',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15)),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                            Icons.add_circle_outline,
                                            size: 22,
                                            color: Colors.green),
                                        onPressed: () {
                                          _updateQuantity(index, qty + 1);
                                        },
                                      ),
                                    ],
                                  )
                                else
                                  Text(
                                    'Qty: $qty',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Text(
                              '${(price * qty).toStringAsFixed(2)} EGP',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.teal,
                              ),
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
                  (widget.status.toLowerCase() == 'delivered' ||
                          widget.status.toLowerCase() == 'completed')
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
      bottomNavigationBar: (widget.status.toLowerCase() == 'delivered' ||
              widget.status.toLowerCase() == 'completed')
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
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
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
          : (widget.status.toLowerCase() == 'preview' ||
                  widget.status.toLowerCase() == 'pending')
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
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
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
