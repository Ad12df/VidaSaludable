import 'dart:async';

import 'package:flutter/widgets.dart';

import '../base_datos/firebase_service.dart';
import '../modelos/user_settings.dart';

/// Servicio simple de auto-registro de sueño durante ventana nocturna
/// cuando la app detecta estado inactivo/pausado.
class SleepAutoService with WidgetsBindingObserver {
  SleepAutoService._();

  static final SleepAutoService instance = SleepAutoService._();

  Timer? _timer;
  bool _started = false;
  DateTime? _inactiveSince;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _inactiveSince = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _inactiveSince ??= DateTime.now();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tryAutoMark());
    } else if (state == AppLifecycleState.resumed) {
      _timer?.cancel();
      _timer = null;
      _tryAutoMark(finalize: true);
      _inactiveSince = null;
    }
  }

  bool _isNightWindow(DateTime dt) {
    final hour = dt.hour;
    return hour >= 20 || hour < 6; // 8:00 PM -> 6:00 AM
  }

  Future<void> _tryAutoMark({bool finalize = false}) async {
    final start = _inactiveSince;
    if (start == null) return;

    final now = DateTime.now();
    final inNight = _isNightWindow(start) || _isNightWindow(now);
    if (!inNight) return;

    final elapsedMinutes = now.difference(start).inMinutes;
    if (!finalize && elapsedMinutes < 15) return;

    final user = await FirebaseService.getCurrentUser();
    if (user == null) return;
    final userId = ((await FirebaseService.getCurrentUserEmail()) ?? user.correo)
        .trim()
        .toLowerCase();

    final UserSettings? settings = await FirebaseService.getSettingsForUser(userId);
    final enabled = settings?.sleepAutoDetectionEnabled ?? true;
    if (!enabled) return;

    final hours = elapsedMinutes / 60.0;
    if (hours <= 0) return;

    final dateKey = FirebaseService.dateKey(start);
    await FirebaseService.addSleep(userId, dateKey, hours);

    _inactiveSince = now;
  }
}
