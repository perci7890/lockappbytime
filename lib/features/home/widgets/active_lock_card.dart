import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/lock_record.dart';
import '../../apps/widgets/app_icon_widget.dart';

class ActiveLockCard extends StatelessWidget {
  final LockRecord lock;
  final VoidCallback onUnlockEarly;

  const ActiveLockCard({
    super.key,
    required this.lock,
    required this.onUnlockEarly,
  });

  String _formatRemaining(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatLockBadge() {
    if (lock.lockType == 'schedule') return 'Scheduled';
    if (lock.lockType == 'focusMode') return 'Focus Mode';
    return 'Locked';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = lock.remainingDuration;
    final unlockTimeStr = DateFormat('h:mm a').format(lock.nextUnlockDateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: lock.lockType == 'schedule'
              ? const Color(0xFF38BDF8).withValues(alpha: 0.4)
              : const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            Row(
              children: [
                AppIconWidget(
                  base64Icon: lock.iconBase64,
                  size: 52,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lock.appName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: lock.lockType == 'schedule'
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatLockBadge(),
                            style: TextStyle(
                              color: lock.lockType == 'schedule'
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFFEF4444),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  Unlocks at $unlockTimeStr',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Time Remaining',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatRemaining(remaining),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF60A5FA),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onUnlockEarly,
                      icon: const Icon(Icons.lock_open, size: 16),
                      label: Text(lock.lockType == 'schedule' ? 'Disable' : 'Unlock Early'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                        side: const BorderSide(color: Color(0xFF475569)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
