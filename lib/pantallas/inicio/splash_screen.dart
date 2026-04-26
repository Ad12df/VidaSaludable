import 'dart:async';
import 'package:flutter/material.dart';
import '../../base_datos/firebase_service.dart';
import '../auth/login_register_screen.dart';
import './vida_plus_app.dart';
import '../../widgets/common/logo_vida_saludable.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.8, end: 1.0));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    
    Timer(const Duration(milliseconds: 2200), () async {
      if (!mounted) return;
      final hasUser = await FirebaseService.getCurrentUser() != null;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => hasUser ? const VidaPlusApp() : const LoginRegisterScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    Color lighten(Color c, double amount) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
          .toColor();
    }

    Color darken(Color c, double amount) {
      final hsl = HSLColor.fromColor(c);
      return hsl
          .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
          .toColor();
    }

    const seed = Color(0xFFE53935);
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.0, 1.0],
                colors: isDark
                    ? [const Color(0xFF0F0F10), const Color(0xFF1B1B1D)]
                    : [lighten(seed, 0.22), darken(seed, 0.06)],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: const LogoVidaSaludable(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
