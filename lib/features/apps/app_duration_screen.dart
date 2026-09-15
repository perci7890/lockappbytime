import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:applockbytime/data/models/app_info.dart';
import 'package:applockbytime/features/apps/app_lock_confirm_screen.dart';
import 'package:applockbytime/features/apps/widgets/app_icon_widget.dart';
import 'package:applockbytime/features/home/providers/lock_provider.dart';

enum LockModeType { quick, untilTomorrow, schedule }

class AppDurationScreen extends StatefulWidget {
  final AppInfo app;

  const AppDurationScreen({super.key, required this.app});

  @override
  State<AppDurationScreen> createState() => _AppDurationScreenState();
}

class _AppDurationScreenState extends State<AppDurationScreen> {
  LockModeType _lockMode = LockModeType.quick;

  // Quick Lock State
  int _selectedHours = 0;
  int _selectedMinutes = 30;

  // Schedule Lock State
  TimeOfDay _startTime = const TimeOfDay(hour: 20, minute: 0); // 8:00 PM
  TimeOfDay _endTime = const TimeOfDay(hour: 22, minute: 0);   // 10:00 PM
  String _repeatType = 'everyday'; // 'everyday', 'weekdays', 'weekends', 'custom'
  final Set<int> _customDays = {2, 3, 4, 5, 6}; // Mon-Fri (1=Sun, 2=Mon... in Calendar)

  final List<DurationPreset> _presets = [
    DurationPreset(label: '5m', hours: 0, minutes: 5),
    DurationPreset(label: '15m', hours: 0, minutes: 15),
    DurationPreset(label: '30m', hours: 0, minutes: 30),
    DurationPreset(label: '45m', hours: 0, minutes: 45),
    DurationPreset(label: '1h', hours: 1, minutes: 0),
    DurationPreset(label: '2h', hours: 2, minutes: 0),
    DurationPreset(label: '4h', hours: 4, minutes: 0),
    DurationPreset(label: '8h', hours: 8, minutes: 0),
    DurationPreset(label: '12h', hours: 12, minutes: 0),
    DurationPreset(label: '24h', hours: 24, minutes: 0),
  ];

  int get _totalMinutes => (_selectedHours * 60) + _selectedMinutes;

  bool get _isValidDuration {
    return _totalMinutes >= 1 && _totalMinutes <= (24 * 60);
  }

  String _formatDurationString() {
    if (_selectedHours == 24 && _selectedMinutes == 0) return '24 hours';
    final parts = <String>[];
    if (_selectedHours > 0) parts.add('$_selectedHours hour${_selectedHours > 1 ? 's' : ''}');
    if (_selectedMinutes > 0) parts.add('$_selectedMinutes minute${_selectedMinutes > 1 ? 's' : ''}');
    if (parts.isEmpty) return '0 minutes';
    return parts.join(' ');
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lock Configuration'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Target App Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      AppIconWidget(base64Icon: widget.app.iconBase64, size: 56),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.app.appName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.app.packageName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Lock Type Selector Segmented Tabs
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(6),
                child: Row(
                  children: [
                    _buildTabOption(LockModeType.quick, 'Quick Lock'),
                    _buildTabOption(LockModeType.untilTomorrow, 'Tomorrow'),
                    _buildTabOption(LockModeType.schedule, 'Schedule'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              if (_lockMode == LockModeType.quick) _buildQuickLockSection(),
              if (_lockMode == LockModeType.untilTomorrow) _buildUntilTomorrowSection(),
              if (_lockMode == LockModeType.schedule) _buildScheduleSection(),

              const SizedBox(height: 32),

              // Action Button
              ElevatedButton(
                onPressed: _handleContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF2563EB),
                ),
                child: Text(
                  _lockMode == LockModeType.schedule ? 'Save Schedule' : 'Continue',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabOption(LockModeType mode, String label) {
    final isSelected = _lockMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _lockMode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLockSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isValidDuration
                  ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                  : Colors.redAccent.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            children: [
              const Text('Duration', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                _formatDurationString(),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _isValidDuration ? const Color(0xFF60A5FA) : Colors.redAccent,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text('Quick Presets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.map((preset) {
            final isSelected = _selectedHours == preset.hours && _selectedMinutes == preset.minutes;
            return ChoiceChip(
              label: Text(preset.label),
              selected: isSelected,
              selectedColor: const Color(0xFF2563EB),
              backgroundColor: const Color(0xFF1E293B),
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedHours = preset.hours;
                    _selectedMinutes = preset.minutes;
                  });
                }
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),
        const Text('Custom Duration (Hours & Minutes)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 12),

        Container(
          height: 170,
          decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: _selectedHours),
                  itemExtent: 44,
                  onSelectedItemChanged: (val) {
                    setState(() {
                      _selectedHours = val;
                      if (_selectedHours == 24) _selectedMinutes = 0;
                    });
                  },
                  children: List.generate(25, (i) => Center(child: Text('$i h', style: const TextStyle(color: Colors.white)))),
                ),
              ),
              const VerticalDivider(color: Color(0xFF334155), width: 1),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(initialItem: _selectedMinutes),
                  itemExtent: 44,
                  onSelectedItemChanged: (val) {
                    setState(() {
                      if (_selectedHours == 24) {
                        _selectedMinutes = 0;
                      } else {
                        _selectedMinutes = val;
                      }
                    });
                  },
                  children: List.generate(60, (i) => Center(child: Text('$i m', style: const TextStyle(color: Colors.white)))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUntilTomorrowSection() {
    final now = DateTime.now();
    final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final hours = tomorrowMidnight.difference(now).inHours;
    final mins = tomorrowMidnight.difference(now).inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.nightlight_round, size: 48, color: Color(0xFF60A5FA)),
          const SizedBox(height: 16),
          const Text(
            'Lock Until Tomorrow',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.app.appName} will be locked from right now until 12:00 AM midnight tomorrow.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Unlocks at:', style: TextStyle(color: Colors.white60)),
                Text(
                  '12:00 AM (~${hours}h ${mins}m)',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    final isOvernight = (_endTime.hour * 60 + _endTime.minute) <= (_startTime.hour * 60 + _startTime.minute);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Time pickers
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickTime(true),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Start Time', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        _startTime.format(context),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _pickTime(false),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('End Time', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(
                        _endTime.format(context),
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        if (isOvernight) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '🌙 Overnight schedule (crosses midnight into the next day)',
              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
            ),
          ),
        ],

        const SizedBox(height: 24),
        const Text('Repeat Days', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          children: [
            _buildRepeatChip('everyday', 'Every day'),
            _buildRepeatChip('weekdays', 'Weekdays'),
            _buildRepeatChip('weekends', 'Weekends'),
            _buildRepeatChip('custom', 'Custom'),
          ],
        ),

        if (_repeatType == 'custom') ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDayToggle('M', 2),
              _buildDayToggle('T', 3),
              _buildDayToggle('W', 4),
              _buildDayToggle('T', 5),
              _buildDayToggle('F', 6),
              _buildDayToggle('S', 7),
              _buildDayToggle('S', 1),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRepeatChip(String key, String label) {
    final isSelected = _repeatType == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: const Color(0xFF1E293B),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
      onSelected: (selected) {
        if (selected) setState(() => _repeatType = key);
      },
    );
  }

  Widget _buildDayToggle(String label, int calendarDay) {
    final isSelected = _customDays.contains(calendarDay);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            if (_customDays.length > 1) _customDays.remove(calendarDay);
          } else {
            _customDays.add(calendarDay);
          }
        });
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
          border: Border.all(color: isSelected ? const Color(0xFF60A5FA) : const Color(0xFF334155)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white60),
          ),
        ),
      ),
    );
  }

  void _handleContinue() async {
    if (_lockMode == LockModeType.quick) {
      if (!_isValidDuration) return;
      final duration = Duration(hours: _selectedHours, minutes: _selectedMinutes);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppLockConfirmScreen(app: widget.app, duration: duration),
        ),
      );
    } else if (_lockMode == LockModeType.untilTomorrow) {
      final now = DateTime.now();
      final tomorrowMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
      final duration = tomorrowMidnight.difference(now);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppLockConfirmScreen(app: widget.app, duration: duration),
        ),
      );
    } else {
      // Schedule Lock
      final startMins = _startTime.hour * 60 + _startTime.minute;
      final endMins = _endTime.hour * 60 + _endTime.minute;

      if (startMins == endMins) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Start time and End time cannot be the same.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      final daysStr = _repeatType == 'custom' ? _customDays.join(',') : _repeatType;

      final provider = context.read<LockProvider>();
      await provider.saveSchedule(
        app: widget.app,
        startMinutes: startMins,
        endMinutes: endMins,
        daysOfWeek: daysStr,
      );

      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Schedule saved for ${widget.app.appName}'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      }
    }
  }
}

class DurationPreset {
  final String label;
  final int hours;
  final int minutes;

  DurationPreset({required this.label, required this.hours, required this.minutes});
}
