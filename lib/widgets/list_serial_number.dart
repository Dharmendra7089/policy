import 'package:flutter/material.dart';

/// Compact leading serial number used by Data Management list rows.
class ListSerialNumber extends StatelessWidget {
  final int number;
  final double size;

  const ListSerialNumber({super.key, required this.number, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Serial number $number',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: const Color(0xFFDCE3EC)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              number.toString(),
              style: TextStyle(
                color: const Color(0xFF475569),
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
