import 'package:flutter/material.dart';

class MoodChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const MoodChip({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
    );
  }
}