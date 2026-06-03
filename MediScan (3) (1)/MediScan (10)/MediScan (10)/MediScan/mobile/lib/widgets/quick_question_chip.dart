import 'package:flutter/material.dart';

class QuickQuestionChip extends StatelessWidget {
  final String question;
  final VoidCallback onTap;

  const QuickQuestionChip({
    super.key,
    required this.question,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Text(
          question,
          style: const TextStyle(
            color: Colors.blue,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
