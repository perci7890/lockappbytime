import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:applockbytime/core/services/pin_service.dart';
import 'package:applockbytime/features/apps/app_selection_screen.dart';
import 'package:applockbytime/features/focus/focus_modes_screen.dart';
import 'package:applockbytime/features/home/providers/lock_provider.dart';
import 'package:applockbytime/features/home/widgets/accessibility_notice_banner.dart';
import 'package:applockbytime/features/home/widgets/active_lock_card.dart';
import 'package:applockbytime/features/home/widgets/early_unlock_dialog.dart';
import 'package:applockbytime/features/home/widgets/pin_entry_dialog.dart';
import 'package:applockbytime/features/settings/settings_screen.dart';
import 'package:applockbytime/features/stats/usage_stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LockProvider>().loadInstalledApps();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<LockProvider>().refreshAll();
    }
  }

  void _openAppSelection(BuildContext context) {
    final provider = context.read<LockProvider>();
    final lockedPackages = provider.activeLocks
        .where((l) => l.isCurrentlyLocked)
        .map((l) => l.packageName)
        .toSet();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppSelectionScreen(
          apps: provider.installedApps,
          currentlyLockedPackages: lockedPackages,
        ),
      ),
    );
  }

  Future<bool> _verifyPinIfRequired() async {
    final isEnabled = await PinService.isPinEnabled();
    if (!isEnabled) return true;
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PinEntryDialog(
        title: 'Security Verification',
        subtitle: 'Enter PIN to authorize unlock action',
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LockProvider>(
      builder: (context, provider, _) {
        final activeLocks = provider.activeLocks;
        final schedules = provider.allSchedules;
        final focusModes = provider.focusModes;

        return Scaffold(
          appBar: AppBar(
            title: const Text('App Locker'),
            actions: [
              IconButton(
                tooltip: 'Usage Statistics',
                icon: const Icon(Icons.bar_chart),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const UsageStatsScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'Focus Modes',
                icon: const Icon(Icons.center_focus_strong),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FocusModesScreen()),
                  );
                },
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await provider.refreshAll();
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (!provider.isAccessibilityEnabled)
                  AccessibilityNoticeBanner(
                    onEnablePressed: () => provider.openAccessibilitySettings(),
                  ),

                if (!provider.isBatteryOptimizationIgnored)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF422006),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.battery_alert, color: Color(0xFFFBBF24)),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Battery Optimization Enabled',
                                style: TextStyle(
                                  color: Color(0xFFFDE68A),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Android may kill App Locker in the background, causing accessibility to turn off. Set battery usage to "Unrestricted" for 100% strict enforcement.',
                          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: () => provider.requestIgnoreBatteryOptimization(),
                            icon: const Icon(Icons.flash_on, size: 16),
                            label: const Text('Set Unrestricted'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ACTIVE NOW Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIVE NOW',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF60A5FA),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeLocks.isEmpty
                              ? 'No apps currently blocked'
                              : '${activeLocks.length} active restriction${activeLocks.length > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 13, color: Colors.white54),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () => _openAppSelection(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Lock App'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                if (activeLocks.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'All apps are currently accessible.\nTap "+ Lock App" to start a Quick Lock or Schedule.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, height: 1.4),
                      ),
                    ),
                  )
                else
                  ...activeLocks.map((lock) {
                    return ActiveLockCard(
                      key: ValueKey('${lock.packageName}_${lock.lockType}_${lock.sourceId}'),
                      lock: lock,
                      onUnlockEarly: () async {
                        final verified = await _verifyPinIfRequired();
                        if (!verified) return;

                        if (!context.mounted) return;
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => EarlyUnlockDialog(appName: lock.appName),
                        );
                        if (confirm == true) {
                          await provider.unlockEarly(lock.packageName, lockType: lock.lockType, sourceId: lock.sourceId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${lock.appName} unlocked early'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
                        }
                      },
                    );
                  }),

                // UPCOMING SCHEDULES SECTION
                if (schedules.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const Text(
                    'RECURRING SCHEDULES',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF60A5FA),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...schedules.map((schedule) {
                    final startH = (schedule.startMinutes ~/ 60) % 24;
                    final startM = schedule.startMinutes % 60;
                    final endH = (schedule.endMinutes ~/ 60) % 24;
                    final endM = schedule.endMinutes % 60;
                    final startFormatted = TimeOfDay(hour: startH, minute: startM).format(context);
                    final endFormatted = TimeOfDay(hour: endH, minute: endM).format(context);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, color: Color(0xFF38BDF8), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(schedule.appName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                Text('$startFormatted → $endFormatted (${schedule.daysOfWeek})', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white38),
                            onPressed: () async {
                              final verified = await _verifyPinIfRequired();
                              if (verified) {
                                await provider.deleteSchedule(schedule.packageName, sourceId: schedule.sourceId);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // FOCUS MODES SHORTCUT
                if (focusModes.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'FOCUS MODES',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF60A5FA),
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const FocusModesScreen()),
                          );
                        },
                        child: const Text('Manage', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: focusModes.take(3).map((mode) {
                      final isActive = (mode['isActive'] as int? ?? 0) == 1;
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isActive ? const Color(0xFF3B82F6) : Colors.transparent),
                          ),
                          child: Column(
                            children: [
                              Text(mode['icon'] as String, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 4),
                              Text(mode['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                              const SizedBox(height: 6),
                              ElevatedButton(
                                onPressed: () async {
                                  if (isActive) {
                                    await provider.stopFocusMode(mode['id'] as String);
                                  } else {
                                    await provider.startFocusMode(mode['id'] as String);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isActive ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(60, 28),
                                ),
                                child: Text(isActive ? 'Stop' : 'Start', style: const TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAppSelection(context),
            icon: const Icon(Icons.add),
            label: const Text('Lock an App'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      },
    );
  }
}
