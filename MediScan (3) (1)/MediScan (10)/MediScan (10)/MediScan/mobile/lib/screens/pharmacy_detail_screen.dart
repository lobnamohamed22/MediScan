import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/pharmacy.dart';

class PharmacyDetailScreen extends StatelessWidget {
  final Pharmacy pharmacy;

  const PharmacyDetailScreen({super.key, required this.pharmacy});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pharmacy.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.location_on, 'Address', pharmacy.address.isNotEmpty ? pharmacy.address : 'No address provided'),
            const SizedBox(height: 16),
            InkWell(
              onTap: pharmacy.phone.isNotEmpty ? () => _makePhoneCall(pharmacy.phone) : null,
              child: _buildInfoRow(
                Icons.phone, 
                'Phone Number', 
                pharmacy.phone.isNotEmpty ? pharmacy.phone : 'No phone number provided',
                isLink: pharmacy.phone.isNotEmpty,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.star, 'Rating', '${pharmacy.rating} / 5.0'),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.access_time, 'Opening Hours', pharmacy.workingHours),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.delivery_dining, 
              'Delivery', 
              pharmacy.hasDelivery ? 'Available' : 'Not Available',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isLink = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: isLink ? Colors.blue : Colors.black87,
                  decoration: isLink ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
