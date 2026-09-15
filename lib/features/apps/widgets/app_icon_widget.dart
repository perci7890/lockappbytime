import 'dart:convert';
import 'package:flutter/material.dart';

class AppIconWidget extends StatelessWidget {
  final String? base64Icon;
  final double size;

  const AppIconWidget({
    super.key,
    this.base64Icon,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    if (base64Icon != null && base64Icon!.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Icon!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildFallback(),
          ),
        );
      } catch (_) {
        return _buildFallback();
      }
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade800,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(
        Icons.android,
        color: Colors.white70,
        size: size * 0.6,
      ),
    );
  }
}
