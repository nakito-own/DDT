import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'calendar_event.dart';

/// Distinct colors for stacked calendars. Index 0 matches the app primary.
abstract final class CalendarPalette {
  static const colors = <Color>[
    Color(0xFF1976D2),
    Color(0xFF00897B),
    Color(0xFFEF6C00),
    Color(0xFF7B1FA2),
    Color(0xFF2E7D32),
    Color(0xFFC2185B),
    Color(0xFF0097A7),
    Color(0xFF5C6BC0),
    Color(0xFF6D4C41),
    Color(0xFF00838F),
  ];

  static Color colorFor(int? index) {
    if (index == null || index < 0) return colors.first;
    return colors[index % colors.length];
  }
}

class CalendarPerson {
  const CalendarPerson({required this.email, required this.displayName});

  final String email;
  final String displayName;

  factory CalendarPerson.fromJson(Map<String, dynamic> json) {
    return CalendarPerson(
      email: (json['email'] as String).toLowerCase(),
      displayName: json['display_name'] as String? ?? json['email'] as String,
    );
  }
}

class ColleagueCalendar extends Equatable {
  const ColleagueCalendar({
    required this.email,
    required this.displayName,
    required this.colorIndex,
    this.enabled = true,
    this.isLoading = false,
    this.available = true,
    this.view = 'None',
    this.error,
    this.events = const [],
  });

  final String email;
  final String displayName;
  final int colorIndex;
  final bool enabled;
  final bool isLoading;
  final bool available;
  final String view;
  final String? error;
  final List<CalendarEvent> events;

  Color get color => CalendarPalette.colorFor(colorIndex);

  ColleagueCalendar copyWith({
    String? email,
    String? displayName,
    int? colorIndex,
    bool? enabled,
    bool? isLoading,
    bool? available,
    String? view,
    String? Function()? error,
    List<CalendarEvent>? events,
  }) {
    return ColleagueCalendar(
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      colorIndex: colorIndex ?? this.colorIndex,
      enabled: enabled ?? this.enabled,
      isLoading: isLoading ?? this.isLoading,
      available: available ?? this.available,
      view: view ?? this.view,
      error: error != null ? error() : this.error,
      events: events ?? this.events,
    );
  }

  Map<String, dynamic> toStorage() {
    return {
      'email': email,
      'displayName': displayName,
      'colorIndex': colorIndex,
      'enabled': enabled,
    };
  }

  factory ColleagueCalendar.fromStorage(Map<String, dynamic> json) {
    return ColleagueCalendar(
      email: (json['email'] as String).toLowerCase(),
      displayName: json['displayName'] as String? ?? json['email'] as String,
      colorIndex: json['colorIndex'] as int? ?? 1,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  factory ColleagueCalendar.fromApi(
    Map<String, dynamic> json, {
    required int colorIndex,
    bool enabled = true,
  }) {
    final email = (json['email'] as String).toLowerCase();
    final displayName = json['display_name'] as String? ?? email;
    final events =
        (json['events'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (item) => CalendarEvent.fromJson(item).copyWith(
                isColleague: true,
                colorIndex: colorIndex,
                mailbox: email,
                ownerName: displayName,
              ),
            )
            .toList();
    return ColleagueCalendar(
      email: email,
      displayName: displayName,
      colorIndex: colorIndex,
      enabled: enabled,
      available: json['available'] as bool? ?? true,
      view: json['view'] as String? ?? 'None',
      error: json['error'] as String?,
      events: events,
    );
  }

  @override
  List<Object?> get props => [
    email,
    displayName,
    colorIndex,
    enabled,
    isLoading,
    available,
    view,
    error,
    events,
  ];
}
