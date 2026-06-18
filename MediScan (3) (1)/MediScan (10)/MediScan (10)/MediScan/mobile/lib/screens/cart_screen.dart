import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'order_tracking_screen.dart';
import '../config.dart';

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


  @override
  void initState() {
    super.initState();
    _fetchCart();
  }

  Future<void> _fetchCart({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final res = await ApiService.getCart();

      if (mounted) {
        if (res['success'] == true) {
          setState(() {
            _cartItems = res['data']['items'] ?? [];
            _totalPrice =
                double.tryParse(res['data']['total_price'].toString()) ?? 0.0;

            _isLoading = false;
            _errorMessage = '';
          });
        } else {
          setState(() {
            if (showLoading || _cartItems.isEmpty) {
              _errorMessage = res['message'] ?? 'Failed to load cart';
            }
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (showLoading || _cartItems.isEmpty) {
            _errorMessage = 'An error occurred: $e';
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(String cartItemId, int newQuantity) async {
    if (newQuantity < 1) {
      _removeItem(cartItemId);
      return;
    }

    // Backup current state in case of api failure
    final originalItems = List<dynamic>.from(_cartItems.map((item) {
      return {
        ...item,
        'medicine': Map<String, dynamic>.from(item['medicine'] as Map),
      };
    }));
    final originalTotal = _totalPrice;

    // Optimistically update the UI quantity and total price
    setState(() {
      for (var item in _cartItems) {
        if (item['cart_item_id'] == cartItemId) {
          item['quantity'] = newQuantity;
        }
      }
      _totalPrice = _cartItems.fold(0.0, (sum, item) {
        final price =
            double.tryParse(item['medicine']['price'].toString()) ?? 0.0;
        final qty = int.tryParse(item['quantity'].toString()) ?? 1;
        return sum + (price * qty);
      });
    });

    final res = await ApiService.updateCartItem(cartItemId, newQuantity);
    if (res['success'] == true) {
      // Background reload to ensure client/server state matches
      _fetchCart(showLoading: false);
    } else {
      // Revert changes on failure
      setState(() {
        _cartItems = originalItems;
        _totalPrice = originalTotal;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(res['message'] ?? 'Failed to update quantity')),
        );
      }
    }
  }

  Future<void> _removeItem(String cartItemId) async {
    // Backup current state in case of api failure
    final originalItems = List<dynamic>.from(_cartItems.map((item) {
      return {
        ...item,
        'medicine': Map<String, dynamic>.from(item['medicine'] as Map),
      };
    }));
    final originalTotal = _totalPrice;

    // Optimistically remove from list and update total price
    setState(() {
      _cartItems.removeWhere((item) => item['cart_item_id'] == cartItemId);
      _totalPrice = _cartItems.fold(0.0, (sum, item) {
        final price =
            double.tryParse(item['medicine']['price'].toString()) ?? 0.0;
        final qty = int.tryParse(item['quantity'].toString()) ?? 1;
        return sum + (price * qty);
      });
    });

    final res = await ApiService.removeCartItem(cartItemId);
    if (res['success'] == true) {
      // Background reload to sync client state
      _fetchCart(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item removed from cart')),
        );
      }
    } else {
      // Revert on failure
      setState(() {
        _cartItems = originalItems;
        _totalPrice = originalTotal;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to remove item')),
        );
      }
    }
  }

  Future<void> _checkout() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final res = await ApiService.checkoutCart();

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

        String imageUrl = medicine['image_url'] ?? '';
        if (imageUrl.contains('127.0.0.1') || imageUrl.contains('localhost')) {
          imageUrl = imageUrl
              .replaceAll('127.0.0.1', '10.0.2.2')
              .replaceAll('localhost', '10.0.2.2');
        } else if (imageUrl.startsWith('/')) {
          imageUrl = '${Config.baseUrl}$imageUrl';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
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
                        'Unit Price: ${price.toStringAsFixed(2)} EGP',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total: ${(price * quantity).toStringAsFixed(2)} EGP',
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.bold),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Total Price',
                        style: TextStyle(color: Colors.grey, fontSize: 14)),
                    Text(
                      '${_totalPrice.toStringAsFixed(2)} EGP',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _checkout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Checkout',
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
