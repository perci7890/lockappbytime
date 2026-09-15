import 'package:flutter/material.dart';

class EmptyLocksView extends StatelessWidget {
  final VoidCallback onLockAppPressed;

  const EmptyLocksView({
    super.key,
    required this.onLockAppPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF334155),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.lock_clock,
                size: 64,
                color: Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Apps Currently Locked',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose an app and set a temporary lock duration from 1 minute to 24 hours to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white60,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onLockAppPressed,
              icon: const Icon(Icons.add),
              label: const Text('Lock an App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
