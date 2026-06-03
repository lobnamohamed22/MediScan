import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  Future<void> _call() async {
    final uri = Uri.parse('tel:+201234567890');
    await launchUrl(uri);
  }

  Future<void> _email() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@mediscan.com',
      queryParameters: {
        'subject': 'Support Request',
      },
    );
    await launchUrl(uri);
  }

  Future<void> _whatsapp() async {
    final uri = Uri.parse('https://wa.me/201234567890');
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Us'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.support_agent,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            const Text(
              'We are here to help you',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Call Us'),
              subtitle: const Text('+20 123 456 7890'),
              onTap: _call,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email'),
              subtitle: const Text('support@mediscan.com'),
              onTap: _email,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('WhatsApp'),
              subtitle: const Text('Chat with support'),
              onTap: _whatsapp,
            ),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'Support hours: 9 AM – 9 PM',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
