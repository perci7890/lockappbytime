import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:applockbytime/features/home/providers/lock_provider.dart';

class FocusModesScreen extends StatelessWidget {
  const FocusModesScreen({super.key});

  void _showCreateDialog(BuildContext context) {
    final provider = context.read<LockProvider>();
    final nameController = TextEditingController(text: 'Study');
    String selectedIcon = '📚';
    int durationMinutes = 60;
    final selectedPackages = <String>{};

    final icons = ['📚', '🌙', '💼', '🧘', '🎯', '🚀', '🏋️'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Focus Mode', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Focus Name',
                    hintText: 'e.g. Study, Work, Sleep',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Choose Icon', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: icons.map((icon) {
                    final isSel = selectedIcon == icon;
                    return GestureDetector(
                      onTap: () => setState(() => selectedIcon = icon),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel ? const Color(0xFF2563EB) : const Color(0xFF334155),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Default Duration', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [30, 60, 120, 240].map((mins) {
                    final isSel = durationMinutes == mins;
                    return ChoiceChip(
                      label: Text('${mins ~/ 60 > 0 ? '${mins ~/ 60}h ' : ''}${mins % 60 > 0 ? '${mins % 60}m' : ''}'),
                      selected: isSel,
                      selectedColor: const Color(0xFF2563EB),
                      backgroundColor: const Color(0xFF334155),
                      onSelected: (val) {
                        if (val) setState(() => durationMinutes = mins);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Select Apps to Group', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 150,
                  child: ListView(
                    children: provider.installedApps.map((app) {
                      final isChecked = selectedPackages.contains(app.packageName);
                      return CheckboxListTile(
                        value: isChecked,
                        dense: true,
                        title: Text(app.appName, style: const TextStyle(color: Colors.white, fontSize: 13)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedPackages.add(app.packageName);
                            } else {
                              selectedPackages.remove(app.packageName);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: selectedPackages.isEmpty
                  ? null
                  : () async {
                      final id = 'focus_${DateTime.now().millisecondsSinceEpoch}';
                      await provider.createFocusMode(
                        id: id,
                        name: nameController.text.trim().isEmpty ? 'Focus' : nameController.text.trim(),
                        icon: selectedIcon,
                        packageNames: selectedPackages.toList(),
                        durationMinutes: durationMinutes,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Create Focus Mode'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus Modes & Groups'),
      ),
      body: Consumer<LockProvider>(
        builder: (context, provider, _) {
          final modes = provider.focusModes;

          if (modes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🎯', style: TextStyle(fontSize: 54)),
                    const SizedBox(height: 16),
                    const Text(
                      'No Focus Modes Yet',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Group multiple distracting apps together (e.g. Study, Work, Sleep) and activate them in one tap.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Focus Mode'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: modes.length,
            separatorBuilder: (context, index) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final mode = modes[index];
              final id = mode['id'] as String;
              final name = mode['name'] as String;
              final icon = mode['icon'] as String;
              final packageCount = (mode['packageNames'] as String).split(',').where((e) => e.isNotEmpty).length;
              final isActive = (mode['isActive'] as int? ?? 0) == 1;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isActive ? const Color(0xFF3B82F6) : const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Text(
                            '$packageCount app${packageCount != 1 ? 's' : ''} • ${isActive ? 'ACTIVE' : 'Inactive'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isActive ? const Color(0xFF60A5FA) : Colors.white54,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (isActive) {
                          await provider.stopFocusMode(id);
                        } else {
                          await provider.startFocusMode(id);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(isActive ? 'Stop' : 'Start'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                      onPressed: () => provider.deleteFocusMode(id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Focus Mode'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }
}
