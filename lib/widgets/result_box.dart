import 'package:flutter/material.dart';

class ResultBox extends StatelessWidget {
  final String text;

  const ResultBox({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Text(
        text,
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}
