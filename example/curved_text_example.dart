import 'package:flutter/material.dart';
import 'package:magic_calendar/src/ui/components/curved_text.dart';

/// Example demonstrating how to use [CurvedText] with a custom bezier [Path].
Widget buildCurvedTextExample() {
  final path = Path()
    ..moveTo(20, 50)
    ..quadraticBezierTo(150, 10, 280, 40);

  return CurvedText(
    text: 'WATER ELEMENT • SAP RISING',
    path: path,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.5,
      color: Color(0xFF5B8A4E),
    ),
  );
}
