import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/game_controller.dart';
import 'app/persistence.dart';
import 'app/settings.dart';
import 'ui/home_screen.dart';

void main() {
  runApp(const MyApp());
}

/// Root app widget.
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final GameController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GameController(persistence: const AppPersistence());
    // Async load; no context usage here.
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ThemeData _theme() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        titleTextStyle: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 18),
        iconTheme: IconThemeData(color: AppColors.text),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GameController>.value(
      value: _controller,
      child: MaterialApp(
        title: 'Chess',
        theme: _theme(),
        home: const HomeScreen(),
      ),
    );
  }
}
