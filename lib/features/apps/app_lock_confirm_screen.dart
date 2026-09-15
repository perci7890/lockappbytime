import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:applockbytime/data/models/app_info.dart';
import 'package:applockbytime/features/home/providers/lock_provider.dart';
import 'package:applockbytime/features/apps/widgets/app_icon_widget.dart';

class AppLockConfirmScreen extends StatefulWidget {
  final AppInfo app;
  final Duration duration;

  const AppLockConfirmScreen({
    super.key,
    required this.app,
    required this.duration,
  });

  @override
  State<AppLockConfirmScreen> createState() => _AppLockConfirmScreenState();
}

class _AppLockConfirmScreenState extends State<AppLockConfirmScreen> {
  bool _isSaving = false;

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    final parts = <String>[];
    if (hours > 0) parts.add('$hours hour${hours > 1 ? 's' : ''}');
    if (mins > 0) parts.add('$mins minute${mins > 1 ? 's' : ''}');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final unlockAt = now.add(widget.duration);
    final timeFormat = DateFormat('h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Lock'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: AppIconWidget(
                  base64Icon: widget.app.iconBase64,
                  size: 80,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Lock ${widget.app.appName}?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  widget.app.packageName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Detail Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  children: [
                    _buildRow('Duration', _formatDuration(widget.duration)),
                    const Divider(color: Color(0xFF334155), height: 28),
                    _buildRow('Starts', 'Now (${timeFormat.format(now)})'),
                    const Divider(color: Color(0xFF334155), height: 28),
                    _buildRow(
                      'Unlocks',
                      timeFormat.format(unlockAt),
                      highlightColor: const Color(0xFF60A5FA),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() {
                          _isSaving = true;
                        });

                        final provider =
                            Provider.of<LockProvider>(context, listen: false);
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        await provider.lockApp(
                          app: widget.app,
                          duration: widget.duration,
                        );

                        if (!mounted) return;

                        navigator.popUntil((route) => route.isFirst);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              '${widget.app.appName} locked until ${timeFormat.format(unlockAt)}',
                            ),
                            backgroundColor: const Color(0xFF2563EB),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF2563EB),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Start Lock',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? highlightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 15,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlightColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
