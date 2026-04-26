import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../base_datos/firebase_service.dart';
import '../../widgets/common/app_glass_style.dart';
import '../../modelos/user_settings.dart';

class SleepScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;

  const SleepScreen({
    super.key,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _recent = [];
  double _todayHours = 0.0;
  bool _sleepAutoDetectionEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final u = await FirebaseService.getCurrentUser();
    if (u == null) return;
    final userId = (await FirebaseService.getCurrentUserEmail()) ?? u.correo;

    final UserSettings? settings = await FirebaseService.getSettingsForUser(userId);
    final bool sleepAutoDetectionEnabled = settings?.sleepAutoDetectionEnabled ?? true;

    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));

    final List<Map<String, dynamic>> list = [];
    for (int i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      final dKey = FirebaseService.dateKey(d);
      final h = await FirebaseService.getSleep(userId, dKey);
      
      list.add({
        'date': dKey,
        'duration_h': h,
      });
      if (dKey == FirebaseService.dateKey(now)) {
        _todayHours = h;
      }
    }
    setState(() {
      _recent = list;
      _sleepAutoDetectionEnabled = sleepAutoDetectionEnabled;
    });
  }

  Future<void> _addSleep(double hours) async {
    final u = await FirebaseService.getCurrentUser();
    if (u == null) return;
    final userId = (await FirebaseService.getCurrentUserEmail()) ?? u.correo;
    final today = FirebaseService.dateKey(DateTime.now());
    
    await FirebaseService.addSleep(userId, today, hours);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppGlassStyle.appBar(title: 'Sueño'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (!_sleepAutoDetectionEnabled) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.pause_circle_outline, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Detección automática de sueño desactivada desde Ajustes.',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Icon(Icons.bedtime_rounded, size: 64, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  '${_todayHours.toStringAsFixed(1)} h',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Text('Dormido hoy', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _sleepButton('+1h', () => _addSleep(1)),
                    _sleepButton('+30m', () => _addSleep(0.5)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Esta semana',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          GlassCard(
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: 12,
                  barGroups: List.generate(7, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: _recent.length > i ? _recent[i]['duration_h'] : 0.0,
                          color: const Color(0xFF8B5CF6),
                          width: 16,
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
                          return Text(
                            days[v.toInt() % 7],
                            style: const TextStyle(color: Colors.white70),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 2,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Colors.white12, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sleepButton(String label, VoidCallback onPressed) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppGlassStyle.primaryGradient),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
        ),
        child: Text(label),
      ),
    );
  }
}
