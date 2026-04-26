import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../base_datos/firebase_service.dart';
import './session_detail_screen.dart';

// Pantalla que solicita al modelo IA rutinas de entrenamiento personalizadas
class RoutineSuggestionScreen extends StatefulWidget {
  final String kind;
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;
  const RoutineSuggestionScreen({
    super.key,
    required this.kind,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });
  @override
  State<RoutineSuggestionScreen> createState() =>
      _RoutineSuggestionScreenState();
}

// Estado: orquesta la llamada a IA y el parseo de resultados
class _RoutineSuggestionScreenState extends State<RoutineSuggestionScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, String>> _suggestions = [];
  late GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    // Inicializa el modelo con la misma clave/versión usada en nutrición
    const apiKey = 'AIzaSyCH1dOX3gt-gwmSv3LD1bJ7WpGU8d0b6X4';
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
    // Pre-carga completa de rutinas con Gemini antes de mostrar lista
    _fetchSuggestions();
  }

  // Construye prompt con datos del usuario y pide 4 sesiones en formato JSON
  Future<void> _fetchSuggestions() async {
    final u = await FirebaseService.getCurrentUser();
    final genero = u?.genero ?? 'no especificado';
    final edad = u?.edad ?? 0;
    final altura = u?.altura ?? 0.0;
    final peso = u?.peso ?? 0.0;
    final isStrength = widget.kind.toLowerCase().contains('fuerza');
    // Mantengo precarga y carga instantánea
    final prompt = isStrength
        // Prompt Gemini modificado para rutinas variadas y realistas
        ? 'Genera 5 rutinas de fuerza diferentes y realistas para un usuario de nivel intermedio. '
              'Nombres variados y atractivos (ej. Push/Pull/Legs, Full Body Explosivo, Upper Body Hypertrophy, Lower Body Strength, Core & Mobility). '
              'Cada rutina con duración en minutos (45-75), enfoque claro, 4-6 ejercicios con series/reps realistas y tiempo estimado por ejercicio. '
              'Responde en formato JSON limpio para que se pueda parsear directamente. '
              'No repitas nombres como "Tren Superior A" siempre. '
              'Estructura: [{"nombre": string, "duracion": number, "descripcion": string, '
              '"ejercicios": [{"nombre": string, "descripcion": string, "detalle": string, "tiempo": string, "reps": string}]}]'
        : 'Genera 4 sesiones de ${widget.kind} para un usuario ($genero, $edad años, $altura cm, $peso kg). '
              'Responde SOLO como un JSON array. Cada sesión debe tener: '
              '{"nombre": string, "duracion": number, "descripcion": string, '
              '"ejercicios": [{"nombre": string, "descripcion": string, "tiempo": string, "reps": string, "detalle": string}]}';
    try {
      final res = await _model.generateContent([Content.text(prompt)]);
      final text = res.text?.trim() ?? '';
      final parsed = _parseRoutineList(text)
          .map(
            (m) => {
              ...m,
              // Duración y tiempos en minutos claros y creíbles
              if ((m['duracion'] ?? '').trim().isNotEmpty)
                'duracion': (() {
                  final raw = (m['duracion'] ?? '').trim();
                  final mm = RegExp(r'(\d{1,3})').firstMatch(raw);
                  final digits = mm?.group(1) ?? '';
                  if (digits.isNotEmpty) return '$digits minutos';
                  return raw;
                })(),
              'tipo': widget.kind.toLowerCase().contains('fuerza')
                  ? 'strength'
                  : (widget.kind.toLowerCase().contains('yoga')
                        ? 'yoga'
                        : 'stretching'),
            },
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _suggestions = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Intenta parsear la respuesta del modelo como lista JSON de rutinas
  List<Map<String, String>> _parseRoutineList(String text) {
    String clean = text.trim();
    clean = clean.replaceAll('```json', '').replaceAll('```', '').trim();
    try {
      dynamic data;
      try {
        data = json.decode(clean);
      } catch (e) {
        final start = clean.indexOf('[');
        final end = clean.lastIndexOf(']');
        if (start != -1 && end != -1 && end > start) {
          final jsonStr = clean.substring(start, end + 1);
          data = json.decode(jsonStr);
        }
      }
      if (data is List) {
        return data
            .whereType<Map>()
            .map((item) {
              final nombre = '${item['nombre'] ?? item['name'] ?? ''}'.trim();
              if (nombre.isEmpty) return <String, String>{};
              final duracion = '${item['duracion'] ?? item['duration'] ?? ''}'
                  .trim();
              final desc = '${item['descripcion'] ?? item['description'] ?? ''}'
                  .trim();
              final ejerciciosRaw = item['ejercicios'] ?? item['exercises'];
              String ejercicios = '';
              String ejerciciosJson = '';
              if (ejerciciosRaw is List) {
                if (ejerciciosRaw.isNotEmpty && ejerciciosRaw.first is Map) {
                  final norm = <Map<String, String>>[];
                  for (final e in ejerciciosRaw) {
                    final m = Map<String, dynamic>.from(e as Map);
                    final enombre = '${m['nombre'] ?? m['name'] ?? ''}'.trim();
                    final edet =
                        '${m['seriesRepsDuracion'] ?? m['reps'] ?? m['series'] ?? m['detalle'] ?? ''}'
                            .trim();
                    final tiempo =
                        '${m['time'] ?? m['tiempo'] ?? m['duracion'] ?? m['duration'] ?? ''}'
                            .trim();
                    final reps = '${m['reps'] ?? m['repeticiones'] ?? ''}'
                        .trim();
                    final edesc =
                        '${m['descripcion'] ?? m['description'] ?? ''}'.trim();
                    final out = <String, String>{};
                    if (enombre.isNotEmpty) out['nombre'] = enombre;
                    if (edet.isNotEmpty) out['detalle'] = edet;
                    if (tiempo.isNotEmpty) out['tiempo'] = tiempo;
                    if (reps.isNotEmpty) out['reps'] = reps;
                    if (edesc.isNotEmpty) out['descripcion'] = edesc;
                    if (out.isNotEmpty) norm.add(out);
                  }
                  ejerciciosJson = json.encode(norm);
                } else {
                  final lines = <String>[];
                  for (final e in ejerciciosRaw) {
                    final s = '$e'.trim();
                    if (s.isEmpty) continue;
                    lines.add(s);
                  }
                  ejercicios = lines.join('\n');
                }
              } else if (ejerciciosRaw is String) {
                ejercicios = ejerciciosRaw.trim();
              }
              return {
                'nombre': nombre,
                if (duracion.isNotEmpty) 'duracion': duracion,
                if (desc.isNotEmpty) 'descripcion': desc,
                if (ejercicios.isNotEmpty) 'ejercicios': ejercicios,
                if (ejerciciosJson.isNotEmpty) 'ejerciciosJson': ejerciciosJson,
              };
            })
            .where((m) => m.isNotEmpty)
            .cast<Map<String, String>>()
            .toList();
      }
    } catch (_) {}
    
    // Parseo manual básico por líneas
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final out = <Map<String, String>>[];
    Map<String, String> current = {};
    for (final l in lines) {
      final lower = l.toLowerCase();
      if (RegExp(r'^\d+[\)\.]').hasMatch(l) || lower.startsWith('- ')) {
        if (current.isNotEmpty) out.add(current);
        current = {'nombre': l.replaceFirst(RegExp(r'^\d+[\)\.]'), '').trim()};
      } else if (lower.contains('minutos') || lower.contains('min')) {
        current['duracion'] = l;
      } else if (current.containsKey('nombre')) {
        current['descripcion'] = '${current['descripcion'] ?? ''} $l';
      }
    }
    if (current.isNotEmpty) out.add(current);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Rutinas de ${widget.kind}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final s = _suggestions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        title: Text(
                          s['nombre'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${s['duracion'] ?? ''}\n${s['descripcion'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SessionDetailScreen(
                                title: s['nombre'] ?? '',
                                duration: s['duracion'] ?? '',
                                description: s['descripcion'] ?? '',
                                exercises: s['ejercicios'] ?? '',
                                exercisesJson: s['ejerciciosJson'],
                                type: s['tipo'] ?? 'strength',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                )),
    );
  }
}
