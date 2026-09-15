import 'package:flutter/material.dart';

class EarlyUnlockDialog extends StatelessWidget {
  final String appName;

  const EarlyUnlockDialog({super.key, required this.appName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Unlock $appName Early?',
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      content: const Text(
        'The current time-based lock will be cancelled immediately and the app will become accessible.',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
          ),
          child: const Text('Unlock'),
        ),
      ],
    );
  }
}
