import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../base_datos/firebase_service.dart';
import '../../servicios/hydration_reminder_service.dart';
import '../../widgets/common/app_glass_style.dart';

class HydrationScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;

  const HydrationScreen({
    super.key,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });

  @override
  State<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends State<HydrationScreen>
    with WidgetsBindingObserver {
  double _liters = 0.0;
  double _goal = 3.0;
  List<double> _weeklyPercent = List.filled(7, 0.0);

  bool _reminderEnabled = true;
  int _reminderMinutes = 15;
  String? _currentUserId;
  bool _reminderBusy = false;

  static const List<int> _minuteOptions = [15, 30, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeHydrationScreen();
  }

  Future<void> _initializeHydrationScreen() async {
    await _load();
    await _loadReminderPrefs();
    await _syncReminderFromSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncReminderFromSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _enabledKey(String userId) => 'hydration_reminder_enabled_$userId';
  String _minutesKey(String userId) => 'hydration_reminder_minutes_$userId';

  Future<void> _loadReminderPrefs() async {
    final u = await FirebaseService.getCurrentUser();
    if (u == null) return;

    final userId = ((await FirebaseService.getCurrentUserEmail()) ?? u.correo)
        .trim()
        .toLowerCase();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey(userId)) ?? true;
    final minutes = prefs.getInt(_minutesKey(userId)) ?? 15;

    if (!mounted) return;
    setState(() {
      _currentUserId = userId;
      _reminderEnabled = enabled;
      _reminderMinutes =
          _minuteOptions.contains(minutes) ? minutes : _minuteOptions.first;
    });
  }

  Future<void> _persistReminderPrefs() async {
    if (_currentUserId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey(_currentUserId!), _reminderEnabled);
    await prefs.setInt(_minutesKey(_currentUserId!), _reminderMinutes);
  }

  Future<void> _syncReminderFromSettings() async {
    setState(() => _reminderBusy = true);
    try {
      await HydrationReminderService.requestPermissions();
      if (_reminderEnabled) {
        await HydrationReminderService.scheduleHydrationReminder(
          intervalMinutes: _reminderMinutes,
        );
      } else {
        await HydrationReminderService.cancelHydrationReminder();
      }
      await _persistReminderPrefs();
    } finally {
      if (mounted) {
        setState(() => _reminderBusy = false);
      }
    }
  }

  Future<void> _load() async {
    final u = await FirebaseService.getCurrentUser();
    if (u == null) return;
    final userId = ((await FirebaseService.getCurrentUserEmail()) ?? u.correo)
        .trim()
        .toLowerCase();

    _goal = FirebaseService.computeDailyHydrationGoalMl(u) / 1000.0;

    final today = FirebaseService.dateKey(DateTime.now());
    final totalMl = await FirebaseService.getHydration(userId, today);

    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekly = List<double>.filled(7, 0.0);
    for (int i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      final dKey = FirebaseService.dateKey(d);
      final t = await FirebaseService.getHydration(userId, dKey);
      weekly[i] = ((t / (_goal * 1000.0)) * 100.0).clamp(0.0, 100.0);
    }
    setState(() {
      _liters = (totalMl / 1000.0).clamp(0.0, 10.0);
      _weeklyPercent = weekly;
      _currentUserId = userId;
    });
  }

  Future<void> _addWater(int ml) async {
    final u = await FirebaseService.getCurrentUser();
    if (u == null) return;
    final userId = ((await FirebaseService.getCurrentUserEmail()) ?? u.correo)
        .trim()
        .toLowerCase();
    final today = FirebaseService.dateKey(DateTime.now());
    await FirebaseService.addHydrationMl(userId, today, ml);
    await _load();
  }

  Future<void> _testNotification() async {
    await HydrationReminderService.requestPermissions();
    await HydrationReminderService.showTestNotification();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notificación de prueba enviada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final heading = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      color: Colors.white,
      fontFamily: widget.fontFamily,
    );
    final body = TextStyle(
      fontSize: 16,
      color: Colors.white.withValues(alpha: 0.9),
      fontFamily: widget.fontFamily,
    );

    final vspace = MediaQuery.of(context).size.height / 50;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppGlassStyle.appBar(title: 'Hidratación'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: (_goal <= 0) ? 0 : (_liters / _goal).clamp(0.0, 1.0),
                        strokeWidth: 12,
                        backgroundColor: cs.primaryContainer,
                        color: widget.seedColor,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${_liters.toStringAsFixed(1)} L',
                          style: heading.copyWith(fontSize: 32),
                        ),
                        Text(
                          'Objetivo: ${_goal.toStringAsFixed(1)} L',
                          style: body,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _waterButton(250, Icons.local_drink),
                    _waterButton(500, Icons.wine_bar),
                    _waterButton(1000, Icons.opacity),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: vspace),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recordatorio de agua', style: heading.copyWith(fontSize: 18)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Colors.white70),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Activar recordatorio',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Switch(
                      value: _reminderEnabled,
                      onChanged: (v) => setState(() => _reminderEnabled = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Cada', style: TextStyle(color: Colors.white70)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _reminderMinutes,
                        dropdownColor: const Color(0xFF1E2542),
                        decoration: InputDecoration(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: _minuteOptions
                            .map(
                              (m) => DropdownMenuItem<int>(
                                value: m,
                                child: Text(
                                  '$m minutos',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _reminderEnabled
                            ? (v) {
                                if (v == null) return;
                                setState(() => _reminderMinutes = v);
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _reminderBusy ? null : _syncReminderFromSettings,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(
                        _reminderEnabled
                            ? 'Aplicar cada $_reminderMinutes min'
                            : 'Desactivar',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _reminderBusy ? null : _testNotification,
                      icon: const Icon(Icons.notification_important_rounded),
                      label: const Text('Probar notificación'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _reminderEnabled
                      ? 'Próxima alerta: ahora + $_reminderMinutes minutos.'
                      : 'Recordatorio desactivado.',
                  style: body.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          SizedBox(height: vspace),
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Progreso semanal', style: heading),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: BarChart(
                    BarChartData(
                      maxY: 100,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => cs.secondaryContainer,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (v, _) {
                              const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
                              return Text(days[v.toInt() % 7]);
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: _weeklyPercent[i],
                              color: cs.primary,
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _waterButton(int ml, IconData icon) {
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: AppGlassStyle.primaryGradient),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            onPressed: () => _addWater(ml),
            icon: Icon(icon, color: Colors.white),
            iconSize: 32,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$ml ml',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }
}
