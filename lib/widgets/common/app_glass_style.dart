import 'dart:ui';
import 'package:flutter/material.dart';

class AppGlassStyle {
  static const List<Color> backgroundGradient = [
    Color(0xFF0F0B25),
    Color(0xFF1D1240),
    Color(0xFF102A5E),
  ];

  static const List<Color> primaryGradient = [
    Color(0xFF8B5CF6),
    Color(0xFF2563EB),
  ];

  static const List<Color> accentGradient = [
    Color(0xFF8B5CF6),
    Color(0xFF22D3EE),
  ];

  static BoxDecoration glassCardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      color: Colors.white.withValues(alpha: 0.1),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55210B45),
          blurRadius: 30,
          offset: Offset(0, 14),
        ),
      ],
    );
  }

  static AppBar appBar({required String title}) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
    );
  }
}

class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-1.0, -1.0),
          end: Alignment(1.0, 1.0),
          colors: AppGlassStyle.backgroundGradient,
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: -90,
            top: -70,
            child: _GlowOrb(size: 260, color: Color(0xFF7C3AED)),
          ),
          const Positioned(
            right: -70,
            top: 70,
            child: _GlowOrb(size: 220, color: Color(0xFF2563EB)),
          ),
          const Positioned(
            right: -100,
            bottom: -80,
            child: _GlowOrb(size: 290, color: Color(0xFF06B6D4)),
          ),
          child,
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: AppGlassStyle.glassCardDecoration(),
          child: child,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.5),
              color.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}
