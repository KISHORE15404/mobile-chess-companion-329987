import 'package:flutter/material.dart';

/// Board color theme.
class BoardTheme {
  final String id;
  final String name;
  final Color lightSquare;
  final Color darkSquare;
  final Color highlight;
  final Color lastMove;

  const BoardTheme({
    required this.id,
    required this.name,
    required this.lightSquare,
    required this.darkSquare,
    required this.highlight,
    required this.lastMove,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'ls': lightSquare.value,
        'ds': darkSquare.value,
        'hl': highlight.value,
        'lm': lastMove.value,
      };

  static BoardTheme fromJson(Map<String, dynamic> json) => BoardTheme(
        id: json['id'] as String,
        name: json['name'] as String,
        lightSquare: Color((json['ls'] as num).toInt()),
        darkSquare: Color((json['ds'] as num).toInt()),
        highlight: Color((json['hl'] as num).toInt()),
        lastMove: Color((json['lm'] as num).toInt()),
      );
}

/// Simple app-level settings.
class AppSettings {
  final String themeId;
  final bool flipBoard;

  const AppSettings({required this.themeId, required this.flipBoard});

  static const defaultSettings = AppSettings(themeId: 'classic_blue', flipBoard: false);

  AppSettings copyWith({String? themeId, bool? flipBoard}) =>
      AppSettings(themeId: themeId ?? this.themeId, flipBoard: flipBoard ?? this.flipBoard);

  Map<String, dynamic> toJson() => {'themeId': themeId, 'flip': flipBoard};

  static AppSettings fromJson(Map<String, dynamic> json) => AppSettings(
        themeId: (json['themeId'] as String?) ?? defaultSettings.themeId,
        flipBoard: (json['flip'] as bool?) ?? defaultSettings.flipBoard,
      );
}

/// App color scheme based on style guide.
class AppColors {
  static const Color primary = Color(0xFF3B82F6);
  static const Color success = Color(0xFF06B6D4);
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF111827);
  static const Color secondary = Color(0xFF64748B);
  static const Color error = Color(0xFFEF4444);
}

/// Predefined board themes.
class BoardThemes {
  const BoardThemes._();

  static const BoardTheme classicBlue = BoardTheme(
    id: 'classic_blue',
    name: 'Classic Blue',
    lightSquare: Color(0xFFEFF6FF),
    darkSquare: Color(0xFF93C5FD),
    highlight: Color(0x6606B6D4), // success with alpha
    lastMove: Color(0x663B82F6), // primary with alpha
  );

  static const BoardTheme green = BoardTheme(
    id: 'green',
    name: 'Green',
    lightSquare: Color(0xFFF0FDF4),
    darkSquare: Color(0xFF86EFAC),
    highlight: Color(0x6606B6D4),
    lastMove: Color(0x663B82F6),
  );

  static const BoardTheme gray = BoardTheme(
    id: 'gray',
    name: 'Gray',
    lightSquare: Color(0xFFF8FAFC),
    darkSquare: Color(0xFFCBD5E1),
    highlight: Color(0x6606B6D4),
    lastMove: Color(0x663B82F6),
  );

  static const List<BoardTheme> all = [classicBlue, green, gray];

  static BoardTheme byId(String id) => all.firstWhere((t) => t.id == id, orElse: () => classicBlue);
}
