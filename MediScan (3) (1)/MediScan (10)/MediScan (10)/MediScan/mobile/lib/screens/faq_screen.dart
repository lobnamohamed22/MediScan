import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  final List<Map<String, String>> faqs = const [
    {
      'q': 'How do I scan a prescription?',
      'a': 'Go to Scan Prescription screen and tap Scan button.'
    },
    {
      'q': 'How can I track my order?',
      'a': 'Open Order History and tap Track Order.'
    },
    {
      'q': 'Can I edit scanned medicines?',
      'a': 'Yes, you can verify and edit medicines before saving.'
    },
    {
      'q': 'How do I enable dark mode?',
      'a': 'Open Settings and turn on Dark Mode.'
    },
    {'q': 'Is my data secure?', 'a': 'Yes, your data is stored securely.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FAQ'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, i) {
          final item = faqs[i];

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: ExpansionTile(
              title: Text(
                item['q']!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(item['a']!),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
