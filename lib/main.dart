// Aplicación de salud integral "Vitu": nutrición, ejercicio, hidratación y sueño
// Archivo principal con la inicialización y el widget raíz de la app
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import './base_datos/firebase_service.dart';
import './firebase_options.dart';
import './modelos/user_settings.dart';
import './pantallas/inicio/splash_screen.dart';
import './servicios/sleep_auto_service.dart';
import './widgets/common/offline_screen.dart';

/// Punto de entrada de la aplicación
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseService.init();
  SleepAutoService.instance.start();

  // Configuración de la interfaz del sistema
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const MyApp());
}

/// Widget principal de la aplicación que configura el tema global dinámico
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _fontFamily;
  String _appTheme = 'emerald';
  bool _isOffline = false;
  bool _checkingConnection = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _periodicConnectionTimer;

  @override
  void initState() {
    super.initState();
    _loadUserTheme();
    _initConnectivityWatcher();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _periodicConnectionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUserTheme() async {
    final email = await FirebaseService.getCurrentUserEmail();
    if (email == null) return;

    final UserSettings? settings = await FirebaseService.getSettingsForUser(email);
    if (settings == null || !mounted) return;

    setState(() {
      _fontFamily = settings.fontFamily;
      _appTheme = settings.appTheme ?? 'emerald';
    });
  }

  Future<void> _initConnectivityWatcher() async {
    final connectivity = Connectivity();

    await _recheckConnection();

    _connectivitySub = connectivity.onConnectivityChanged.listen((_) async {
      await _recheckConnection();
    });

    _periodicConnectionTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _recheckConnection();
    });
  }

  Future<void> _recheckConnection() async {
    final results = await Connectivity().checkConnectivity();

    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    bool hasInternet = false;

    if (hasNetwork) {
      hasInternet = await _hasRealInternet();
    }

    if (!mounted) return;
    setState(() {
      _isOffline = !(hasNetwork && hasInternet);
      _checkingConnection = false;
    });
  }

  Future<bool> _hasRealInternet() async {
    try {
      final response = await InternetAddress.lookup('example.com');
      return response.isNotEmpty && response.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } catch (_) {
      return false;
    }
  }

  ThemeData _buildTheme() {
    final (brightness, seed, font) = _themePreset(_appTheme, _fontFamily);

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
      useMaterial3: true,
      fontFamily: font,
    );
  }

  (Brightness, Color, String?) _themePreset(String theme, String? selectedFont) {
    switch (theme) {
      case 'violet_night':
        return (Brightness.dark, const Color(0xFF8B5CF6), selectedFont ?? 'Poppins');
      case 'ocean':
        return (Brightness.light, const Color(0xFF06B6D4), selectedFont ?? 'Montserrat');
      case 'emerald':
      default:
        return (Brightness.light, const Color(0xFF22C55E), selectedFont);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitu',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: _checkingConnection
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isOffline
                ? const OfflineScreen()
                : const SplashScreen(),
    );
  }
}
