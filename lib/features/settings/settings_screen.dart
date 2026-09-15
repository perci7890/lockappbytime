import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:applockbytime/core/services/native_bridge_service.dart';
import 'package:applockbytime/core/services/pin_service.dart';
import 'package:applockbytime/features/focus/focus_modes_screen.dart';
import 'package:applockbytime/features/home/providers/lock_provider.dart';
import 'package:applockbytime/features/home/widgets/pin_entry_dialog.dart';
import 'package:applockbytime/features/settings/diagnostics_screen.dart';
import 'package:applockbytime/features/stats/usage_stats_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _canDrawOverlays = false;
  bool _isPinEnabled = false;
  bool _isEmergencyPinReq = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final granted = await NativeBridgeService.canDrawOverlays();
    final pinEnabled = await PinService.isPinEnabled();
    final emergencyPin = await PinService.isEmergencyPinRequired();
    if (mounted) {
      setState(() {
        _canDrawOverlays = granted;
        _isPinEnabled = pinEnabled;
        _isEmergencyPinReq = emergencyPin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<LockProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Required Services
              const Text(
                'App Locking',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF60A5FA),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('Accessibility Service', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Detect when a locked application opens', style: TextStyle(fontSize: 12, color: Colors.white60)),
                      trailing: provider.isAccessibilityEnabled
                          ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                          : const Icon(Icons.cancel, color: Color(0xFFEF4444)),
                      onTap: () => provider.openAccessibilitySettings(),
                    ),
                    const Divider(color: Color(0xFF334155), height: 1),
                    ListTile(
                      title: const Text('Display Over Other Apps', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Presents lock screen on top of locked apps', style: TextStyle(fontSize: 12, color: Colors.white60)),
                      trailing: _canDrawOverlays
                          ? const Icon(Icons.check_circle, color: Color(0xFF10B981))
                          : const Icon(Icons.cancel, color: Color(0xFFEF4444)),
                      onTap: () async {
                        await NativeBridgeService.openOverlaySettings();
                        await _checkStatus();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Security & PIN
              const Text(
                'Security',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF60A5FA),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('PIN Protection', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        _isPinEnabled ? 'Protects early unlock and schedule editing' : 'Set a 4-digit PIN to prevent bypass',
                        style: const TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                      value: _isPinEnabled,
                      activeThumbColor: const Color(0xFF2563EB),
                      onChanged: (val) async {
                        if (val) {
                          final success = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const PinEntryDialog(isCreating: true),
                          );
                          if (success == true) await _checkStatus();
                        } else {
                          final success = await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const PinEntryDialog(title: 'Disable PIN', subtitle: 'Enter current PIN to confirm'),
                          );
                          if (success == true) {
                            await PinService.disablePin();
                            await _checkStatus();
                          }
                        }
                      },
                    ),
                    if (_isPinEnabled) ...[
                      const Divider(color: Color(0xFF334155), height: 1),
                      SwitchListTile(
                        title: const Text('Require PIN for Emergency Unlock', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Prompt for PIN before 5-minute unlock', style: TextStyle(fontSize: 12, color: Colors.white60)),
                        value: _isEmergencyPinReq,
                        activeThumbColor: const Color(0xFF2563EB),
                        onChanged: (val) async {
                          await PinService.setEmergencyPinRequired(val);
                          await _checkStatus();
                        },
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Advanced Features Quick Links
              const Text(
                'Features & Tools',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF60A5FA),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.bar_chart, color: Color(0xFF38BDF8)),
                      title: const Text('Usage Statistics', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('App screen time & usage analysis', style: TextStyle(fontSize: 12, color: Colors.white60)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsageStatsScreen())),
                    ),
                    const Divider(color: Color(0xFF334155), height: 1),
                    ListTile(
                      leading: const Icon(Icons.center_focus_strong, color: Color(0xFF38BDF8)),
                      title: const Text('Focus Modes & Groups', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Batch lock groups (Study, Work, Sleep)', style: TextStyle(fontSize: 12, color: Colors.white60)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusModesScreen())),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Diagnostics
              const Text(
                'Advanced',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF60A5FA),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  leading: const Icon(Icons.troubleshoot, color: Color(0xFF38BDF8)),
                  title: const Text('Native Diagnostics', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Real-time enforcement telemetry, foreground events & errors', style: TextStyle(fontSize: 12, color: Colors.white60)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white38),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiagnosticsScreen())),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
