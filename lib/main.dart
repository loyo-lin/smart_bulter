import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'habit_center.dart';
import 'habit_models.dart';

void main() {
  runApp(const SmartButlerApp());
}

class SmartButlerApp extends StatelessWidget {
  const SmartButlerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Butler',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ButlerTaskConfig {
  const ButlerTaskConfig({
    required this.taskKey,
    required this.title,
    required this.body,
    required this.enabled,
    required this.scheduleType,
    required this.route,
    this.intervalMinutes,
    this.timeOfDay,
  });

  final String taskKey;
  final String title;
  final String body;
  final bool enabled;
  final String scheduleType;
  final int? intervalMinutes;
  final String? timeOfDay;
  final String route;

  factory ButlerTaskConfig.fromJson(Map<String, dynamic> json) {
    return ButlerTaskConfig(
      taskKey: json['task_key']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Reminder',
      body: json['body']?.toString() ?? '',
      enabled: json['enabled'] == true,
      scheduleType: json['schedule_type']?.toString() ?? 'interval',
      intervalMinutes: (json['interval_minutes'] as num?)?.toInt(),
      timeOfDay: json['time_of_day']?.toString(),
      route: json['route']?.toString() ?? 'task',
    );
  }

  ButlerTaskConfig copyWith({
    String? taskKey,
    String? title,
    String? body,
    bool? enabled,
    String? scheduleType,
    int? intervalMinutes,
    String? timeOfDay,
    String? route,
  }) {
    return ButlerTaskConfig(
      taskKey: taskKey ?? this.taskKey,
      title: title ?? this.title,
      body: body ?? this.body,
      enabled: enabled ?? this.enabled,
      scheduleType: scheduleType ?? this.scheduleType,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      route: route ?? this.route,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_key': taskKey,
      'title': title,
      'body': body,
      'enabled': enabled,
      'schedule_type': scheduleType,
      'interval_minutes': intervalMinutes,
      'time_of_day': timeOfDay,
      'route': route,
    };
  }
}

class ButlerSettings {
  const ButlerSettings({
    required this.englishMode,
    required this.proactiveFollowup,
    required this.doNotDisturbStart,
    required this.doNotDisturbEnd,
    required this.bedtimeTime,
  });

  final bool englishMode;
  final bool proactiveFollowup;
  final String doNotDisturbStart;
  final String doNotDisturbEnd;
  final String bedtimeTime;

  factory ButlerSettings.fromJson(Map<String, dynamic> json) {
    return ButlerSettings(
      englishMode: json['english_mode'] == true,
      proactiveFollowup: json['proactive_followup'] == true,
      doNotDisturbStart: json['do_not_disturb_start']?.toString() ?? '23:30',
      doNotDisturbEnd: json['do_not_disturb_end']?.toString() ?? '07:00',
      bedtimeTime: json['bedtime_time']?.toString() ?? '22:30',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'english_mode': englishMode,
      'proactive_followup': proactiveFollowup,
      'do_not_disturb_start': doNotDisturbStart,
      'do_not_disturb_end': doNotDisturbEnd,
      'bedtime_time': bedtimeTime,
    };
  }
}

class MemoryItem {
  const MemoryItem({
    required this.id,
    required this.memoryKey,
    required this.memoryValue,
    required this.category,
  });

  final int id;
  final String memoryKey;
  final String memoryValue;
  final String category;

  factory MemoryItem.fromJson(Map<String, dynamic> json) {
    return MemoryItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      memoryKey: json['memory_key']?.toString() ?? '',
      memoryValue: json['memory_value']?.toString() ?? '',
      category: json['category']?.toString() ?? 'profile',
    );
  }
}

class ProgressSummary {
  const ProgressSummary({
    required this.todayActiveCount,
    required this.longestStreak,
    required this.totalStreakDays,
    required this.consistencyScore,
    required this.totalEvents,
  });

  final int todayActiveCount;
  final int longestStreak;
  final int totalStreakDays;
  final int consistencyScore;
  final int totalEvents;

  factory ProgressSummary.fromJson(Map<String, dynamic> json) {
    return ProgressSummary(
      todayActiveCount: (json['today_active_count'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      totalStreakDays: (json['total_streak_days'] as num?)?.toInt() ?? 0,
      consistencyScore: (json['consistency_score'] as num?)?.toInt() ?? 0,
      totalEvents: (json['total_events'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyActivity {
  const DailyActivity({required this.date, required this.events});

  final String date;
  final int events;

  factory DailyActivity.fromJson(Map<String, dynamic> json) {
    return DailyActivity(
      date: json['date']?.toString() ?? '',
      events: (json['events'] as num?)?.toInt() ?? 0,
    );
  }
}

class BadgeItem {
  const BadgeItem({
    required this.code,
    required this.title,
    required this.unlocked,
    required this.progress,
  });

  final String code;
  final String title;
  final bool unlocked;
  final int progress;

  factory BadgeItem.fromJson(Map<String, dynamic> json) {
    return BadgeItem(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      unlocked: json['unlocked'] == true,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
    );
  }
}

class HeatmapCell {
  const HeatmapCell({
    required this.date,
    required this.count,
    required this.level,
  });

  final String date;
  final int count;
  final int level;

  factory HeatmapCell.fromJson(Map<String, dynamic> json) {
    return HeatmapCell(
      date: json['date']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 0,
    );
  }
}

class FreezeInfo {
  const FreezeInfo({
    required this.tokens,
    required this.usedThisWeek,
    required this.remainingThisWeek,
    required this.weekAnchor,
  });

  final int tokens;
  final int usedThisWeek;
  final int remainingThisWeek;
  final String weekAnchor;

  factory FreezeInfo.fromJson(Map<String, dynamic> json) {
    return FreezeInfo(
      tokens: (json['tokens'] as num?)?.toInt() ?? 1,
      usedThisWeek: (json['used_this_week'] as num?)?.toInt() ?? 0,
      remainingThisWeek: (json['remaining_this_week'] as num?)?.toInt() ?? 1,
      weekAnchor: json['week_anchor']?.toString() ?? '',
    );
  }
}

class WeekReport {
  const WeekReport({
    required this.weekStart,
    required this.weekEnd,
    required this.activeDays,
    required this.completionRate,
  });

  final String weekStart;
  final String weekEnd;
  final int activeDays;
  final int completionRate;

  factory WeekReport.fromJson(Map<String, dynamic> json) {
    return WeekReport(
      weekStart: json['week_start']?.toString() ?? '',
      weekEnd: json['week_end']?.toString() ?? '',
      activeDays: (json['active_days'] as num?)?.toInt() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toInt() ?? 0,
    );
  }
}

class PhraseCardItem {
  const PhraseCardItem({
    required this.id,
    required this.phrase,
    required this.scene,
    required this.note,
    required this.createdAt,
  });

  final int id;
  final String phrase;
  final String scene;
  final String note;
  final String createdAt;

  factory PhraseCardItem.fromJson(Map<String, dynamic> json) {
    return PhraseCardItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      phrase: json['phrase']?.toString() ?? '',
      scene: json['scene']?.toString() ?? 'general',
      note: json['note']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class StatsSnapshot {
  const StatsSnapshot({
    required this.streaks,
    required this.summary,
    required this.dailyActivity,
    required this.events,
    required this.badges,
    required this.heatmap,
    required this.freezeInfo,
    required this.weekReport,
  });

  final List<StreakItem> streaks;
  final ProgressSummary summary;
  final List<DailyActivity> dailyActivity;
  final List<ProgressEvent> events;
  final List<BadgeItem> badges;
  final List<HeatmapCell> heatmap;
  final FreezeInfo freezeInfo;
  final WeekReport weekReport;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final Map<String, Timer> _taskTimers = {};

  static const String _apiFromDefine = String.fromEnvironment('API_BASE_URL');
  static const String _prodApiDefault =
      'https://your-api-domain.example.com/api';
  final String apiBaseUrl = _apiFromDefine.isNotEmpty
      ? _apiFromDefine
      : (kReleaseMode ? _prodApiDefault : 'http://10.0.2.2:8000/api');

  bool _isLoading = false;
  int _currentQuota = 0;
  List<ButlerTaskConfig> _tasks = const [];
  List<HabitItemModel> _habits = const [];
  ButlerSettings? _settings;
  List<MemoryItem> _memories = const [];
  List<StreakItem> _streaks = const [];
  ProgressSummary _progressSummary = const ProgressSummary(
    todayActiveCount: 0,
    longestStreak: 0,
    totalStreakDays: 0,
    consistencyScore: 0,
    totalEvents: 0,
  );
  List<DailyActivity> _dailyActivity = const [];
  List<ProgressEvent> _progressEvents = const [];
  List<BadgeItem> _badgeItems = const [];
  List<HeatmapCell> _heatmap = const [];
  FreezeInfo _freezeInfo = const FreezeInfo(
    tokens: 1,
    usedThisWeek: 0,
    remainingThisWeek: 1,
    weekAnchor: '',
  );
  WeekReport _weekReport = const WeekReport(
    weekStart: '',
    weekEnd: '',
    activeDays: 0,
    completionRate: 0,
  );
  List<PhraseCardItem> _phraseCards = const [];
  String? _cachedInspirationDate;
  String? _cachedInspirationBody;
  DateTime? _lastStatsLoadedAt;
  DateTime? _lastHabitsLoadedAt;
  DateTime? _lastPhraseCardsLoadedAt;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _initNotifications();
    await _loadHistory();
    await _loadSettings();
    await _loadTasks();
    await _loadHabits();
    await _loadStats();
  }

  String _cleanContent(String input) {
    var cleaned = input.replaceAll('```', '');
    cleaned = cleaned.replaceAll(RegExp(r'</?note>'), '');
    cleaned = cleaned.replaceAll(RegExp(r'<[^>\n]+>'), '');
    cleaned = cleaned.replaceAll('`', '');
    return cleaned.trim();
  }

  Map<String, String> _toDisplayMessage({
    required String role,
    required String content,
    required String time,
  }) {
    if (role == 'user' && content.startsWith('I am practicing English.')) {
      return {
        'role': role,
        'content': 'English practice request',
        'hidden_prompt': content,
        'time': time,
      };
    }
    if (role == 'user' &&
        content.contains(
          'Please give me a concise night reflection using 4 sections',
        )) {
      return {
        'role': role,
        'content': 'Night reflection request',
        'hidden_prompt': content,
        'time': time,
      };
    }
    return {'role': role, 'content': content, 'time': time};
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/history'));

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final historyList = data['history'] as List? ?? [];

        setState(() {
          _currentQuota = (data['quota'] as num?)?.toInt() ?? 0;
          _messages
            ..clear()
            ..addAll(
              historyList.map(
                (item) => _toDisplayMessage(
                  role: item['role'].toString(),
                  content: _cleanContent(item['content'].toString()),
                  time: item['time']?.toString() ?? '',
                ),
              ),
            );
        });
        _scrollToBottom(jump: true);
      }
    } catch (e) {
      debugPrint('Failed to load history: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTasks() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/tasks'));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final taskList = data['tasks'] as List? ?? [];

      if (!mounted) return;
      setState(() {
        _tasks = taskList
            .map(
              (item) => ButlerTaskConfig.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      });
      _rescheduleTasks();
    } catch (e) {
      debugPrint('Failed to load tasks: $e');
    }
  }

  Future<String?> _fetchTodayInspirationBody() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    if (_cachedInspirationDate == today && _cachedInspirationBody != null) {
      return _cachedInspirationBody;
    }
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/inspiration/today'),
      );
      if (response.statusCode != 200) return null;
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final body = data['body']?.toString().trim();
      if (body == null || body.isEmpty) return null;
      _cachedInspirationDate = today;
      _cachedInspirationBody = body;
      return body;
    } catch (e) {
      debugPrint('Failed to load daily inspiration: $e');
      return null;
    }
  }

  Future<void> _saveTask(ButlerTaskConfig task) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/tasks'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(task.toJson()),
    );

    if (response.statusCode != 200) {
      throw Exception('Unable to save task: ${response.statusCode}');
    }
  }

  Future<void> _loadHabits() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/habits'));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = data['habits'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _habits = list
            .map(
              (item) => HabitItemModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      });
      _lastHabitsLoadedAt = DateTime.now();
    } catch (e) {
      debugPrint('Failed to load habits: $e');
    }
  }

  Future<void> _saveHabit(HabitItemModel habit) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/habits'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(habit.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to save habit: ${response.statusCode}');
    }
    await _loadHabits();
  }

  Future<void> _deleteHabit(String habitKey) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/habits/$habitKey'),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to delete habit: ${response.statusCode}');
    }
    await _loadHabits();
    await _loadStats();
  }

  HabitMutationResult _currentHabitMutationResult() {
    return HabitMutationResult(
      streaks: List<StreakItem>.from(_streaks),
      events: List<ProgressEvent>.from(_progressEvents),
    );
  }

  Future<HabitMutationResult> _checkInHabit(String habitKey) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/habits/$habitKey/checkin'),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to check in habit: ${response.statusCode}');
    }
    await _loadStats();
    return _currentHabitMutationResult();
  }

  Future<HabitMutationResult> _undoHabitCheckIn(String habitKey) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/habits/$habitKey/checkin'),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to undo habit check-in: ${response.statusCode}');
    }
    await _loadStats();
    return _currentHabitMutationResult();
  }

  Future<void> _deleteTask(String taskKey) async {
    final response = await http.delete(Uri.parse('$apiBaseUrl/tasks/$taskKey'));
    if (response.statusCode != 200) {
      throw Exception('Unable to delete task: ${response.statusCode}');
    }
  }

  Future<void> _loadSettings() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/settings'));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _settings = ButlerSettings.fromJson(
          data['settings'] as Map<String, dynamic>,
        );
      });
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
  }

  Future<void> _saveSettings(ButlerSettings settings) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/settings'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(settings.toJson()),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to save settings: ${response.statusCode}');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/profile'));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = data['memories'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _memories = list
            .map((item) => MemoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      debugPrint('Failed to load profile: $e');
    }
  }

  Future<void> _saveProfileItem({
    required String key,
    required String value,
    required String category,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/profile'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'memory_key': key,
        'memory_value': value,
        'category': category,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to save profile memory: ${response.statusCode}');
    }
  }

  Future<void> _deleteProfileItem(int memoryId) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/profile/$memoryId'),
    );
    if (response.statusCode != 200) {
      throw Exception(
        'Unable to delete profile memory: ${response.statusCode}',
      );
    }
  }

  Future<void> _loadStats() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/stats'));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = data['stats'] as List? ?? [];
      final dailyList = data['daily_activity'] as List? ?? [];
      final eventList = data['events'] as List? ?? [];
      final badgeList = data['badges'] as List? ?? [];
      final heatmapList = data['heatmap'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _streaks = list
            .map((item) => StreakItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _progressSummary = ProgressSummary.fromJson(
          (data['summary'] as Map<String, dynamic>?) ?? const {},
        );
        _dailyActivity = dailyList
            .map((item) => DailyActivity.fromJson(item as Map<String, dynamic>))
            .toList();
        _progressEvents = eventList
            .map((item) => ProgressEvent.fromJson(item as Map<String, dynamic>))
            .toList();
        _badgeItems = badgeList
            .map((item) => BadgeItem.fromJson(item as Map<String, dynamic>))
            .toList();
        _heatmap = heatmapList
            .map((item) => HeatmapCell.fromJson(item as Map<String, dynamic>))
            .toList();
        _freezeInfo = FreezeInfo.fromJson(
          (data['freeze'] as Map<String, dynamic>?) ?? const {},
        );
        _weekReport = WeekReport.fromJson(
          (data['week_report'] as Map<String, dynamic>?) ?? const {},
        );
      });
      _lastStatsLoadedAt = DateTime.now();
    } catch (e) {
      debugPrint('Failed to load stats: $e');
    }
  }

  bool _isFresh(DateTime? last, Duration maxAge) {
    if (last == null) return false;
    return DateTime.now().difference(last) < maxAge;
  }

  Future<void> _loadStatsIfStale({
    Duration maxAge = const Duration(seconds: 20),
  }) async {
    if (_isFresh(_lastStatsLoadedAt, maxAge)) return;
    await _loadStats();
  }

  Future<void> _loadHabitsIfStale({
    Duration maxAge = const Duration(seconds: 30),
  }) async {
    if (_isFresh(_lastHabitsLoadedAt, maxAge)) return;
    await _loadHabits();
  }

  Future<void> _loadPhraseCardsIfStale({
    Duration maxAge = const Duration(seconds: 30),
  }) async {
    if (_isFresh(_lastPhraseCardsLoadedAt, maxAge)) return;
    await _loadPhraseCards();
  }

  StatsSnapshot _currentStatsSnapshot() {
    return StatsSnapshot(
      streaks: List<StreakItem>.from(_streaks),
      summary: _progressSummary,
      dailyActivity: List<DailyActivity>.from(_dailyActivity),
      events: List<ProgressEvent>.from(_progressEvents),
      badges: List<BadgeItem>.from(_badgeItems),
      heatmap: List<HeatmapCell>.from(_heatmap),
      freezeInfo: _freezeInfo,
      weekReport: _weekReport,
    );
  }

  Future<StatsSnapshot> _refreshStatsSnapshot() async {
    await _loadStats();
    return _currentStatsSnapshot();
  }

  Future<StatsSnapshot> _recordProgress({
    required String statKey,
    int count = 1,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/stats/record'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'stat_key': statKey, 'count': count}),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to record progress: ${response.statusCode}');
    }
    return _refreshStatsSnapshot();
  }

  Future<StatsSnapshot> _deleteProgressEvent(int eventId) async {
    final urls = [
      '$apiBaseUrl/stats/events/$eventId',
      '$apiBaseUrl/stats/event/$eventId',
      '$apiBaseUrl/progress/events/$eventId',
    ];

    for (final url in urls) {
      final response = await http.delete(Uri.parse(url));
      if (response.statusCode == 200) {
        return _refreshStatsSnapshot();
      }

      if (response.statusCode == 404) {
        await _loadStats();
        final stillExists = _progressEvents.any((item) => item.id == eventId);
        if (!stillExists) {
          return _currentStatsSnapshot();
        }
      }
    }

    throw Exception('Unable to delete progress event: 404');
  }

  Future<StatsSnapshot> _freezeYesterday(String statKey) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final targetDate =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      Uri.parse('$apiBaseUrl/stats/freeze'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'stat_key': statKey, 'target_date': targetDate}),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to freeze: ${response.statusCode}');
    }
    return _refreshStatsSnapshot();
  }

  Future<StatsSnapshot> _makeupYesterday(String statKey) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final targetDate =
        '${yesterday.year.toString().padLeft(4, '0')}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      Uri.parse('$apiBaseUrl/stats/makeup'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'stat_key': statKey, 'target_date': targetDate}),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to make up: ${response.statusCode}');
    }
    return _refreshStatsSnapshot();
  }

  Future<void> _loadPhraseCards() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/phrase_cards'));
      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = data['cards'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _phraseCards = list
            .map(
              (item) => PhraseCardItem.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      });
      _lastPhraseCardsLoadedAt = DateTime.now();
    } catch (e) {
      debugPrint('Failed to load phrase cards: $e');
    }
  }

  Future<List<PhraseCardItem>> _createPhraseCard({
    required String phrase,
    required String scene,
    String note = '',
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/phrase_cards'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'phrase': phrase, 'scene': scene, 'note': note}),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to save phrase: ${response.statusCode}');
    }
    await _loadPhraseCards();
    return _phraseCards;
  }

  Future<List<PhraseCardItem>> _deletePhraseCard(int cardId) async {
    final response = await http.delete(
      Uri.parse('$apiBaseUrl/phrase_cards/$cardId'),
    );
    if (response.statusCode != 200) {
      throw Exception('Unable to delete phrase: ${response.statusCode}');
    }
    await _loadPhraseCards();
    return _phraseCards;
  }

  Future<void> _initNotifications() async {
    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const settings = InitializationSettings(android: androidSettings);
      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: (notificationResponse) {
          _handleNotificationPayload(notificationResponse.payload);
        },
      );

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  Future<void> _showNotification(
    String title,
    String body,
    int delaySeconds, {
    String route = 'task',
  }) async {
    Future.delayed(Duration(seconds: delaySeconds), () async {
      const androidDetails = AndroidNotificationDetails(
        'butler_channel',
        'Butler Reminders',
        channelDescription: 'Daily reminders sent by Smart Butler',
        importance: Importance.max,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      final payload = jsonEncode({'route': route});

      await _notifications.show(0, title, body, details, payload: payload);
    });
  }

  void _handleNotificationPayload(String? payload) {
    var route = 'task';
    if (payload != null && payload.isNotEmpty) {
      try {
        final parsed = jsonDecode(payload) as Map<String, dynamic>;
        route = parsed['route']?.toString() ?? 'task';
      } catch (_) {
        route = payload;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (route == 'review') {
        _openReviewPage();
      } else {
        _openTaskSettingsPage();
      }
    });
  }

  Future<void> _notifyForTask(ButlerTaskConfig task) async {
    if (task.taskKey == 'daily_inspiration') {
      final body = await _fetchTodayInspirationBody();
      await _showNotification(
        task.title,
        body ?? task.body,
        0,
        route: task.route,
      );
      return;
    }
    await _showNotification(task.title, task.body, 0, route: task.route);
  }

  void _rescheduleTasks() {
    for (final timer in _taskTimers.values) {
      timer.cancel();
    }
    _taskTimers.clear();

    for (final task in _tasks) {
      if (!task.enabled) continue;
      if (task.scheduleType == 'interval') {
        _scheduleIntervalTask(task);
      } else if (task.scheduleType == 'daily') {
        _scheduleDailyTask(task);
      }
    }
  }

  void _scheduleIntervalTask(ButlerTaskConfig task) {
    final interval = task.intervalMinutes;
    if (interval == null || interval <= 0) return;

    final duration = Duration(minutes: interval);
    _taskTimers[task.taskKey] = Timer.periodic(duration, (_) {
      _notifyForTask(task);
    });
  }

  void _scheduleDailyTask(ButlerTaskConfig task) {
    final timeOfDay = task.timeOfDay;
    if (timeOfDay == null || !timeOfDay.contains(':')) return;

    final parts = timeOfDay.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, hour, minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }

    final delay = target.difference(now);
    _taskTimers[task.taskKey] = Timer(delay, () {
      _notifyForTask(task);
      final latestTask = _tasks
          .where((item) => item.taskKey == task.taskKey)
          .firstOrNull;
      if (latestTask != null && latestTask.enabled) {
        _scheduleDailyTask(latestTask);
      }
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await _sendMessageWithText(text);
  }

  Future<void> _sendMessageWithText(
    String text, {
    String? visibleText,
    String? hiddenPrompt,
    String messageType = 'chat',
  }) async {
    final displayMessage = {
      'role': 'user',
      'content': visibleText ?? text,
      'time': _getCurrentTime(),
    };
    if (hiddenPrompt != null) {
      displayMessage['hidden_prompt'] = hiddenPrompt;
    }

    setState(() {
      _messages.add(displayMessage);
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final requestBody = {'message': text, 'message_type': messageType};
      if (visibleText != null) {
        requestBody['visible_text'] = visibleText;
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/chat'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final responseData =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      setState(() {
        if (responseData['quota'] != null) {
          _currentQuota = (responseData['quota'] as num).toInt();
        }

        _messages.add({
          'role': 'assistant',
          'content': _cleanContent('${responseData['reply'] ?? ''}'),
          'time': _getCurrentTime(),
        });
      });
      _scrollToBottom();

      final action = responseData['action'];
      if (action is Map<String, dynamic> && action['type'] == 'notify') {
        await _showNotification(
          '${action['title'] ?? 'Reminder'}',
          '${action['content'] ?? ''}',
          (action['delay_seconds'] as num?)?.toInt() ?? 0,
          route: action['route']?.toString() ?? 'task',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': 'Unable to reach the server right now. Please try again.',
          'time': _getCurrentTime(),
        });
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openTaskSettingsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => TaskSettingsPage(
          tasks: _tasks,
          onSave: _updateTask,
          onDelete: (taskKey) async {
            await _deleteTask(taskKey);
            if (!mounted) return;
            setState(() {
              _tasks = _tasks.where((task) => task.taskKey != taskKey).toList();
            });
            _rescheduleTasks();
          },
          onCreate: (task) async {
            await _saveTask(task);
            if (!mounted) return;
            setState(() {
              _tasks = [..._tasks, task];
            });
            _rescheduleTasks();
          },
        ),
      ),
    );
  }

  Future<void> _openSettingsPage() async {
    final settings = _settings;
    if (settings == null) return;
    final updated = await Navigator.of(context).push<ButlerSettings>(
      MaterialPageRoute<ButlerSettings>(
        builder: (context) => SettingsPage(initialSettings: settings),
      ),
    );
    if (updated == null) return;
    try {
      await _saveSettings(updated);
      if (!mounted) return;
      setState(() {
        _settings = updated;
      });
      await _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save settings: $e')));
    }
  }

  Future<void> _openProfilePage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfilePage(
          memories: _memories,
          onAdd: ({required key, required value, required category}) async {
            await _saveProfileItem(key: key, value: value, category: category);
            await _loadProfile();
          },
          onDelete: (id) async {
            await _deleteProfileItem(id);
            await _loadProfile();
          },
        ),
      ),
    );
  }

  Future<void> _openStatsPage() async {
    await _loadStatsIfStale();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StatsPage(
          streaks: _streaks,
          summary: _progressSummary,
          dailyActivity: _dailyActivity,
          events: _progressEvents,
          badges: _badgeItems,
          heatmap: _heatmap,
          freezeInfo: _freezeInfo,
          weekReport: _weekReport,
          onRecord: (statKey, count) =>
              _recordProgress(statKey: statKey, count: count),
          onDeleteEvent: (eventId) => _deleteProgressEvent(eventId),
          onFreezeYesterday: (statKey) => _freezeYesterday(statKey),
          onMakeupYesterday: (statKey) => _makeupYesterday(statKey),
          onReload: _refreshStatsSnapshot,
        ),
      ),
    );
  }

  Future<void> _openReviewPage() async {
    final reviewData = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute<Map<String, String>>(
        builder: (context) => const ReviewPage(),
      ),
    );
    if (reviewData == null) return;

    final prompt =
        '''
Please give me a concise night reflection using 4 sections:
1) Mood
2) Study
3) Exercise
4) Tomorrow plan

My inputs:
- Mood: ${reviewData['mood'] ?? ''}
- Study: ${reviewData['study'] ?? ''}
- Exercise: ${reviewData['exercise'] ?? ''}
- Tomorrow plan: ${reviewData['tomorrow'] ?? ''}
''';
    await _sendMessageWithText(
      prompt.trim(),
      visibleText: 'Night reflection request',
      hiddenPrompt: prompt.trim(),
      messageType: 'review',
    );
  }

  Future<void> _openEnglishPracticePage({
    bool popFeatureCenterAfterSubmit = false,
  }) async {
    final request = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (context) => EnglishPracticePage(apiBaseUrl: apiBaseUrl),
      ),
    );
    if (request == null) return;
    final submitted = request['submitted'] == true;
    if (!submitted) return;
    final prompt = request['prompt']?.trim() ?? '';
    final preview = request['preview']?.trim() ?? 'English practice request';
    if (prompt.isEmpty) return;
    await _sendMessageWithText(
      prompt,
      visibleText: preview,
      hiddenPrompt: prompt,
      messageType: 'english_practice',
    );
    if (popFeatureCenterAfterSubmit &&
        mounted &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openPhraseBookPage() async {
    await _loadPhraseCardsIfStale();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PhraseBookPage(
          cards: _phraseCards,
          onCreate: ({required phrase, required scene, required note}) =>
              _createPhraseCard(phrase: phrase, scene: scene, note: note),
          onDelete: (id) => _deletePhraseCard(id),
        ),
      ),
    );
  }

  Future<void> _openGrowthCenterPage() async {
    await _loadHabitsIfStale();
    await _loadStatsIfStale();
    await _openHabitCenterPage(title: 'Growth Center');
  }

  Future<void> _openHabitCenterPage({String title = 'Growth Center'}) async {
    await _loadHabitsIfStale();
    await _loadStatsIfStale();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HabitCenterPage(
          title: title,
          habits: _habits,
          streaks: _streaks,
          events: _progressEvents,
          onCheckIn: _checkInHabit,
          onUndoCheckIn: _undoHabitCheckIn,
          onSave: _saveHabit,
          onDelete: _deleteHabit,
        ),
      ),
    );
    await _loadStats();
  }

  Future<void> _handleFeatureAction(String action) async {
    if (action == 'growth' || action == 'today') {
      await _openGrowthCenterPage();
    } else if (action == 'habits') {
      await _openHabitCenterPage();
    } else if (action == 'tasks') {
      await _openTaskSettingsPage();
    } else if (action == 'settings') {
      await _openSettingsPage();
    } else if (action == 'profile') {
      await _openProfilePage();
    } else if (action == 'stats') {
      await _openStatsPage();
    } else if (action == 'review') {
      await _openReviewPage();
    } else if (action == 'english') {
      await _openEnglishPracticePage(popFeatureCenterAfterSubmit: true);
    } else if (action == 'phrases') {
      await _openPhraseBookPage();
    }
  }

  Future<void> _openFeaturePage() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>?>(
      MaterialPageRoute<Map<String, dynamic>?>(
        builder: (context) => FeaturesPage(
          onAction: (action) => _handleFeatureAction(action),
          apiBaseUrl: apiBaseUrl,
        ),
      ),
    );
    if (result == null || result['submitted'] != true) return;
    final prompt = result['prompt']?.toString().trim() ?? '';
    final preview =
        result['preview']?.toString().trim() ?? 'English practice request';
    if (prompt.isEmpty) return;
    await _sendMessageWithText(
      prompt,
      visibleText: preview,
      hiddenPrompt: prompt,
      messageType: 'english_practice',
    );
  }

  String _taskSubtitle(ButlerTaskConfig task) {
    if (task.scheduleType == 'interval') {
      final minutes = task.intervalMinutes ?? 0;
      final unit = minutes == 1 ? 'minute' : 'minutes';
      return 'Every $minutes $unit';
    }
    return 'Daily at ${task.timeOfDay ?? '--:--'}';
  }

  bool _isStructuredHeading(String line) {
    final trimmed = line.trim();
    return RegExp(r'^\d+\)').hasMatch(trimmed) || trimmed.endsWith(':');
  }

  List<String> _extractStructuredBlocks(String text) {
    final lines = text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final blocks = <String>[];
    final current = <String>[];

    for (final line in lines) {
      if (_isStructuredHeading(line)) {
        if (current.isNotEmpty) {
          blocks.add(current.join('\n'));
          current.clear();
        }
        current.add(line);
      } else if (current.isNotEmpty) {
        current.add(line);
      }
    }

    if (current.isNotEmpty) {
      blocks.add(current.join('\n'));
    }
    return blocks;
  }

  Widget _buildAssistantContent(String content) {
    final structured = _extractStructuredBlocks(content);
    if (structured.length < 2) {
      return Text(content, style: const TextStyle(fontSize: 16));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in structured)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.teal.shade100),
            ),
            child: Text(line, style: const TextStyle(fontSize: 15)),
          ),
      ],
    );
  }

  Future<void> _updateTask(ButlerTaskConfig task) async {
    try {
      await _saveTask(task);
      if (!mounted) return;
      setState(() {
        _tasks = _tasks
            .map((item) => item.taskKey == task.taskKey ? task : item)
            .toList();
      });
      _rescheduleTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save task: $e')));
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      final position = _chatScrollController.position.maxScrollExtent;
      if (jump) {
        _chatScrollController.jumpTo(position);
      } else {
        _chatScrollController.animateTo(
          position,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToTop() {
    if (!_chatScrollController.hasClients) return;
    _chatScrollController.animateTo(
      _chatScrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    for (final timer in _taskTimers.values) {
      timer.cancel();
    }
    _chatScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Butler'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: _openFeaturePage,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Remaining quota: $_currentQuota',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_tasks.isNotEmpty)
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: _tasks.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () async {
                        final updated = task.copyWith(enabled: !task.enabled);
                        await _updateTask(updated);
                      },
                      child: Container(
                        width: 210,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        decoration: BoxDecoration(
                          gradient: task.enabled
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFE8FFFA),
                                    Color(0xFFD9F5EE),
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF7F7F7),
                                    Color(0xFFEDEDED),
                                  ],
                                ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: task.enabled
                                ? const Color(0xFF8ED8C6)
                                : Colors.grey.shade300,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: task.enabled
                                  ? const Color(0x220A7E68)
                                  : const Color(0x14000000),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: task.enabled
                                        ? const Color(0xFFBEF0E2)
                                        : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    task.enabled
                                        ? Icons.notifications_active
                                        : Icons.notifications_off,
                                    size: 18,
                                    color: task.enabled
                                        ? const Color(0xFF0A7E68)
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        task.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _taskSubtitle(task),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: task.enabled
                                              ? Colors.black87
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: task.enabled
                                      ? const Color(0xFF0A7E68)
                                      : const Color(0xFF7D7D7D),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  task.enabled ? 'ON' : 'OFF',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser
                              ? Colors.teal.shade100
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUser)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    msg['content'] ?? '',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  if ((msg['hidden_prompt'] ?? '').isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        showDialog<void>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Hidden Prompt'),
                                            content: SingleChildScrollView(
                                              child: Text(
                                                msg['hidden_prompt'] ?? '',
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.of(context).pop(),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: const Text('View prompt'),
                                    ),
                                ],
                              )
                            else
                              _buildAssistantContent(msg['content'] ?? ''),
                            const SizedBox(height: 4),
                            Text(
                              msg['time'] ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'chat_top',
                        onPressed: _scrollToTop,
                        child: const Icon(Icons.vertical_align_top),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'chat_bottom',
                        onPressed: _scrollToBottom,
                        child: const Icon(Icons.vertical_align_bottom),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: _isLoading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class TaskSettingsPage extends StatefulWidget {
  const TaskSettingsPage({
    super.key,
    required this.tasks,
    required this.onSave,
    required this.onDelete,
    required this.onCreate,
  });

  final List<ButlerTaskConfig> tasks;
  final Future<void> Function(ButlerTaskConfig task) onSave;
  final Future<void> Function(String taskKey) onDelete;
  final Future<void> Function(ButlerTaskConfig task) onCreate;

  @override
  State<TaskSettingsPage> createState() => _TaskSettingsPageState();
}

class _TaskSettingsPageState extends State<TaskSettingsPage> {
  late List<ButlerTaskConfig> _draftTasks;

  @override
  void initState() {
    super.initState();
    _draftTasks = List<ButlerTaskConfig>.from(widget.tasks);
  }

  Future<void> _deleteTask(String taskKey) async {
    await widget.onDelete(taskKey);
    if (!mounted) return;
    setState(() {
      _draftTasks = _draftTasks
          .where((task) => task.taskKey != taskKey)
          .toList();
    });
  }

  Future<void> _openTaskEditorPage({ButlerTaskConfig? existing}) async {
    final edited = await Navigator.of(context).push<ButlerTaskConfig>(
      MaterialPageRoute<ButlerTaskConfig>(
        builder: (context) => TaskEditorPage(initialTask: existing),
      ),
    );
    if (edited == null) return;

    if (existing == null) {
      await widget.onCreate(edited);
      if (!mounted) return;
      setState(() {
        _draftTasks = [..._draftTasks, edited];
      });
    } else {
      await widget.onSave(edited);
      if (!mounted) return;
      setState(() {
        _draftTasks = _draftTasks
            .map((task) => task.taskKey == edited.taskKey ? edited : task)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openTaskEditorPage(),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _draftTasks.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final task = _draftTasks[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Switch(
                        value: task.enabled,
                        onChanged: (value) async {
                          final updated = task.copyWith(enabled: value);
                          await widget.onSave(updated);
                          if (!mounted) return;
                          setState(() {
                            _draftTasks = _draftTasks
                                .map(
                                  (item) => item.taskKey == task.taskKey
                                      ? updated
                                      : item,
                                )
                                .toList();
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openTaskEditorPage(existing: task),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTask(task.taskKey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(task.body),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          task.scheduleType == 'interval'
                              ? 'Every ${task.intervalMinutes ?? 0} min'
                              : 'At ${task.timeOfDay ?? '--:--'}',
                        ),
                      ),
                      Chip(
                        label: Text(
                          task.route == 'review'
                              ? 'Tap -> Review card'
                              : 'Tap -> Task center',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({super.key, this.initialTask});

  final ButlerTaskConfig? initialTask;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late final bool _isEdit;
  late final TextEditingController _taskKeyController;
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _intervalController;
  late final TextEditingController _timeController;
  String _scheduleType = 'interval';
  String _route = 'task';
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _isEdit = widget.initialTask != null;
    final task = widget.initialTask;
    _taskKeyController = TextEditingController(
      text: task?.taskKey ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
    );
    _titleController = TextEditingController(text: task?.title ?? 'Reminder');
    _bodyController = TextEditingController(text: task?.body ?? '');
    _intervalController = TextEditingController(
      text: (task?.intervalMinutes ?? 60).toString(),
    );
    _timeController = TextEditingController(text: task?.timeOfDay ?? '22:30');
    _scheduleType = task?.scheduleType ?? 'interval';
    _route = task?.route ?? 'task';
    _enabled = task?.enabled ?? true;
  }

  @override
  void dispose() {
    _taskKeyController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _intervalController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _save() {
    final taskKey = _taskKeyController.text.trim();
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (taskKey.isEmpty || title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task key, title and body are required')),
      );
      return;
    }

    final interval = int.tryParse(_intervalController.text.trim());
    if (_scheduleType == 'interval' && (interval == null || interval <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interval must be a positive number')),
      );
      return;
    }

    final time = _timeController.text.trim();
    if (_scheduleType == 'daily' && !RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time must be in HH:MM format')),
      );
      return;
    }

    final task = ButlerTaskConfig(
      taskKey: taskKey,
      title: title,
      body: body,
      enabled: _enabled,
      scheduleType: _scheduleType,
      intervalMinutes: _scheduleType == 'interval' ? interval : null,
      timeOfDay: _scheduleType == 'daily' ? time : null,
      route: _route,
    );
    Navigator.of(context).pop(task);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Task' : 'Create Task')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _taskKeyController,
            enabled: !_isEdit,
            decoration: const InputDecoration(
              labelText: 'Task key',
              hintText: 'hydration or your_custom_key',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Notification title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(labelText: 'Notification body'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _enabled,
            title: const Text('Enabled'),
            onChanged: (value) {
              setState(() {
                _enabled = value;
              });
            },
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _scheduleType,
            decoration: const InputDecoration(labelText: 'Schedule type'),
            items: const [
              DropdownMenuItem(
                value: 'interval',
                child: Text('Every N minutes'),
              ),
              DropdownMenuItem(
                value: 'daily',
                child: Text('Fixed time each day'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _scheduleType = value;
              });
            },
          ),
          const SizedBox(height: 12),
          if (_scheduleType == 'interval')
            TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Interval (minutes)',
                hintText: '60',
              ),
            )
          else
            TextField(
              controller: _timeController,
              decoration: const InputDecoration(
                labelText: 'Time (HH:MM)',
                hintText: '22:30',
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _route,
            decoration: const InputDecoration(labelText: 'Page on tap'),
            items: const [
              DropdownMenuItem(value: 'task', child: Text('Task center')),
              DropdownMenuItem(
                value: 'review',
                child: Text('Night review page'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _route = value;
              });
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save Task')),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.initialSettings});

  final ButlerSettings initialSettings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({
    super.key,
    required this.onAction,
    required this.apiBaseUrl,
  });

  final Future<void> Function(String action) onAction;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    Widget tile(String title, IconData icon, String action) {
      return Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (action == 'english') {
              final result = await Navigator.of(context)
                  .push<Map<String, dynamic>>(
                    MaterialPageRoute<Map<String, dynamic>>(
                      builder: (context) =>
                          EnglishPracticePage(apiBaseUrl: apiBaseUrl),
                    ),
                  );
              if (result != null &&
                  context.mounted &&
                  result['submitted'] == true) {
                Navigator.of(context).pop(result);
              }
              return;
            }
            await onAction(action);
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Feature Center')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          tile('Growth Center', Icons.auto_graph_rounded, 'growth'),
          tile('Reminder Tasks', Icons.tune, 'tasks'),
          tile('Settings', Icons.settings_outlined, 'settings'),
          tile('Night Review Card', Icons.checklist_rtl_outlined, 'review'),
          tile('English Practice Card', Icons.school_outlined, 'english'),
          tile('Phrase Book', Icons.bookmark_outline, 'phrases'),
          tile('Memory Vault (Optional)', Icons.person_outline, 'profile'),
          const Card(
            child: ListTile(
              leading: Icon(Icons.psychology_alt_outlined),
              title: Text('Memory runs automatically'),
              subtitle: Text(
                'Butler now learns stable profile info directly from chat.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _englishMode;
  late bool _proactiveFollowup;
  late TextEditingController _dndStartController;
  late TextEditingController _dndEndController;
  late TextEditingController _bedtimeController;

  @override
  void initState() {
    super.initState();
    _englishMode = widget.initialSettings.englishMode;
    _proactiveFollowup = widget.initialSettings.proactiveFollowup;
    _dndStartController = TextEditingController(
      text: widget.initialSettings.doNotDisturbStart,
    );
    _dndEndController = TextEditingController(
      text: widget.initialSettings.doNotDisturbEnd,
    );
    _bedtimeController = TextEditingController(
      text: widget.initialSettings.bedtimeTime,
    );
  }

  @override
  void dispose() {
    _dndStartController.dispose();
    _dndEndController.dispose();
    _bedtimeController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = ButlerSettings(
      englishMode: _englishMode,
      proactiveFollowup: _proactiveFollowup,
      doNotDisturbStart: _dndStartController.text.trim(),
      doNotDisturbEnd: _dndEndController.text.trim(),
      bedtimeTime: _bedtimeController.text.trim(),
    );
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Butler Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _englishMode,
            title: const Text('English mode'),
            subtitle: const Text('Prefer English output and learning support'),
            onChanged: (value) {
              setState(() {
                _englishMode = value;
              });
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _proactiveFollowup,
            title: const Text('Proactive follow-up'),
            subtitle: const Text(
              'Allow the butler to ask gentle follow-up questions',
            ),
            onChanged: (value) {
              setState(() {
                _proactiveFollowup = value;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dndStartController,
            decoration: const InputDecoration(
              labelText: 'Do not disturb start (HH:MM)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dndEndController,
            decoration: const InputDecoration(
              labelText: 'Do not disturb end (HH:MM)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bedtimeController,
            decoration: const InputDecoration(
              labelText: 'Bedtime review time (HH:MM)',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save Settings')),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.memories,
    required this.onAdd,
    required this.onDelete,
  });

  final List<MemoryItem> memories;
  final Future<void> Function({
    required String key,
    required String value,
    required String category,
  })
  onAdd;
  final Future<void> Function(int memoryId) onDelete;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late List<MemoryItem> _localMemories;
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  final _categoryController = TextEditingController(text: 'profile');

  @override
  void initState() {
    super.initState();
    _localMemories = widget.memories;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _addMemory() async {
    final key = _keyController.text.trim();
    final value = _valueController.text.trim();
    final category = _categoryController.text.trim().isEmpty
        ? 'profile'
        : _categoryController.text.trim();
    if (key.isEmpty || value.isEmpty) return;

    await widget.onAdd(key: key, value: value, category: category);
    if (!mounted) return;
    setState(() {
      _localMemories = [
        ..._localMemories,
        MemoryItem(
          id: 0,
          memoryKey: key,
          memoryValue: value,
          category: category,
        ),
      ];
      _keyController.clear();
      _valueController.clear();
    });
  }

  Future<void> _editMemory(MemoryItem item) async {
    final valueController = TextEditingController(text: item.memoryValue);
    final categoryController = TextEditingController(text: item.category);
    final updated = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit ${item.memoryKey}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Value'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop({
                  'value': valueController.text.trim(),
                  'category': categoryController.text.trim(),
                });
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    valueController.dispose();
    categoryController.dispose();

    if (updated == null) return;
    final value = updated['value'] ?? '';
    final category = (updated['category'] ?? '').isEmpty
        ? item.category
        : updated['category']!;
    if (value.isEmpty) return;

    await widget.onAdd(key: item.memoryKey, value: value, category: category);
    if (!mounted) return;
    setState(() {
      _localMemories = _localMemories
          .map(
            (element) => element.id == item.id
                ? MemoryItem(
                    id: element.id,
                    memoryKey: element.memoryKey,
                    memoryValue: value,
                    category: category,
                  )
                : element,
          )
          .toList();
    });
  }

  void _applySuggestion(String key, String category, String hint) {
    _keyController.text = key;
    _categoryController.text = category;
    if (_valueController.text.trim().isEmpty) {
      _valueController.text = hint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile Memory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'What Butler Remembers',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'These profile facts help Butler give more personalized advice and reminders.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('name'),
                onPressed: () => _applySuggestion('name', 'profile', 'Leo'),
              ),
              ActionChip(
                label: const Text('english_level'),
                onPressed: () => _applySuggestion(
                  'english_level',
                  'learning',
                  'intermediate',
                ),
              ),
              ActionChip(
                label: const Text('study_goal'),
                onPressed: () => _applySuggestion(
                  'study_goal',
                  'learning',
                  'Improve spoken English',
                ),
              ),
              ActionChip(
                label: const Text('exercise_preference'),
                onPressed: () => _applySuggestion(
                  'exercise_preference',
                  'habit',
                  'Pull-ups and running',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._localMemories.map(
            (item) => Card(
              child: ListTile(
                title: Text('${item.memoryKey}: ${item.memoryValue}'),
                subtitle: Text('Category: ${item.category}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editMemory(item),
                    ),
                    if (item.id > 0)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await widget.onDelete(item.id);
                          if (!mounted) return;
                          setState(() {
                            _localMemories = _localMemories
                                .where((element) => element.id != item.id)
                                .toList();
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Add / Update Memory',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            decoration: const InputDecoration(labelText: 'Key (e.g. name)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _valueController,
            decoration: const InputDecoration(labelText: 'Value'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _categoryController,
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _addMemory, child: const Text('Save Memory')),
        ],
      ),
    );
  }
}

class PhraseBookPage extends StatefulWidget {
  const PhraseBookPage({
    super.key,
    required this.cards,
    required this.onCreate,
    required this.onDelete,
  });

  final List<PhraseCardItem> cards;
  final Future<List<PhraseCardItem>> Function({
    required String phrase,
    required String scene,
    required String note,
  })
  onCreate;
  final Future<List<PhraseCardItem>> Function(int id) onDelete;

  @override
  State<PhraseBookPage> createState() => _PhraseBookPageState();
}

class _PhraseBookPageState extends State<PhraseBookPage> {
  late List<PhraseCardItem> _cards;
  final TextEditingController _phraseController = TextEditingController();
  final TextEditingController _sceneController = TextEditingController(
    text: 'daily conversation',
  );
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cards = widget.cards;
  }

  @override
  void dispose() {
    _phraseController.dispose();
    _sceneController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _createCard() async {
    final phrase = _phraseController.text.trim();
    final scene = _sceneController.text.trim().isEmpty
        ? 'general'
        : _sceneController.text.trim();
    final note = _noteController.text.trim();
    if (phrase.isEmpty) return;

    final latest = await widget.onCreate(
      phrase: phrase,
      scene: scene,
      note: note,
    );
    if (!mounted) return;
    setState(() {
      _cards = latest;
      _phraseController.clear();
      _noteController.clear();
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved to Phrase Book')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phrase Book')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Save useful spoken lines for reuse.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phraseController,
            decoration: const InputDecoration(
              labelText: 'Phrase',
              hintText: 'Could you say that one more time?',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _sceneController,
            decoration: const InputDecoration(
              labelText: 'Scene',
              hintText: 'daily conversation / interview / ielts speaking',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'when to use this phrase',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _createCard,
            child: const Text('Save Phrase'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Saved Phrases',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ..._cards.map(
            (card) => Card(
              child: ListTile(
                title: Text(card.phrase),
                subtitle: Text(
                  '${card.scene}${card.note.isEmpty ? '' : ' • ${card.note}'}',
                ),
                trailing: card.id > 0
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final latest = await widget.onDelete(card.id);
                          if (!mounted) return;
                          setState(() {
                            _cards = latest;
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatsPage extends StatefulWidget {
  const StatsPage({
    super.key,
    this.streaks = const [],
    this.summary = const ProgressSummary(
      todayActiveCount: 0,
      longestStreak: 0,
      totalStreakDays: 0,
      consistencyScore: 0,
      totalEvents: 0,
    ),
    this.dailyActivity = const [],
    this.events = const [],
    this.badges = const [],
    this.heatmap = const [],
    this.freezeInfo = const FreezeInfo(
      tokens: 1,
      usedThisWeek: 0,
      remainingThisWeek: 1,
      weekAnchor: '',
    ),
    this.weekReport = const WeekReport(
      weekStart: '',
      weekEnd: '',
      activeDays: 0,
      completionRate: 0,
    ),
    this.onRecord,
    this.onDeleteEvent,
    this.onFreezeYesterday,
    this.onMakeupYesterday,
    this.onReload,
  });

  final List<StreakItem> streaks;
  final ProgressSummary summary;
  final List<DailyActivity> dailyActivity;
  final List<ProgressEvent> events;
  final List<BadgeItem> badges;
  final List<HeatmapCell> heatmap;
  final FreezeInfo freezeInfo;
  final WeekReport weekReport;
  final Future<StatsSnapshot> Function(String statKey, int count)? onRecord;
  final Future<StatsSnapshot> Function(int eventId)? onDeleteEvent;
  final Future<StatsSnapshot> Function(String statKey)? onFreezeYesterday;
  final Future<StatsSnapshot> Function(String statKey)? onMakeupYesterday;
  final Future<StatsSnapshot> Function()? onReload;

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  late List<StreakItem> _streaks;
  late ProgressSummary _summary;
  late List<DailyActivity> _dailyActivity;
  late List<ProgressEvent> _events;
  late List<BadgeItem> _badges;
  late List<HeatmapCell> _heatmap;
  late FreezeInfo _freezeInfo;
  late WeekReport _weekReport;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _streaks = widget.streaks;
    _summary = widget.summary;
    _dailyActivity = widget.dailyActivity;
    _events = widget.events;
    _badges = widget.badges;
    _heatmap = widget.heatmap;
    _freezeInfo = widget.freezeInfo;
    _weekReport = widget.weekReport;
  }

  void _applySnapshot(StatsSnapshot snapshot) {
    if (!mounted) return;
    setState(() {
      _streaks = snapshot.streaks;
      _summary = snapshot.summary;
      _dailyActivity = snapshot.dailyActivity;
      _events = snapshot.events;
      _badges = snapshot.badges;
      _heatmap = snapshot.heatmap;
      _freezeInfo = snapshot.freezeInfo;
      _weekReport = snapshot.weekReport;
    });
  }

  String _label(String key) {
    switch (key) {
      case 'reflection':
        return 'Reflection streak';
      case 'study':
        return 'Study streak';
      case 'exercise':
        return 'Exercise streak';
      case 'english':
        return 'English streak';
      default:
        return key;
    }
  }

  Future<String?> _pickStatKey(BuildContext context) async {
    final choices = _streaks.map((item) => item.statKey).toSet().toList()
      ..sort();
    if (choices.isEmpty) {
      choices.addAll(['english', 'study', 'exercise', 'reflection']);
    }
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose habit'),
        children: [
          for (final value in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(value),
              child: Text(value),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxEvents = _dailyActivity.isEmpty
        ? 1
        : _dailyActivity
              .map((item) => item.events)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, 9999);

    Widget metricCard(String title, String value, IconData icon) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.teal),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(color: Colors.black54)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (widget.onReload == null) return;
              final snapshot = await widget.onReload!.call();
              _applySnapshot(snapshot);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isMutating
            ? null
            : () async {
                final payload = await Navigator.of(context)
                    .push<Map<String, String>>(
                      MaterialPageRoute<Map<String, String>>(
                        builder: (context) => const ProgressRecordPage(),
                      ),
                    );

                if (payload == null) return;
                final statKey = (payload['stat_key'] ?? '').trim();
                final count = int.tryParse(payload['count'] ?? '1') ?? 1;
                if (statKey.isEmpty) return;
                if (_isMutating) return;

                try {
                  setState(() {
                    _isMutating = true;
                  });
                  if (widget.onRecord == null) return;
                  final snapshot = await widget.onRecord!.call(statKey, count);
                  _applySnapshot(snapshot);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Progress recorded')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to record progress: $e')),
                  );
                } finally {
                  if (mounted) {
                    setState(() {
                      _isMutating = false;
                    });
                  }
                }
              },
        icon: const Icon(Icons.add_task),
        label: Text(_isMutating ? 'Saving...' : 'Add Progress'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Trigger rules: progress auto-records when your chat mentions study/exercise/review or uses English. You can also tap "Add Progress" to create custom entries.',
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Freeze tokens: ${_freezeInfo.remainingThisWeek}/${_freezeInfo.tokens}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Week starts: ${_freezeInfo.weekAnchor.isEmpty ? '-' : _freezeInfo.weekAnchor}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: _isMutating
                            ? null
                            : () async {
                                final stat = await _pickStatKey(context);
                                if (stat == null) return;
                                try {
                                  setState(() {
                                    _isMutating = true;
                                  });
                                  if (widget.onFreezeYesterday == null) return;
                                  final snapshot = await widget
                                      .onFreezeYesterday!
                                      .call(stat);
                                  _applySnapshot(snapshot);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Freeze applied for yesterday',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Freeze failed: $e'),
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isMutating = false;
                                    });
                                  }
                                }
                              },
                        child: const Text('Use Freeze'),
                      ),
                      FilledButton.tonal(
                        onPressed: _isMutating
                            ? null
                            : () async {
                                final stat = await _pickStatKey(context);
                                if (stat == null) return;
                                try {
                                  setState(() {
                                    _isMutating = true;
                                  });
                                  if (widget.onMakeupYesterday == null) return;
                                  final snapshot = await widget
                                      .onMakeupYesterday!
                                      .call(stat);
                                  _applySnapshot(snapshot);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Make-up recorded for yesterday',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Make-up failed: $e'),
                                    ),
                                  );
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isMutating = false;
                                    });
                                  }
                                }
                              },
                        child: const Text('Make-up Yesterday'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              metricCard(
                'Today active',
                '${_summary.todayActiveCount}',
                Icons.today_outlined,
              ),
              const SizedBox(width: 8),
              metricCard(
                'Consistency',
                '${_summary.consistencyScore}%',
                Icons.analytics_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              metricCard(
                'Longest streak',
                '${_summary.longestStreak}d',
                Icons.local_fire_department_outlined,
              ),
              const SizedBox(width: 8),
              metricCard(
                'Total streak days',
                '${_summary.totalStreakDays}',
                Icons.calendar_month_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.checklist_rounded),
              title: const Text('Weekly completion'),
              subtitle: Text(
                '${_weekReport.weekStart.isEmpty ? '-' : _weekReport.weekStart} to ${_weekReport.weekEnd.isEmpty ? '-' : _weekReport.weekEnd}',
              ),
              trailing: Text(
                '${_weekReport.completionRate}%',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Achievements',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _badges
                .map(
                  (badge) => Chip(
                    avatar: Icon(
                      badge.unlocked ? Icons.emoji_events : Icons.lock_outline,
                      size: 18,
                      color: badge.unlocked
                          ? Colors.amber.shade700
                          : Colors.grey,
                    ),
                    label: Text(badge.title),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            '28-day heatmap',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: _heatmap.map((cell) {
              final colors = [
                Colors.grey.shade300,
                Colors.teal.shade100,
                Colors.teal.shade300,
                Colors.teal.shade500,
                Colors.teal.shade700,
              ];
              return Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: colors[cell.level.clamp(0, 4)],
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '7-day activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final item in _dailyActivity)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: 20 + (80 * item.events / maxEvents),
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.date.length >= 10
                                        ? item.date.substring(5)
                                        : item.date,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'By habit area',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._streaks.map((item) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.local_fire_department_outlined),
                title: Text(_label(item.statKey)),
                subtitle: Text('Last active: ${item.lastDate ?? '-'}'),
                trailing: Text(
                  '${item.count} days',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          const Text(
            'Recent progress records',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._events.take(20).map((item) {
            return Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(item.statKey),
                subtitle: Text(item.eventDate),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _isMutating
                      ? null
                      : () async {
                          try {
                            setState(() {
                              _isMutating = true;
                            });
                            if (widget.onDeleteEvent == null) return;
                            final snapshot = await widget.onDeleteEvent!.call(
                              item.id,
                            );
                            _applySnapshot(snapshot);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Progress deleted')),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to delete: $e')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isMutating = false;
                              });
                            }
                          }
                        },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class ProgressRecordPage extends StatefulWidget {
  const ProgressRecordPage({super.key});

  @override
  State<ProgressRecordPage> createState() => _ProgressRecordPageState();
}

class _ProgressRecordPageState extends State<ProgressRecordPage> {
  final TextEditingController _statController = TextEditingController(
    text: 'english',
  );
  final TextEditingController _countController = TextEditingController(
    text: '1',
  );
  bool _isSubmitting = false;

  @override
  void dispose() {
    _statController.dispose();
    _countController.dispose();
    super.dispose();
  }

  void _save() {
    if (_isSubmitting) return;
    final statKey = _statController.text.trim();
    final countText = _countController.text.trim();
    if (statKey.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });
    Navigator.of(
      context,
    ).pop({'stat_key': statKey, 'count': countText.isEmpty ? '1' : countText});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _statController,
            decoration: const InputDecoration(
              labelText: 'Category',
              hintText: 'english / study / exercise / reflection',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _countController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Events count',
              hintText: '1',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _save,
            child: Text(_isSubmitting ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final _moodController = TextEditingController();
  final _studyController = TextEditingController();
  final _exerciseController = TextEditingController();
  final _tomorrowController = TextEditingController();
  int _energy = 3;

  @override
  void dispose() {
    _moodController.dispose();
    _studyController.dispose();
    _exerciseController.dispose();
    _tomorrowController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop({
      'mood': _moodController.text.trim(),
      'study': _studyController.text.trim(),
      'exercise': _exerciseController.text.trim(),
      'tomorrow': '${_tomorrowController.text.trim()} (energy: $_energy/5)',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Night Review')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '2-minute night review: fill Mood / Study / Exercise / Tomorrow. Butler will give concise actionable feedback.',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Energy today'),
              Expanded(
                child: Slider(
                  value: _energy.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_energy',
                  onChanged: (value) {
                    setState(() {
                      _energy = value.toInt();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _moodController,
            decoration: const InputDecoration(
              labelText: 'Mood',
              hintText: 'calm / anxious / tired / excited',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _studyController,
            decoration: const InputDecoration(
              labelText: 'Study',
              hintText: 'what you learned and what was hard',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _exerciseController,
            decoration: const InputDecoration(
              labelText: 'Exercise',
              hintText: 'workout done or why it was skipped',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tomorrowController,
            decoration: const InputDecoration(
              labelText: 'Tomorrow Plan',
              hintText: 'one realistic goal',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: const Text('Generate Reflection Advice'),
          ),
        ],
      ),
    );
  }
}

class EnglishPracticePage extends StatefulWidget {
  const EnglishPracticePage({super.key, required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  State<EnglishPracticePage> createState() => _EnglishPracticePageState();
}

class _EnglishPracticePageState extends State<EnglishPracticePage> {
  final _inputController = TextEditingController();
  final _contextController = TextEditingController();
  String _scene = 'daily conversation';
  List<String> _exampleChips = const [];

  @override
  void initState() {
    super.initState();
    _loadExamples();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  void _submit() {
    final sentence = _inputController.text.trim();
    final practiceContext = _contextController.text.trim();
    if (sentence.isEmpty) return;

    final ieltsExtra = _scene == 'ielts speaking'
        ? 'Also include 3 IELTS speaking vocabulary items (with short meaning and one example sentence each), one band-7 style answer line, and one fluent part-3 follow-up opinion line.'
        : '';

    final prompt =
        '''
I am practicing spoken English for real life and IELTS improvement.
Please respond in a natural, conversational tone (not textbook style), and do these 6 things:
1) Fix my sentence.
2) Give one natural daily-life version I can really say out loud.
3) Give one more polished version useful for IELTS speaking.
4) Explain 1-2 key phrases using this exact format: **word/phrase** /IPA/: simple Chinese meaning.
   Never write Chinese pinyin or romanization after Chinese characters. Wrong: 例子 (zìlì). Right: **example** /ɪɡˈzæmpəl/: 例子.
5) Ask one follow-up question so I can continue speaking.
6) Give one extra daily spoken line + one IELTS-friendly line.

My sentence: "$sentence"
My scene: "$_scene"
My context (optional): "${practiceContext.isEmpty ? '-' : practiceContext}"

Keep it concise, practical, and speech-ready.
$ieltsExtra
''';
    Navigator.of(context).pop({
      'submitted': true,
      'prompt': prompt.trim(),
      'preview': 'English practice: "$sentence" ($_scene)',
    });
  }

  Future<void> _loadExamples() async {
    try {
      final uri = Uri.parse(
        '${widget.apiBaseUrl}/english/examples?scene=${Uri.encodeComponent(_scene)}&limit=5',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return;
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final list = data['examples'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _exampleChips = list
            .map(
              (item) =>
                  (item as Map<String, dynamic>)['text']?.toString() ?? '',
            )
            .where((value) => value.trim().isNotEmpty)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _exampleChips = const [
          'Can you say that again, please?',
          'I am trying to improve my spoken English.',
          'Could you help me with this sentence?',
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('English Practice')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Target: practical spoken English you can use in daily life. You will get correction, better phrasing, and a follow-up line.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _scene,
            decoration: const InputDecoration(labelText: 'Scene'),
            items: const [
              DropdownMenuItem(
                value: 'daily conversation',
                child: Text('Daily conversation'),
              ),
              DropdownMenuItem(value: 'mixed', child: Text('Mixed topics')),
              DropdownMenuItem(value: 'work', child: Text('Work')),
              DropdownMenuItem(value: 'school', child: Text('School')),
              DropdownMenuItem(value: 'gym', child: Text('Gym')),
              DropdownMenuItem(value: 'travel', child: Text('Travel')),
              DropdownMenuItem(
                value: 'daily errands',
                child: Text('Daily errands'),
              ),
              DropdownMenuItem(
                value: 'friends and social',
                child: Text('Friends & social'),
              ),
              DropdownMenuItem(
                value: 'restaurant and cafe',
                child: Text('Restaurant & cafe'),
              ),
              DropdownMenuItem(
                value: 'phone calls',
                child: Text('Phone calls'),
              ),
              DropdownMenuItem(
                value: 'job interview',
                child: Text('Job interview'),
              ),
              DropdownMenuItem(
                value: 'academic discussion',
                child: Text('Academic discussion'),
              ),
              DropdownMenuItem(
                value: 'debate and opinion',
                child: Text('Debate and opinion'),
              ),
              DropdownMenuItem(
                value: 'ielts speaking',
                child: Text('IELTS speaking'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              _scene = value;
              _loadExamples();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inputController,
            decoration: const InputDecoration(
              labelText: 'Your sentence',
              hintText: 'I very tired today but I still did workout.',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _contextController,
            decoration: const InputDecoration(
              labelText: 'Context (optional)',
              hintText: 'who you are talking to and what you want to express',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Try one:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _loadExamples,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh examples'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _exampleChips
                .map(
                  (text) => ActionChip(
                    label: Text(text),
                    onPressed: () {
                      _inputController.text = text;
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submit,
            child: const Text('Generate Learning Feedback'),
          ),
        ],
      ),
    );
  }
}
