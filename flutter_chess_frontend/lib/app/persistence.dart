import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../chess/engine.dart';
import 'settings.dart';

class _PrefsKeys {
  static const String settings = 'settings_v1';
  static const String gameState = 'game_state_v1';
}

/// Local persistence for settings and the current game.
class AppPersistence {
  const AppPersistence();

  // PUBLIC_INTERFACE
  Future<AppSettings> loadSettings() async {
    /// Load settings from SharedPreferences; returns defaults when missing/invalid.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_PrefsKeys.settings);
    if (raw == null) return AppSettings.defaultSettings;
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return AppSettings.defaultSettings;
    }
  }

  // PUBLIC_INTERFACE
  Future<void> saveSettings(AppSettings settings) async {
    /// Save settings to SharedPreferences.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefsKeys.settings, jsonEncode(settings.toJson()));
  }

  // PUBLIC_INTERFACE
  Future<ChessEngine?> loadGame() async {
    /// Load game engine state from SharedPreferences (including undo/redo stack).
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_PrefsKeys.gameState);
    if (raw == null) return null;
    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return ChessEngine.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  // PUBLIC_INTERFACE
  Future<void> saveGame(ChessEngine engine) async {
    /// Save game engine state to SharedPreferences.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefsKeys.gameState, jsonEncode(engine.toJson()));
  }

  // PUBLIC_INTERFACE
  Future<void> clearGame() async {
    /// Remove persisted game state.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_PrefsKeys.gameState);
  }
}
