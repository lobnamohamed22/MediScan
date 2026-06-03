import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Text(
                '1. Information We Collect',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'We may collect account data, prescription images, and scan results to provide core app features.',
              ),
              SizedBox(height: 16),
              Text(
                '2. How We Use Data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Data is used only for prescription scanning, pharmacy search, and reservation features.',
              ),
              SizedBox(height: 16),
              Text(
                '3. Location Usage',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Location is used to find nearby pharmacies. It is not stored permanently.',
              ),
              SizedBox(height: 16),
              Text(
                '4. Data Storage',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Some data may be stored locally on your device for better experience.',
              ),
              SizedBox(height: 16),
              Text(
                '5. Third-Party Services',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'We may use trusted third-party libraries for OCR and maps.',
              ),
              SizedBox(height: 24),
              Text(
                'Last updated: 2026',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
