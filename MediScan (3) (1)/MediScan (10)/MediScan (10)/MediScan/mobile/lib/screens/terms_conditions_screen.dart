import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        centerTitle: true,
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terms and Conditions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              Text(
                '1. Acceptance of Terms',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'By using this application, you agree to comply with and be bound by these terms and conditions.',
              ),
              SizedBox(height: 16),
              Text(
                '2. Medical Disclaimer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'This app is not a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider.',
              ),
              SizedBox(height: 16),
              Text(
                '3. Prescription Scanning',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'OCR and scanning results may contain errors. Users must verify all prescription details before use.',
              ),
              SizedBox(height: 16),
              Text(
                '4. User Responsibilities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Users are responsible for the accuracy of the information they upload and share.',
              ),
              SizedBox(height: 16),
              Text(
                '5. Data Usage',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'We store and process data only to provide core app functionality.',
              ),
              SizedBox(height: 16),
              Text(
                '6. Limitation of Liability',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'We are not liable for any damages resulting from the use of this application.',
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
