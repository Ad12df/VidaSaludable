import 'dart:convert';
import 'package:flutter/material.dart';

class SessionDetailScreen extends StatelessWidget {
  final String title;
  final String duration;
  final String description;
  final String exercises;
  final String? exercisesJson;
  final String type;

  const SessionDetailScreen({
    super.key,
    required this.title,
    required this.duration,
    required this.description,
    required this.exercises,
    this.exercisesJson,
    required this.type,
  });

  List<Map<String, String>> _buildExercises() {
    if (exercisesJson != null && exercisesJson!.isNotEmpty) {
      try {
        final data = json.decode(exercisesJson!);
        if (data is List) {
          return data.whereType<Map>().map((e) {
            final m = Map<String, dynamic>.from(e);
            final n = '${m['nombre'] ?? ''}'.trim();
            final d = '${m['detalle'] ?? ''}'.trim();
            final t = '${m['tiempo'] ?? ''}'.trim();
            final r = '${m['reps'] ?? ''}'.trim();
            final desc = '${m['descripcion'] ?? ''}'.trim();
            return {
              'nombre': n,
              'detalle': d,
              'tiempo': t,
              'reps': r,
              'descripcion': desc,
            };
          }).toList();
        }
      } catch (_) {}
    }
    final lines = exercises
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return lines.map((l) {
      String name = l;
      String det = '';
      String t = '';
      String desc = '';
      if (l.contains(':')) {
        final idx = l.indexOf(':');
        name = l.substring(0, idx).trim();
        det = l.substring(idx + 1).trim();
      } else if (l.contains('-')) {
        final idx = l.indexOf('-');
        name = l.substring(0, idx).trim();
        det = l.substring(idx + 1).trim();
      }
      final p = RegExp(r'\(([^)]+)\)').firstMatch(l);
      if (p != null) desc = (p.group(1) ?? '').trim();
      if (det.isEmpty) {
        final r1 = RegExp(
          r'(\d+)\s*x\s*(\d+(?:-\d+)?)',
          caseSensitive: false,
        ).firstMatch(l);
        final r2 = RegExp(
          r'(\d+)\s*series?\s*(de)?\s*(\d+(?:-\d+)?)\s*reps?',
          caseSensitive: false,
        ).firstMatch(l);
        if (r1 != null) {
          det = '${r1.group(1)} series de ${r1.group(2)} reps';
        } else if (r2 != null) {
          det = '${r2.group(1)} series de ${r2.group(3)} reps';
        }
      }
      final m = RegExp(r'(\d+)\s*min', caseSensitive: false).firstMatch(l);
      if (m != null) t = '${m.group(1)} min';
      return {'nombre': name, 'detalle': det, 'tiempo': t, 'descripcion': desc};
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final items = _buildExercises();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(duration, style: TextStyle(color: cs.primary, fontSize: 18)),
          const SizedBox(height: 12),
          Text(description),
          const Divider(height: 40),
          const Text('Ejercicios', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...items.map((e) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(e['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${e['detalle'] ?? ''}\n${e['descripcion'] ?? ''}'),
                  trailing: Text(e['tiempo'] ?? ''),
                ),
              )),
        ],
      ),
    );
  }
}
