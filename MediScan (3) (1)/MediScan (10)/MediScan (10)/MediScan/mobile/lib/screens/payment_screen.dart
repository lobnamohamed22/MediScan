// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;
  final double total;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.total,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String paymentMethod = 'cash';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        centerTitle: true,
      ),

      ///  BODY
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ID: ${widget.orderId}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${widget.total} EGP',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'cash',
              groupValue: paymentMethod,
              title: const Text('Cash on Delivery'),
              onChanged: (v) {
                setState(() {
                  paymentMethod = v!;
                });
              },
            ),
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: 'card',
              groupValue: paymentMethod,
              title: const Text('Credit / Debit Card'),
              onChanged: (v) {
                setState(() {
                  paymentMethod = v!;
                });
              },
            ),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
          child: SizedBox(
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Confirm Payment',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
