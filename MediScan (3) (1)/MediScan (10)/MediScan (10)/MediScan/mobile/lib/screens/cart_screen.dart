import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'order_tracking_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<dynamic> _cartItems = [];
  double _totalPrice = 0.0;
  int _userPoints = 0;
  bool _usePoints = false;
  double _pointsDiscount = 0.0;
  double _finalTotalPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  Future<void> _fetchCart() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final res = await ApiService.getCart();
    final walletRes = await ApiService.getWallet();

    if (mounted) {
      if (res['success'] == true) {
        setState(() {
          _cartItems = res['data']['items'] ?? [];
          _totalPrice =
              double.tryParse(res['data']['total_price'].toString()) ?? 0.0;
          if (walletRes['success'] == true) {
            _userPoints = int.tryParse(walletRes['data']['reward_points'].toString()) ?? 0;
          }
          _updatePointsDiscount();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load cart';
          _isLoading = false;
        });
      }
    }
  }

  void _updatePointsDiscount() {
    if (_usePoints && _userPoints > 0) {
      double pointsValue = _userPoints * 0.1;
      if (pointsValue > _totalPrice) {
        _pointsDiscount = _totalPrice;
        _finalTotalPrice = 0.0;
      } else {
        _pointsDiscount = pointsValue;
        _finalTotalPrice = _totalPrice - pointsValue;
      }
    } else {
      _pointsDiscount = 0.0;
      _finalTotalPrice = _totalPrice;
    }
  }

  Future<void> _updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity < 1) {
      _removeItem(cartItemId);
      return;
    }

    final res = await ApiService.updateCartItem(cartItemId, newQuantity);
    if (res['success'] == true) {
      _fetchCart();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res['message'] ?? 'Failed to update quantity')),
        );
      }
    }
  }

  Future<void> _removeItem(String cartItemId) async {
    final res = await ApiService.removeCartItem(cartItemId);
    if (res['success'] == true) {
      _fetchCart();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed from cart')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to remove item')),
        );
      }
    }
  }

  Future<void> _checkout() async {
    setState(() => _isLoading = true);

    int redeemPoints = 0;
    if (_usePoints && _userPoints > 0) {
      double pointsValue = _userPoints * 0.1;
      if (pointsValue > _totalPrice) {
        redeemPoints = (_totalPrice * 10).toInt();
      } else {
        redeemPoints = _userPoints;
      }
    }

    final res = await ApiService.checkoutCart(redeemPoints: redeemPoints);

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success'] == true) {
        final orderId = res['order_id'];
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );
        final List<String> medicineNames = _cartItems
            .map((item) => item['medicine']['medicine_name'].toString())
            .toList();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(
              orderId: orderId,
              pharmacyName: 'MediScan Pharmacy',
              medicines: medicineNames,
              status: 'assigned',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Checkout failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
      ),
      body: _buildBody(),
      bottomNavigationBar:
          _cartItems.isNotEmpty && !_isLoading ? _buildCheckoutBar() : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: _fetchCart, child: const Text('Retry'))
          ],
        ),
      );
    }

    if (_cartItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Your cart is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cartItems.length,
      itemBuilder: (context, index) {
        final item = _cartItems[index];
        final medicine = item['medicine'];
        final quantity = item['quantity'];
        final price = medicine['price'];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: medicine['image_url'] != null &&
                          medicine['image_url'].toString().isNotEmpty
                      ? Image.network(medicine['image_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.medication, color: Colors.grey))
                      : const Icon(Icons.medication, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine['medicine_name'] ?? 'Unknown Medicine',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${price.toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      onPressed: () =>
                          _updateQuantity(item['cart_item_id'], quantity - 1),
                    ),
                    Text('$quantity',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline,
                          color: Colors.green),
                      onPressed: () =>
                          _updateQuantity(item['cart_item_id'], quantity + 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -5),
            blurRadius: 10,
          )
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_userPoints > 0) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Redeem Points (Available: $_userPoints pts)',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _usePoints
                      ? 'Discount: -${_pointsDiscount.toStringAsFixed(2)} EGP'
                      : 'Equiv. to ${(_userPoints * 0.1).toStringAsFixed(2)} EGP',
                  style: TextStyle(
                    fontSize: 12,
                    color: _usePoints ? Colors.red : Colors.grey,
                  ),
                ),
                value: _usePoints,
                onChanged: (val) {
                  setState(() {
                    _usePoints = val ?? false;
                    _updatePointsDiscount();
                  });
                },
                activeColor: Colors.blue,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Divider(),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Price',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                    if (_pointsDiscount > 0) ...[
                      Text(
                        '${_totalPrice.toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                    Text(
                      '${_finalTotalPrice.toStringAsFixed(2)} EGP',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Checkout',
                      style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
