import 'package:flutter/material.dart';

import '../../base_datos/firebase_service.dart';
import '../ajustes/settings_screen.dart';
import '../ejercicio/exercise_screen.dart';
import '../hidratacion/hydration_screen.dart';
import '../nutricion/nutrition_screen.dart';
import '../sueno/sleep_screen.dart';
import '../../widgets/common/app_glass_style.dart';

class VidaPlusApp extends StatefulWidget {
  const VidaPlusApp({super.key});
  @override
  State<VidaPlusApp> createState() => _VidaPlusAppState();
}

// Estado que gestiona tema, color semilla, fuente y ubicación a nivel global
class _VidaPlusAppState extends State<VidaPlusApp> {
  int _index = 0;
  Brightness _brightness = Brightness.light;
  Color _seedColor = const Color(0xFF80CBC4);
  String? _fontFamily;
  bool _followLocation = false;
  // Agregado para accesibilidad: escala de texto y alto contraste
  double _textScale = 1.0;
  bool _highContrast = false;

  @override
  void initState() {
    super.initState();
    _loadThemeFromSettings();
  }

  Future<void> _loadThemeFromSettings() async {
    final u = await FirebaseService.getCurrentUser();
    if (u == null || !mounted) return;

    final s = await FirebaseService.getSettingsForUser(u.correo);
    if (!mounted) return;

    setState(() {
      if ('${s?.brightness}' == 'Brightness.dark' || '${s?.brightness}' == 'dark') {
        _brightness = Brightness.dark;
      } else if ('${s?.brightness}' == 'Brightness.light' || '${s?.brightness}' == 'light') {
        _brightness = Brightness.light;
      }
      if (s?.seedColor is int) {
        _seedColor = Color(s!.seedColor!);
      }
      _fontFamily = s?.fontFamily;
      _followLocation = s?.followLocation ?? false;
      _textScale = s?.textScale ?? 1.0;
      _highContrast = s?.highContrast ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Corregido modo oscuro global: aplica ThemeData dinámico con ColorScheme.fromSeed
    final cs = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: _brightness,
    );
    final theme = ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      fontFamily: _fontFamily ?? 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(fontWeight: FontWeight.w800),
        titleLarge: TextStyle(fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        centerTitle: true,
        elevation: 0,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cs.surface,
        selectedItemColor: cs.primary,
        unselectedItemColor: cs.onSurfaceVariant,
        selectedIconTheme: const IconThemeData(size: 32),
        unselectedIconTheme: const IconThemeData(size: 28),
      ),
    );

    final items = const [
      BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu_rounded), label: 'Nutrición'),
      BottomNavigationBarItem(
        icon: Icon(Icons.fitness_center_rounded),
        label: 'Ejercicio',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.water_drop_rounded),
        label: 'Hidratación',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.bedtime_rounded), label: 'Sueño'),
      BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
    ];

    final pages = [
      NutritionScreen(
        brightness: _brightness,
        seedColor: _seedColor,
        fontFamily: _fontFamily,
      ),
      ExerciseScreen(
        brightness: _brightness,
        seedColor: _seedColor,
        fontFamily: _fontFamily,
      ),
      HydrationScreen(
        brightness: _brightness,
        seedColor: _seedColor,
        fontFamily: _fontFamily,
      ),
      SleepScreen(
        brightness: _brightness,
        seedColor: _seedColor,
        fontFamily: _fontFamily,
      ),
      SettingsScreen(
        brightness: _brightness,
        seed: _seedColor,
        fontFamily: _fontFamily,
        followLocation: _followLocation,
        asTab: true,
        onChanged: (data) async {
          await _loadThemeFromSettings();
        },
      ),
    ];

    // Agregado para aplicar escala de texto y alto contraste globalmente
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: TextScaler.linear(_textScale),
        highContrast: _highContrast,
      ),
      child: Scaffold(
        body: GlassBackground(
          child: SafeArea(
            child: Builder(
              builder: (context) {
                final activeTheme = theme;
                final activeCs = activeTheme.colorScheme;
                return Theme(
                  data: activeTheme,
                  child: Column(
                    children: [
                      Expanded(
                        child: IndexedStack(index: _index, children: pages),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: BottomNavigationBar(
                            type: BottomNavigationBarType.fixed,
                            elevation: 0,
                            iconSize: 28,
                            backgroundColor: Colors.transparent,
                            currentIndex: _index,
                            onTap: (i) => setState(() => _index = i),
                            selectedItemColor: activeCs.primary,
                            unselectedItemColor: activeCs.onSurfaceVariant,
                            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
                            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
                            showSelectedLabels: true,
                            showUnselectedLabels: true,
                            items: items,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
