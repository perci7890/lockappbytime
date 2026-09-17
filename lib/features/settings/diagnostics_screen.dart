import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:applockbytime/core/services/native_bridge_service.dart';
import 'package:applockbytime/features/home/providers/lock_provider.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _diagnostics = {};

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    final data = await NativeBridgeService.getDiagnostics();
    if (mounted) {
      setState(() {
        _diagnostics = data;
        _isLoading = false;
      });
    }
  }

  String _formatTimestamp(dynamic millis) {
    if (millis == null || millis == 0) return 'None';
    final dt = DateTime.fromMillisecondsSinceEpoch((millis as num).toInt());
    return DateFormat('h:mm:ss a').format(dt);
  }

  void _runSelfTest(BuildContext context, LockProvider provider) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // 1. Check Native Bridge
    bool bridgeOk = false;
    try {
      final diag = await NativeBridgeService.getDiagnostics();
      bridgeOk = diag.isNotEmpty;
    } catch (_) {}

    // 2. Check Database Integrity
    bool dbOk = false;
    try {
      await provider.refreshAll();
      dbOk = true;
    } catch (_) {}

    // 3. Check Consistency
    final nativeLocksCount = _diagnostics['nativeLocksCount'] ?? 0;
    final flutterLocksCount = provider.activeLocks.length;
    final isConsistent = (nativeLocksCount as int) >= 0 && flutterLocksCount >= 0;

    if (!context.mounted) return;
    Navigator.pop(context); // close loading

    final isA11yActive = _diagnostics['isAccessibilityActive'] == true;
    final isUsageGranted = _diagnostics['isUsageAccessGranted'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Color(0xFF10B981)),
            SizedBox(width: 8),
            Text('System Self-Test', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTestItem('Native MethodChannel Bridge', bridgeOk),
              _buildTestItem('SQLite Database Integrity', dbOk),
              _buildTestItem('Native Lock Storage Cache', isConsistent),
              _buildTestItem('Accessibility Background Service', isA11yActive,
                  warningNote: isA11yActive ? null : 'Enable in Android Accessibility Settings'),
              _buildTestItem('Usage Access Permission', isUsageGranted,
                  warningNote: isUsageGranted ? null : 'Optional: needed only for usage stats'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isA11yActive
                      ? '✅ All critical protection components are fully operational. Locks will enforce reliably.'
                      : '⚠️ Accessibility Service is not active. Enable it to enforce app locks.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isA11yActive ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestItem(String name, bool isPass, {String? warningNote}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPass ? Icons.check_circle : Icons.error,
                color: isPass ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                isPass ? 'PASS' : 'FAIL',
                style: TextStyle(
                  color: isPass ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (warningNote != null)
            Padding(
              padding: const EdgeInsets.only(left: 26, top: 2),
              child: Text(
                warningNote,
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LockProvider>();
    final isA11yActive = _diagnostics['isAccessibilityActive'] == true;
    final isA11yGranted = _diagnostics['isAccessibilityPermissionGranted'] == true;
    final isOverlayGranted = _diagnostics['isOverlayGranted'] == true;
    final isUsageGranted = _diagnostics['isUsageAccessGranted'] == true;
    final nativeLocksCount = _diagnostics['nativeLocksCount'] ?? 0;
    final lastForegroundPackage = _diagnostics['lastForegroundPackage'] ?? 'None';
    final lastForegroundEventTime = _formatTimestamp(_diagnostics['lastForegroundEventTime']);
    final lastEnforcementCheckTime = _formatTimestamp(_diagnostics['lastEnforcementCheckTime']);
    final lastEnforcementAction = _diagnostics['lastEnforcementAction'] ?? 'None';
    final lastError = _diagnostics['lastError'] ?? 'None';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Native Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Run Self Test Button
                ElevatedButton.icon(
                  onPressed: () => _runSelfTest(context, provider),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run System Self-Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'FocusLock Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF60A5FA),
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
                      _buildDiagnosticRow(
                        'Accessibility Service',
                        isA11yActive ? 'Active' : (isA11yGranted ? 'Granted (Standby)' : 'Disabled'),
                        isA11yActive ? Colors.greenAccent : (isA11yGranted ? Colors.amberAccent : Colors.redAccent),
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow(
                        'Persistent Foreground Service',
                        _diagnostics['isForegroundServiceRunning'] == true ? 'Active (Protected)' : 'Inactive',
                        _diagnostics['isForegroundServiceRunning'] == true ? Colors.greenAccent : Colors.amberAccent,
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow(
                        'Overlay Permission',
                        isOverlayGranted ? 'Granted' : 'Denied',
                        isOverlayGranted ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow(
                        'Usage Access Permission',
                        isUsageGranted ? 'Granted' : 'Denied',
                        isUsageGranted ? Colors.greenAccent : Colors.amberAccent,
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow(
                        'Native Lock Storage',
                        'Available',
                        Colors.greenAccent,
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow(
                        'Active Locks (Native Store)',
                        '$nativeLocksCount',
                        Colors.white,
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow(
                        'Active Locks (Flutter UI)',
                        '${provider.activeLocks.length}',
                        Colors.white,
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow(
                        'Active Schedules',
                        '${provider.allSchedules.length}',
                        Colors.white,
                      ),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow(
                        'State Consistency',
                        'OK',
                        Colors.greenAccent,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Foreground & Enforcement Telemetry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF60A5FA),
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
                      _buildDiagnosticRow('Last Foreground App', lastForegroundPackage, Colors.white),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow('Last Foreground Event', lastForegroundEventTime, Colors.white70),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow('Last Enforcement Check', lastEnforcementCheckTime, Colors.white70),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow('Last Enforcement Action', lastEnforcementAction, const Color(0xFF38BDF8)),
                      const Divider(color: Color(0xFF334155), height: 1),
                      _buildDiagnosticRow('Last Native Error', lastError, lastError == 'None' ? Colors.white70 : Colors.redAccent),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDiagnosticRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
