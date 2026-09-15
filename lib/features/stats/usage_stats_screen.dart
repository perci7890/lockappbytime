import 'package:flutter/material.dart';
import 'package:applockbytime/core/services/native_bridge_service.dart';

class UsageStatsScreen extends StatefulWidget {
  const UsageStatsScreen({super.key});

  @override
  State<UsageStatsScreen> createState() => _UsageStatsScreenState();
}

class _UsageStatsScreenState extends State<UsageStatsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _hasPermission = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _stats = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadStats();
      }
    });
    _checkPermissionAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionAndLoad() async {
    setState(() => _isLoading = true);
    final granted = await NativeBridgeService.hasUsageStatsPermission();
    if (mounted) {
      setState(() {
        _hasPermission = granted;
      });
      if (granted) {
        _loadStats();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final days = _tabController.index == 0 ? 0 : (_tabController.index == 1 ? 1 : 7);
    final result = await NativeBridgeService.getUsageStats(days: days);
    if (mounted) {
      setState(() {
        _stats = result;
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int millis) {
    final secs = millis ~/ 1000;
    final hours = secs ~/ 3600;
    final mins = (secs % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  int get _totalTimeMillis {
    return _stats.fold(0, (acc, item) => acc + (item['totalTimeForegroundMillis'] as int? ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Statistics'),
        bottom: _hasPermission
            ? TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF3B82F6),
                tabs: const [
                  Tab(text: 'Today'),
                  Tab(text: 'Yesterday'),
                  Tab(text: 'Past 7 Days'),
                ],
              )
            : null,
      ),
      body: !_hasPermission
          ? _buildPermissionPrompt()
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Total Usage Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Screen Time', style: TextStyle(color: Colors.white60, fontSize: 13)),
                                SizedBox(height: 4),
                                Text('Across all apps', style: TextStyle(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                            Text(
                              _formatDuration(_totalTimeMillis),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF60A5FA),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        'Application Usage',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),

                      if (_stats.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: Text('No application usage recorded for this period', style: TextStyle(color: Colors.white54)),
                          ),
                        )
                      else
                        ..._stats.take(20).map((item) {
                          final appName = item['appName'] as String;
                          final pkg = item['packageName'] as String;
                          final timeMillis = item['totalTimeForegroundMillis'] as int;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: const Color(0xFF334155),
                                  child: Text(appName.isNotEmpty ? appName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(appName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                      Text(pkg, style: const TextStyle(fontSize: 11, color: Colors.white38), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatDuration(timeMillis),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 24),
                      // Privacy Note
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.privacy_tip_outlined, size: 20, color: Color(0xFF38BDF8)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Privacy Guaranteed: App usage statistics are queried directly on your device and are never transmitted to external servers.',
                                style: TextStyle(fontSize: 11, color: Colors.white60),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildPermissionPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Color(0xFF60A5FA)),
            const SizedBox(height: 20),
            const Text(
              'Usage Access Required',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            const Text(
              'To view app usage history and screen time statistics, Android requires Usage Access permission.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: () async {
                await NativeBridgeService.openUsageAccessSettings();
                await Future.delayed(const Duration(seconds: 1));
                _checkPermissionAndLoad();
              },
              icon: const Icon(Icons.security),
              label: const Text('Enable Usage Access'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }
}
