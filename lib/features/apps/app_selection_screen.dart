import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:applockbytime/data/models/app_info.dart';
import 'package:applockbytime/features/apps/app_duration_screen.dart';
import 'package:applockbytime/features/apps/widgets/app_icon_widget.dart';
import 'package:applockbytime/features/home/providers/lock_provider.dart';

class AppSelectionScreen extends StatefulWidget {
  final List<AppInfo> apps;
  final Set<String> currentlyLockedPackages;

  const AppSelectionScreen({
    super.key,
    required this.apps,
    required this.currentlyLockedPackages,
  });

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleAppSelection(BuildContext context, AppInfo app) {
    final provider = context.read<LockProvider>();
    final isLocked = provider.isAppLocked(app.packageName);

    if (isLocked) {
      final lock = provider.activeLocks.firstWhere((l) => l.packageName == app.packageName);
      final remaining = lock.remainingDuration;
      final remainingMins = remaining.inMinutes;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            '${app.appName} is Already Locked',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: Text(
            'Current lock has approximately $remainingMins minute${remainingMins != 1 ? 's' : ''} remaining.\n\nWhat would you like to do?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Existing Lock', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AppDurationScreen(app: app)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              child: const Text('Replace With New Duration'),
            ),
          ],
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AppDurationScreen(app: app)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LockProvider>();
    final lockedPackages = provider.activeLocks
        .where((l) => l.isCurrentlyLocked)
        .map((l) => l.packageName)
        .toSet();

    final filteredApps = widget.apps.where((app) {
      final matchesQuery = app.appName
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose App to Lock'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search installed apps...',
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filteredApps.isEmpty
                ? const Center(
                    child: Text(
                      'No matching apps found',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredApps.length,
                    separatorBuilder: (context, index) => const Divider(
                      color: Color(0xFF1E293B),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final isLocked = lockedPackages.contains(app.packageName);

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        leading: AppIconWidget(
                          base64Icon: app.iconBase64,
                          size: 48,
                        ),
                        title: Text(
                          app.appName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          app.packageName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isLocked
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.redAccent),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock, size: 14, color: Colors.redAccent),
                                    SizedBox(width: 4),
                                    Text(
                                      'Locked',
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.white38,
                              ),
                        onTap: () => _handleAppSelection(context, app),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
