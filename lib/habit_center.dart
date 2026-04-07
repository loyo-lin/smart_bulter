import 'package:flutter/material.dart';

import 'habit_models.dart';

class HabitCenterPage extends StatefulWidget {
  const HabitCenterPage({
    super.key,
    this.title = 'Growth Center',
    required this.habits,
    required this.streaks,
    required this.events,
    required this.onCheckIn,
    required this.onUndoCheckIn,
    required this.onSave,
    required this.onDelete,
  });

  final String title;
  final List<HabitItemModel> habits;
  final List<StreakItem> streaks;
  final List<ProgressEvent> events;
  final Future<HabitMutationResult> Function(String habitKey) onCheckIn;
  final Future<HabitMutationResult> Function(String habitKey) onUndoCheckIn;
  final Future<void> Function(HabitItemModel habit) onSave;
  final Future<void> Function(String habitKey) onDelete;

  @override
  State<HabitCenterPage> createState() => _HabitCenterPageState();
}

class _HabitCenterPageState extends State<HabitCenterPage> {
  late List<HabitItemModel> _habits;
  late List<StreakItem> _streaks;
  late List<ProgressEvent> _events;
  bool _isMutating = false;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _habits = widget.habits;
    _streaks = widget.streaks;
    _events = widget.events;
  }

  String get _today => DateTime.now().toIso8601String().split('T').first;

  String _dateKey(DateTime day) {
    final year = day.year.toString().padLeft(4, '0');
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '$year-$month-$date';
  }

  Set<String> get _habitKeys => _habits.map((habit) => habit.habitKey).toSet();

  List<ProgressEvent> _eventsForDay(DateTime day) {
    final key = _dateKey(day);
    final habitKeys = _habitKeys;
    return _events
        .where(
          (event) =>
              event.eventDate == key && habitKeys.contains(event.statKey),
        )
        .toList();
  }

  String _habitTitle(String habitKey) {
    for (final habit in _habits) {
      if (habit.habitKey == habitKey) return habit.title;
    }
    return habitKey;
  }

  Map<String, int> _todayCounts() {
    final counts = <String, int>{};
    for (final event in _events) {
      if (event.eventDate != _today) continue;
      counts[event.statKey] = (counts[event.statKey] ?? 0) + 1;
    }
    return counts;
  }

  int _streakFor(String habitKey) {
    for (final item in _streaks) {
      if (item.statKey == habitKey) return item.count;
    }
    return 0;
  }

  Future<void> _createHabit() async {
    final created = await showDialog<HabitItemModel>(
      context: context,
      builder: (context) => const HabitEditorDialog(),
    );
    if (created == null) return;

    await widget.onSave(created);
    if (!mounted) return;
    setState(() {
      _habits = [..._habits, created];
    });
  }

  Future<void> _checkIn(HabitItemModel habit) async {
    if (_isMutating) return;
    setState(() {
      _isMutating = true;
    });
    try {
      final result = await widget.onCheckIn(habit.habitKey);
      if (!mounted) return;
      setState(() {
        _streaks = result.streaks;
        _events = result.events;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Checked in: ${habit.title}')));
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _undoCheckIn(HabitItemModel habit) async {
    if (_isMutating) return;
    final todayCount = _todayCounts()[habit.habitKey] ?? 0;
    if (todayCount == 0) return;

    setState(() {
      _isMutating = true;
    });
    try {
      final result = await widget.onUndoCheckIn(habit.habitKey);
      if (!mounted) return;
      setState(() {
        _streaks = result.streaks;
        _events = result.events;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed one: ${habit.title}')));
    } finally {
      if (mounted) {
        setState(() {
          _isMutating = false;
        });
      }
    }
  }

  Future<void> _deleteHabit(HabitItemModel habit) async {
    await widget.onDelete(habit.habitKey);
    if (!mounted) return;
    setState(() {
      _habits = _habits
          .where((item) => item.habitKey != habit.habitKey)
          .toList();
      _events = _events
          .where((item) => item.statKey != habit.habitKey)
          .toList();
      _streaks = _streaks
          .where((item) => item.statKey != habit.habitKey)
          .toList();
    });
  }

  void _moveMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _showDayDetails(DateTime day) {
    final events = _eventsForDay(day);
    final counts = <String, int>{};
    for (final event in events) {
      counts[event.statKey] = (counts[event.statKey] ?? 0) + 1;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_dateKey(day)),
        content: counts.isEmpty
            ? const Text('No check-ins.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: counts.entries.map((entry) {
                  return ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(_habitTitle(entry.key)),
                    trailing: Text('x${entry.value}'),
                  );
                }).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final leadingEmptyCells = firstDay.weekday % 7;
    final totalCells = leadingEmptyCells + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final todayKey = _today;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${_visibleMonth.year}-${_visibleMonth.month.toString().padLeft(2, '0')}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _moveMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: const [
                Expanded(child: Center(child: Text('Sun'))),
                Expanded(child: Center(child: Text('Mon'))),
                Expanded(child: Center(child: Text('Tue'))),
                Expanded(child: Center(child: Text('Wed'))),
                Expanded(child: Center(child: Text('Thu'))),
                Expanded(child: Center(child: Text('Fri'))),
                Expanded(child: Center(child: Text('Sat'))),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemBuilder: (context, index) {
                final dayNumber = index - leadingEmptyCells + 1;
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final day = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month,
                  dayNumber,
                );
                final events = _eventsForDay(day);
                final isToday = _dateKey(day) == todayKey;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showDayDetails(day),
                  child: Container(
                    decoration: BoxDecoration(
                      color: events.isEmpty
                          ? Colors.transparent
                          : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isToday ? Colors.teal : Colors.grey.shade300,
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (events.isNotEmpty)
                          Text(
                            '${events.length}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.teal.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayCounts = _todayCounts();
    final activeHabits = _habits.where((item) => item.enabled).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createHabit),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (activeHabits.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('No habits yet'),
                subtitle: Text('Add one habit and tap it when you finish.'),
              ),
            )
          else
            ...activeHabits.map((habit) {
              final todayCount = todayCounts[habit.habitKey] ?? 0;
              final streak = _streakFor(habit.habitKey);
              final achievement = habitAchievementFor(streak);
              return Card(
                child: ListTile(
                  leading: Icon(habitIconFromKey(habit.icon)),
                  title: Text(habit.title),
                  subtitle: Text(
                    [
                      'Today x$todayCount',
                      '$streak days',
                      if (achievement.isNotEmpty) achievement,
                    ].join(' • '),
                  ),
                  onTap: _isMutating ? null : () => _checkIn(habit),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Check in',
                        icon: const Icon(Icons.add_task),
                        onPressed: _isMutating ? null : () => _checkIn(habit),
                      ),
                      IconButton(
                        tooltip: 'Undo one check-in',
                        icon: const Icon(Icons.undo),
                        onPressed: _isMutating || todayCount == 0
                            ? null
                            : () => _undoCheckIn(habit),
                      ),
                      IconButton(
                        tooltip: 'Delete habit',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _isMutating
                            ? null
                            : () => _deleteHabit(habit),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Calendar',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          _buildCalendar(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createHabit,
        icon: const Icon(Icons.add),
        label: const Text('Add Habit'),
      ),
    );
  }
}

class HabitEditorDialog extends StatefulWidget {
  const HabitEditorDialog({super.key});

  @override
  State<HabitEditorDialog> createState() => _HabitEditorDialogState();
}

class _HabitEditorDialogState extends State<HabitEditorDialog> {
  final TextEditingController _titleController = TextEditingController();
  String _icon = 'check_circle';

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final key = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    Navigator.of(context).pop(
      HabitItemModel(
        habitKey: key.isEmpty
            ? 'habit_${DateTime.now().millisecondsSinceEpoch}'
            : key,
        title: title,
        icon: _icon,
        category: 'habit',
        enabled: true,
        isCustom: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Habit'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Habit',
              hintText: 'Read 20 min',
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _icon,
            decoration: const InputDecoration(labelText: 'Icon'),
            items: const [
              DropdownMenuItem(value: 'check_circle', child: Text('Check')),
              DropdownMenuItem(value: 'local_drink', child: Text('Water')),
              DropdownMenuItem(
                value: 'self_improvement',
                child: Text('Stretch'),
              ),
              DropdownMenuItem(value: 'menu_book', child: Text('Book')),
              DropdownMenuItem(value: 'directions_walk', child: Text('Walk')),
              DropdownMenuItem(value: 'bedtime', child: Text('Sleep')),
              DropdownMenuItem(
                value: 'record_voice_over',
                child: Text('Speaking'),
              ),
              DropdownMenuItem(value: 'fitness_center', child: Text('Gym')),
              DropdownMenuItem(value: 'spa', child: Text('Relax')),
              DropdownMenuItem(value: 'psychology', child: Text('Mind')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _icon = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Add Habit')),
      ],
    );
  }
}
