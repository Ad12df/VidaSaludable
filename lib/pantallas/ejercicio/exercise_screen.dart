import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geolocator/geolocator.dart';
import '../../nucleo/utilidades.dart';
import '../../base_datos/firebase_service.dart';
import '../../modelos/user_settings.dart';
import '../../widgets/common/app_glass_style.dart';

class ExerciseScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;
  const ExerciseScreen({
    super.key,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });
  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen>
    with TickerProviderStateMixin {
  // Suscripción a ubicación para inferir actividad y velocidad
  StreamSubscription<Position>? _posSub;
  Timer? _chartTimer;
  Timer? _persistDebounce;
  bool _tracking = false;
  bool _activityTrackingEnabled = true;
  Position? _lastPos;
  double _distanceMeters = 0.0;
  bool _hasLocationPermission = false;
  // Actividad actual inferida
  ActivityKind _currentKind = ActivityKind.unknown;
  // Contador de pasos del día
  int _dailySteps = 0;
  // Velocidad actual en km/h
  double _speedKmh = 0;
  // Fecha (YYYY-MM-DD) del último registro persistido
  String _lastDate = '';
  // Buffer de pasos para graficar por intervalos
  int _stepBuffer = 0;
  int _pendingPersistSteps = 0;
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  // Serie de puntos para el gráfico de cardio (pasos por ventana)
  final List<FlSpot> _cardioSpots = [];
  late final AnimationController _fadeCtrl;
  // Parámetros de conteo por GPS
  static const double _stepLengthMeters = 0.75;
  static const double _distanceThresholdMeters = 2.5; // ignora ruido
  double _pendingMeters = 0.0;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
    _bootstrapTracking();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _chartTimer?.cancel();
    _persistDebounce?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // Inicia el tracking de ubicación (expuesto como startLocationTracking)
  void startLocationTracking() {
    _beginTracking();
  }

  Future<void> _bootstrapTracking() async {
    await _loadPersisted();
    await _syncTrackingPreferenceAndApply();
  }

  Future<void> _syncTrackingPreferenceAndApply() async {
    final email = await FirebaseService.getCurrentUserEmail();
    UserSettings? settings;
    if (email != null) {
      settings = await FirebaseService.getSettingsForUser(email);
    }
    final enabled = settings?.followLocation ?? true;
    if (!mounted) return;

    if (_activityTrackingEnabled != enabled) {
      setState(() => _activityTrackingEnabled = enabled);
    }

    if (!enabled) {
      _stopTrackingTemporarily();
      return;
    }

    await _ensurePermissionAndStart();
    if (mounted && _hasLocationPermission && !_tracking) {
      startLocationTracking();
    }
  }

  void _stopTrackingTemporarily() {
    _posSub?.cancel();
    _posSub = null;
    _chartTimer?.cancel();
    _chartTimer = null;
    _persistDebounce?.cancel();
    _persistDebounce = null;
    _speedKmh = 0;
    _tracking = false;
    _currentKind = ActivityKind.unknown;
    _lastPos = null;
    _pendingMeters = 0;
    if (mounted) setState(() {});
  }

  Future<void> _loadPersisted() async {
    final u = await FirebaseService.getCurrentUser();
    if (u == null) return;
    final todayStr = FirebaseService.dateKey(DateTime.now());
    final raw = await FirebaseService.getDailyExercise(u.correo, todayStr);
    if (raw != null) {
      if (!mounted) return;
      setState(() {
        _dailySteps = (raw['steps'] is int)
            ? raw['steps']
            : int.tryParse('${raw['steps'] ?? 0}') ?? 0;
        _lastDate = todayStr;
      });
    } else {
      final data = {
        'userId': u.correo,
        'date': todayStr,
        'steps': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await FirebaseService.saveDailyExercise(u.correo, todayStr, data);
      if (!mounted) return;
      setState(() {
        _dailySteps = 0;
        _lastDate = todayStr;
      });
    }
  }

  Future<void> _persistSteps() async {
    if (_pendingPersistSteps == 0) return;
    final u = await FirebaseService.getCurrentUser();
    if (u == null || _lastDate.isEmpty) return;
    final data = {
      'userId': u.correo,
      'date': _lastDate,
      'steps': _dailySteps,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    _pendingPersistSteps = 0;
    await FirebaseService.saveDailyExercise(u.correo, _lastDate, data);
  }

  void _schedulePersist() {
    _pendingPersistSteps++;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 3), () {
      _persistSteps();
    });
  }

  // Solicita permisos de ubicación y arranca los streams si están concedidos
  Future<void> _ensurePermissionAndStart() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'GPS desactivado. Actívalo para registrar tu recorrido.',
            ),
          ),
        );
      }
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {}
      enabled = await Geolocator.isLocationServiceEnabled();
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de ubicación denegado')),
        );
      }
    }
    if (perm == LocationPermission.deniedForever) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Permiso de ubicación'),
          content: const Text(
            'Habilita la ubicación en ajustes para registrar tu actividad.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    }
    _hasLocationPermission =
        enabled &&
        (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse);
  }

  // Inicia streams de geolocalización y acelerómetro; actualiza estado y gráfica
  void _beginTracking() {
    _posSub?.cancel();
    _chartTimer?.cancel();
    
    LocationSettings ls;
    if (Platform.isAndroid) {
      ls = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 3),
      );
    } else if (Platform.isIOS) {
      ls = AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: true,
      );
    } else {
      ls = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      );
    }

    _posSub = Geolocator.getPositionStream(locationSettings: ls).listen((pos) {
      if (!mounted) return;
      _onNewPosition(pos);
    });

    _chartTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _updateChart();
    });

    setState(() => _tracking = true);
  }

  void _onNewPosition(Position pos) {
    if (_lastPos != null) {
      final d = Geolocator.distanceBetween(
        _lastPos!.latitude,
        _lastPos!.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (d > _distanceThresholdMeters) {
        _distanceMeters += d;
        _pendingMeters += d;
        final deltaSteps = (_pendingMeters / _stepLengthMeters).floor();
        if (deltaSteps > 0) {
          _dailySteps += deltaSteps;
          _stepBuffer += deltaSteps;
          _pendingMeters -= deltaSteps * _stepLengthMeters;
          _schedulePersist();
        }
      }
    }
    _lastPos = pos;
    _speedKmh = pos.speed * 3.6;
    _inferActivity(pos.speed);

    final now = DateTime.now();
    if (now.difference(_lastUiUpdate).inMilliseconds >= 500) {
      _lastUiUpdate = now;
      setState(() {});
    }
  }

  void _inferActivity(double speed) {
    if (speed < 0.5) {
      _currentKind = ActivityKind.stationary;
    } else if (speed < 2.2) {
      _currentKind = ActivityKind.walking;
    } else if (speed < 8.0) {
      _currentKind = ActivityKind.running;
    } else {
      _currentKind = ActivityKind.vehicle;
    }
  }

  void _updateChart() {
    if (_cardioSpots.length >= 20) {
      _cardioSpots.removeAt(0);
      for (var i = 0; i < _cardioSpots.length; i++) {
        _cardioSpots[i] = FlSpot(i.toDouble(), _cardioSpots[i].y);
      }
    }
    final nextX = _cardioSpots.isEmpty ? 0.0 : _cardioSpots.last.x + 1.0;
    _cardioSpots.add(FlSpot(nextX, _stepBuffer.toDouble()));
    _stepBuffer = 0;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    unawaited(_syncTrackingPreferenceAndApply());
    final cs = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _fadeCtrl,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppGlassStyle.appBar(title: 'Actividad física'),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!_activityTrackingEnabled) ...[
              GlassCard(
                child: Row(
                  children: const [
                    Icon(Icons.pause_circle_outline, color: Colors.amber, size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Seguimiento pausado desde Ajustes',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _buildStatCard(cs),
            const SizedBox(height: 24),
            _buildChartCard(cs),
            const SizedBox(height: 24),
            _buildActivityIndicator(cs),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(ColorScheme cs) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pasos hoy',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      '$_dailySteps',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                _buildCharacterBadge(),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _miniStat(
                  Icons.speed,
                  '${_speedKmh.toStringAsFixed(1)} km/h',
                  'Velocidad',
                ),
                _miniStat(
                  Icons.map_outlined,
                  '${(_distanceMeters / 1000).toStringAsFixed(2)} km',
                  'Distancia',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String val, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.white),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }

  Widget _buildChartCard(ColorScheme cs) {
    final maxY = _cardioSpots.isEmpty
        ? 8.0
        : (_cardioSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 4).clamp(8.0, 120.0);

    return AspectRatio(
      aspectRatio: 1.7,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Intensidad reciente',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: LineChart(
                    LineChartData(
                    minX: 0,
                    maxX: (_cardioSpots.length - 1).toDouble().clamp(0, 19),
                    minY: 0,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.white.withValues(alpha: 0.08),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _cardioSpots.isEmpty ? [const FlSpot(0, 0)] : _cardioSpots,
                        isCurved: true,
                        curveSmoothness: 0.25,
                        color: const Color(0xFF2EC4B6),
                        barWidth: 4,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFF2EC4B6).withValues(alpha: 0.35),
                              const Color(0xFF2EC4B6).withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCharacterBadge() {
    IconData icon = Icons.person_outline;
    String mood = 'Cargando avatar...';

    switch (_currentKind) {
      case ActivityKind.stationary:
        icon = Icons.self_improvement;
        mood = 'Modo descanso';
      case ActivityKind.walking:
        icon = Icons.directions_walk;
        mood = 'Modo aventura';
      case ActivityKind.running:
        icon = Icons.directions_run;
        mood = 'Modo turbo';
      case ActivityKind.vehicle:
        icon = Icons.directions_car;
        mood = 'Modo velocidad';
      case ActivityKind.unknown:
        icon = Icons.gps_fixed;
        mood = 'Buscando misión...';
    }

    return Column(
      children: [
        Icon(icon, size: 64, color: Colors.white),
        const SizedBox(height: 6),
        Text(
          mood,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityIndicator(ColorScheme cs) {
    String title = 'Tip de carga';
    String tip = 'Sin señal de misión... respira, estira y espera el siguiente checkpoint.';
    IconData icon = Icons.tips_and_updates_outlined;

    switch (_currentKind) {
      case ActivityKind.stationary:
        title = 'Tip de descanso';
        tip = 'Tu personaje regenera energía en reposo. No gastes todo el maná en el sofá.';
        icon = Icons.nightlight_round;
      case ActivityKind.walking:
        title = 'Tip de exploración';
        tip = 'Caminar desbloquea mapa y XP. Bonus secreto si sonríes como NPC amigable.';
        icon = Icons.explore_outlined;
      case ActivityKind.running:
        title = 'Tip de sprint';
        tip = 'Vas en modo speedrun: mantén ritmo y no olvides hidratar tu barra de vida.';
        icon = Icons.local_fire_department_outlined;
      case ActivityKind.vehicle:
        title = 'Tip de viaje';
        tip = 'En vehículo no sumas tantos pasos... pero sí puntos de “llegué a tiempo”.';
        icon = Icons.route_outlined;
      case ActivityKind.unknown:
        title = 'Tip de conexión';
        tip = 'El GPS está cargando texturas. Mientras tanto, postura épica y hombros relajados.';
        icon = Icons.wifi_tethering_error_rounded;
    }

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
