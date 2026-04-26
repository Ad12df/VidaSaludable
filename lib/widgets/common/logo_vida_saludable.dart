import 'package:flutter/material.dart';

class LogoVidaSaludable extends StatelessWidget {
  const LogoVidaSaludable({super.key});
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                base.primary.withValues(alpha: 0.2),
                base.secondary.withValues(alpha: 0.25),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/WhatsApp Image 2026-03-02 at 9.13.49 AM (1).jpeg',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.spa,
                  size: 64,
                  color: Color(0xFF689F38),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Vitu',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
