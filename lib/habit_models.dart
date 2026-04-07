import 'package:flutter/material.dart';

class HabitItemModel {
  const HabitItemModel({
    required this.habitKey,
    required this.title,
    required this.icon,
    required this.category,
    required this.enabled,
    required this.isCustom,
  });

  final String habitKey;
  final String title;
  final String icon;
  final String category;
  final bool enabled;
  final bool isCustom;

  factory HabitItemModel.fromJson(Map<String, dynamic> json) {
    return HabitItemModel(
      habitKey: json['habit_key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      icon: json['icon']?.toString() ?? 'check_circle',
      category: json['category']?.toString() ?? 'wellbeing',
      enabled: json['enabled'] == true,
      isCustom: json['is_custom'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'habit_key': habitKey,
      'title': title,
      'icon': icon,
      'category': category,
      'enabled': enabled,
      'is_custom': isCustom,
    };
  }
}

class StreakItem {
  const StreakItem({
    required this.statKey,
    required this.count,
    required this.lastDate,
  });

  final String statKey;
  final int count;
  final String? lastDate;

  factory StreakItem.fromJson(Map<String, dynamic> json) {
    return StreakItem(
      statKey: json['stat_key']?.toString() ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      lastDate: json['last_date']?.toString(),
    );
  }
}

class ProgressEvent {
  const ProgressEvent({
    required this.id,
    required this.statKey,
    required this.eventDate,
    required this.eventTime,
  });

  final int id;
  final String statKey;
  final String eventDate;
  final String eventTime;

  factory ProgressEvent.fromJson(Map<String, dynamic> json) {
    return ProgressEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      statKey: json['stat_key']?.toString() ?? '',
      eventDate: json['event_date']?.toString() ?? '',
      eventTime: json['event_time']?.toString() ?? '00:00:00',
    );
  }
}

class HabitMutationResult {
  const HabitMutationResult({required this.streaks, required this.events});

  final List<StreakItem> streaks;
  final List<ProgressEvent> events;
}

IconData habitIconFromKey(String key) {
  switch (key) {
    case 'local_drink':
      return Icons.local_drink;
    case 'self_improvement':
      return Icons.self_improvement;
    case 'menu_book':
      return Icons.menu_book;
    case 'directions_walk':
      return Icons.directions_walk;
    case 'bedtime':
      return Icons.bedtime;
    case 'record_voice_over':
      return Icons.record_voice_over;
    case 'fitness_center':
      return Icons.fitness_center;
    case 'spa':
      return Icons.spa;
    case 'psychology':
      return Icons.psychology;
    case 'check_circle':
    default:
      return Icons.check_circle;
  }
}

String habitAchievementFor(int streakDays) {
  if (streakDays >= 30) return '30-day habit keeper';
  if (streakDays >= 14) return '14-day rhythm';
  if (streakDays >= 7) return '7-day streak';
  if (streakDays >= 3) return '3-day spark';
  return '';
}
