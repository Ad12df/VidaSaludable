import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../base_datos/firebase_service.dart';
import '../../modelos/receta.dart';
import '../../widgets/common/app_glass_style.dart';

enum MealType { desayuno, almuerzo, cena }

enum BudgetLevel { barato, medio, caro }

class RecipeFilters {
  final String alergias;
  final String preferencias;
  final String ingredienteObligatorio;
  final MealType mealType;
  final BudgetLevel budgetLevel;

  const RecipeFilters({
    this.alergias = '',
    this.preferencias = '',
    this.ingredienteObligatorio = '',
    this.mealType = MealType.almuerzo,
    this.budgetLevel = BudgetLevel.medio,
  });

  RecipeFilters copyWith({
    String? alergias,
    String? preferencias,
    String? ingredienteObligatorio,
    MealType? mealType,
    BudgetLevel? budgetLevel,
  }) {
    return RecipeFilters(
      alergias: alergias ?? this.alergias,
      preferencias: preferencias ?? this.preferencias,
      ingredienteObligatorio: ingredienteObligatorio ?? this.ingredienteObligatorio,
      mealType: mealType ?? this.mealType,
      budgetLevel: budgetLevel ?? this.budgetLevel,
    );
  }

  bool get hasAnyFilter =>
      alergias.trim().isNotEmpty ||
      preferencias.trim().isNotEmpty ||
      ingredienteObligatorio.trim().isNotEmpty ||
      mealType != MealType.almuerzo ||
      budgetLevel != BudgetLevel.medio;

  String get mealTypeLabel {
    switch (mealType) {
      case MealType.desayuno:
        return 'Desayuno';
      case MealType.almuerzo:
        return 'Almuerzo';
      case MealType.cena:
        return 'Cena';
    }
  }

  String get budgetLabel {
    switch (budgetLevel) {
      case BudgetLevel.barato:
        return 'Barato';
      case BudgetLevel.medio:
        return 'Medio';
      case BudgetLevel.caro:
        return 'Caro';
    }
  }
}

class NutritionScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seedColor;
  final String? fontFamily;

  const NutritionScreen({
    super.key,
    required this.brightness,
    required this.seedColor,
    this.fontFamily,
  });

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  static const String _apiKeyFromEnv = String.fromEnvironment('GEMINI_API_KEY');
  static const String _fallbackApiKey = 'AIzaSyCH1dOX3gt-gwmSv3LD1bJ7WpGU8d0b6X4';
  static String get _effectiveApiKey =>
      _apiKeyFromEnv.trim().isNotEmpty ? _apiKeyFromEnv.trim() : _fallbackApiKey;

  late final GenerativeModel _model;

  File? _photo;
  final List<File> _savedPhotos = [];

  bool _analyzing = false;
  bool _cargandoRecetas = false;
  bool _cargandoGuardadas = false;
  DateTime? _lastRecipesFetchAt;

  String? _plato;
  int? _kcal;
  double? _prot;
  double? _carb;
  double? _fat;
  double? _fibra;

  String? _errorAnalisis;
  String? _errorRecetas;
  String? _errorGuardadas;

  List<Receta> _recetasRecomendadas = [];
  List<Receta> _recetasGuardadas = [];
  final Set<String> _savedRecipeIds = <String>{};
  RecipeFilters _filters = const RecipeFilters();

  bool get _hasNutrients =>
      _prot != null && _carb != null && _fat != null && (_prot! + _carb! + _fat!) > 0;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _effectiveApiKey);
    unawaited(_cargarRecetasGuardadas());
    unawaited(_cargarRecetasRecomendadas());
  }

  Future<void> _cargarRecetasGuardadas() async {
    if (!mounted) return;
    setState(() {
      _cargandoGuardadas = true;
      _errorGuardadas = null;
    });

    try {
      final email = await FirebaseService.getCurrentUserEmail();
      if (email == null || email.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _recetasGuardadas = [];
          _savedRecipeIds.clear();
          _errorGuardadas = 'Inicia sesión para ver recetas guardadas.';
          _cargandoGuardadas = false;
        });
        return;
      }

      final rows = await FirebaseService.getSavedRecipesForUser(email.trim().toLowerCase());
      final recetas = <Receta>[];
      final ids = <String>{};

      for (final row in rows) {
        final raw = row['recipe'];
        if (raw is Map) {
          final receta = Receta.fromMap(Map<String, dynamic>.from(raw));
          recetas.add(receta);
          ids.add(receta.recipeId);
        }
      }

      if (!mounted) return;
      setState(() {
        _recetasGuardadas = recetas;
        _savedRecipeIds
          ..clear()
          ..addAll(ids);
        _cargandoGuardadas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorGuardadas = 'No se pudieron cargar guardadas: $e';
        _cargandoGuardadas = false;
      });
    }
  }

  Future<void> _toggleGuardarReceta(Receta receta) async {
    final email = await FirebaseService.getCurrentUserEmail();
    if (email == null || email.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para guardar recetas en la nube.')),
      );
      return;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final recipeId = receta.recipeId;
    final alreadySaved = _savedRecipeIds.contains(recipeId);

    if (alreadySaved) {
      await FirebaseService.deleteSavedRecipeForUser(email: normalizedEmail, recipeId: recipeId);
    } else {
      await FirebaseService.saveRecipeForUser(
        email: normalizedEmail,
        recipeId: recipeId,
        recipeData: receta.toMap(),
      );
    }

    await _cargarRecetasGuardadas();
  }

  Future<void> _cargarRecetasRecomendadas({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _recetasRecomendadas.isNotEmpty &&
        _lastRecipesFetchAt != null &&
        DateTime.now().difference(_lastRecipesFetchAt!) < const Duration(minutes: 15)) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _cargandoRecetas = true;
      _errorRecetas = null;
    });

    try {
      if (_effectiveApiKey.isEmpty) {
        throw Exception('Falta GEMINI_API_KEY. Ejecuta con --dart-define=GEMINI_API_KEY=TU_API_KEY');
      }

      final u = await FirebaseService.getCurrentUser();
      final genero = (u?.genero ?? 'No especificado').toString();
      final edad = u?.edad ?? 0;
      final altura = u?.altura ?? 0.0;
      final peso = u?.peso ?? 0.0;

      final prompt =
          'Eres nutricionista clínico. Devuelve exactamente 3 recetas para este usuario: '
          'género: $genero, edad: $edad, altura: $altura, peso: $peso. '
          'Tipo de comida: ${_filters.mealTypeLabel}. Presupuesto: ${_filters.budgetLabel}. '
          '${_filters.alergias.trim().isNotEmpty ? 'Alergias: ${_filters.alergias.trim()}. ' : ''}'
          '${_filters.preferencias.trim().isNotEmpty ? 'Preferencias: ${_filters.preferencias.trim()}. ' : ''}'
          '${_filters.ingredienteObligatorio.trim().isNotEmpty ? 'Ingrediente obligatorio: ${_filters.ingredienteObligatorio.trim()}. ' : ''}'
          'Responde SOLO con JSON válido, sin markdown, sin texto extra, con estructura exacta: '
          '[{"nombre":"", "tiempo":"", "dificultad":"", "ingredientes":["",""], "steps":["",""]}]';

      final res = await _model.generateContent([Content.text(prompt)]);
      final text = (res.text ?? '').trim();
      final recetas = await compute(_parseRecetasInIsolate, text);

      if (recetas.isEmpty) {
        throw Exception('Gemini no devolvió recetas válidas.');
      }

      if (!mounted) return;
      setState(() {
        _recetasRecomendadas = recetas.take(3).toList();
        _lastRecipesFetchAt = DateTime.now();
        _cargandoRecetas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _recetasRecomendadas = [];
        _errorRecetas = _friendlyAiError(e, forScan: false);
        _cargandoRecetas = false;
      });
    }
  }

  String _friendlyAiError(Object e, {required bool forScan}) {
    final msg = e.toString();
    final low = msg.toLowerCase();

    if (low.contains('quota') || low.contains('rate') || low.contains('429')) {
      return forScan
          ? 'Límite de uso de IA alcanzado. Espera unos minutos o usa una API key con cuota activa.'
          : 'No se pudieron generar recetas ahora por límite de uso de IA. Intenta de nuevo en unos minutos.';
    }

    if (low.contains('api key') || low.contains('permission') || low.contains('unauthorized')) {
      return 'La clave de IA no es válida o no tiene permisos. Revisa GEMINI_API_KEY.';
    }

    if (low.contains('format') || low.contains('json') || low.contains('unexpected character')) {
      return forScan
          ? 'La IA devolvió un formato inesperado al analizar la imagen. Intenta otra foto.'
          : 'La IA devolvió una respuesta inválida. Vuelve a tocar "Actualizar".';
    }

    return forScan
        ? 'No se pudo analizar la imagen en este momento. Intenta nuevamente.'
        : 'No se pudieron generar recetas IA en este momento. Intenta nuevamente.';
  }

  Future<void> _openFiltersSheet() async {
    final result = await showModalBottomSheet<RecipeFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _RecipeFilterSheet(initial: _filters),
    );

    if (result == null || !mounted) return;
    setState(() => _filters = result);
    await _cargarRecetasRecomendadas(forceRefresh: true);
  }

  Future<void> _pickFromSource(ImageSource source) async {
    if (_analyzing) return;

    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: source, imageQuality: 85);
    if (xfile == null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/vitu_food_$ts.jpg');
      await file.writeAsBytes(await xfile.readAsBytes());

      if (!mounted) return;
      setState(() {
        _photo = file;
        _savedPhotos.insert(0, file);
        _analyzing = true;
        _errorAnalisis = null;
        _plato = null;
        _kcal = null;
        _prot = null;
        _carb = null;
        _fat = null;
        _fibra = null;
      });

      await _analizarConGemini(file);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorAnalisis = _friendlyAiError(e, forScan: true);
      });
    } finally {
      if (mounted) {
        setState(() => _analyzing = false);
      }
    }
  }

  Future<void> _analizarConGemini(File foto) async {
    if (_effectiveApiKey.isEmpty) {
      throw Exception('Falta GEMINI_API_KEY. Ejecuta con --dart-define=GEMINI_API_KEY=TU_API_KEY');
    }

    final bytes = await foto.readAsBytes();

    final prompt =
        'Analiza la imagen del alimento y devuelve SOLO JSON válido (sin markdown ni texto extra) con estructura: '
        '{"plato":"", "calorias":0, "proteinas_g":0, "carbohidratos_g":0, "grasas_g":0, "fibra_g":0}.';

    final content = [
      Content.multi([
        TextPart(prompt),
        DataPart('image/jpeg', bytes),
      ]),
    ];

    final res = await _model.generateContent(content);
    final text = (res.text ?? '').trim().replaceAll('```json', '').replaceAll('```', '').trim();

    dynamic data;
    try {
      data = json.decode(text);
    } catch (_) {
      final s = text.indexOf('{');
      final e = text.lastIndexOf('}');
      if (s != -1 && e != -1 && e > s) {
        data = json.decode(text.substring(s, e + 1));
      } else {
        throw Exception('Formato JSON inválido en respuesta de Gemini.');
      }
    }

    if (data is! Map) {
      throw Exception('Respuesta no válida de Gemini.');
    }

    final m = Map<String, dynamic>.from(data);

    if (!mounted) return;
    setState(() {
      _plato = (m['plato'] ?? 'Plato detectado').toString();
      _kcal = (m['calorias'] as num?)?.round() ?? 0;
      _prot = (m['proteinas_g'] as num?)?.toDouble() ?? 0;
      _carb = (m['carbohidratos_g'] as num?)?.toDouble() ?? 0;
      _fat = (m['grasas_g'] as num?)?.toDouble() ?? 0;
      _fibra = (m['fibra_g'] as num?)?.toDouble() ?? 0;
      _errorAnalisis = null;
    });
  }

  Widget _macroChip(String label, String value, IconData icon, List<Color> gradient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openRecipeDetail(Receta receta) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecipeDetailSheet(receta: receta),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: AppGlassStyle.primaryGradient),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white54,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final chips = <Widget>[
      _MetaPill(icon: Icons.free_breakfast_rounded, text: _filters.mealTypeLabel),
      _MetaPill(icon: Icons.sell_rounded, text: _filters.budgetLabel),
    ];

    if (_filters.alergias.trim().isNotEmpty) {
      chips.add(_MetaPill(icon: Icons.no_food_rounded, text: 'Sin: ${_filters.alergias.trim()}'));
    }
    if (_filters.preferencias.trim().isNotEmpty) {
      chips.add(_MetaPill(icon: Icons.favorite_rounded, text: _filters.preferencias.trim()));
    }
    if (_filters.ingredienteObligatorio.trim().isNotEmpty) {
      chips.add(_MetaPill(icon: Icons.check_circle_rounded, text: 'Con: ${_filters.ingredienteObligatorio.trim()}'));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppGlassStyle.appBar(title: 'Nutrición'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analiza tu Comida Hoy',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Toma una foto para registrar nutrientes',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 14),
                if (_photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(_photo!, height: 230, width: double.infinity, fit: BoxFit.cover),
                  )
                else
                  Container(
                    height: 230,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                    ),
                    child: const Center(
                      child: Icon(Icons.photo_camera_rounded, size: 70, color: Color(0xFF79D3C8)),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 170,
                  child: _actionButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Tomar Foto',
                    onTap: _analyzing ? null : () => _pickFromSource(ImageSource.camera),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _analyzing ? null : () => _pickFromSource(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Elegir desde galería'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassCard(
            child: Column(
              children: [
                if (!_hasNutrients)
                  Container(
                    height: 210,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _analyzing
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF8B5CF6)),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Tomamos tu foto y la analizamos con IA...',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        : _errorAnalisis != null
                            ? Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  _errorAnalisis!,
                                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                                ),
                              )
                            : const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fastfood_rounded, size: 58, color: Colors.white54),
                                    SizedBox(height: 8),
                                    Text(
                                      'Toma una foto para analizar nutrientes',
                                      style: TextStyle(color: Colors.white70, fontSize: 21),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                  ),
                const SizedBox(height: 12),
                if (_hasNutrients) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _plato ?? '',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$_kcal kcal', style: TextStyle(fontSize: 18, color: cs.primary)),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _macroChip(
                        'Proteínas',
                        '${_prot?.toStringAsFixed(1) ?? '0'} g',
                        Icons.fitness_center_rounded,
                        const [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
                      ),
                      _macroChip(
                        'Carbohidratos',
                        '${_carb?.toStringAsFixed(1) ?? '0'} g',
                        Icons.grain_rounded,
                        const [Color(0xFF00B4D8), Color(0xFF0077B6)],
                      ),
                      _macroChip(
                        'Grasas',
                        '${_fat?.toStringAsFixed(1) ?? '0'} g',
                        Icons.local_fire_department_rounded,
                        const [Color(0xFFFF7B00), Color(0xFFFF9500)],
                      ),
                      _macroChip(
                        'Fibra',
                        '${_fibra?.toStringAsFixed(1) ?? '0'} g',
                        Icons.spa_rounded,
                        const [Color(0xFF2EC4B6), Color(0xFF1B9AAA)],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    height: 220,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 56,
                        sectionsSpace: 3,
                        sections: [
                          PieChartSectionData(
                            value: _prot!,
                            color: const Color(0xFFE63946),
                            title: 'Prot',
                            radius: 64,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          PieChartSectionData(
                            value: _carb!,
                            color: const Color(0xFF2A9D8F),
                            title: 'Carb',
                            radius: 64,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          PieChartSectionData(
                            value: _fat!,
                            color: const Color(0xFFF4A261),
                            title: 'Grasa',
                            radius: 64,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          PieChartSectionData(
                            value: _fibra!,
                            color: const Color(0xFF4CC9B0),
                            title: 'Fibra',
                            radius: 64,
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Recetas recomendadas',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _openFiltersSheet,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Filtros'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _cargarRecetasRecomendadas(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualizar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _cargandoGuardadas
                    ? null
                    : () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _SavedRecipesSheet(
                            recetas: _recetasGuardadas,
                            onOpenRecipe: _openRecipeDetail,
                            onRemoveRecipe: _toggleGuardarReceta,
                            loading: _cargandoGuardadas,
                            error: _errorGuardadas,
                          ),
                        );
                      },
                icon: const Icon(Icons.bookmarks_rounded, size: 18),
                label: const Text('Guardadas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFilterChips(),
          const SizedBox(height: 8),
          if (_cargandoRecetas)
            const LinearProgressIndicator()
          else if (_errorRecetas != null)
            Text(_errorRecetas!, style: const TextStyle(color: Colors.redAccent))
          else if (_recetasRecomendadas.isEmpty)
            const Text('No hay recetas disponibles por ahora.', style: TextStyle(color: Colors.white70)),
          ..._recetasRecomendadas.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openRecipeDetail(r),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0x332A9D8F), Color(0x336A4C93)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 10,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.nombre,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _MetaPill(icon: Icons.schedule_rounded, text: r.tiempo),
                                  _MetaPill(icon: Icons.bar_chart_rounded, text: r.dificultad),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: _savedRecipeIds.contains(r.recipeId) ? 'Quitar de guardadas' : 'Guardar',
                          onPressed: () => _toggleGuardarReceta(r),
                          icon: Icon(
                            _savedRecipeIds.contains(r.recipeId)
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<Receta> _parseRecetasInIsolate(String raw) {
  String clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
  clean = clean.replaceAll(RegExp(r'[\u201C\u201D]'), '"');
  clean = clean.replaceAll(RegExp(r'[\u2018\u2019]'), "'");

  dynamic data;
  try {
    data = json.decode(clean);
  } catch (_) {
    final s = clean.indexOf('[');
    final e = clean.lastIndexOf(']');
    if (s != -1 && e != -1 && e > s) {
      final candidate = clean.substring(s, e + 1);
      try {
        data = json.decode(candidate);
      } catch (_) {
        final sanitized = candidate
            .replaceAll(RegExp(r',\s*([}\]])'), r'$1')
            .replaceAll(RegExp(r'[\u201C\u201D]'), '"')
            .replaceAll(RegExp(r'[\u2018\u2019]'), "'");
        data = json.decode(sanitized);
      }
    }
  }

  if (data is! List) return [];

  return data.whereType<Map>().map((m) {
    final mm = Map<String, dynamic>.from(m);
    final nombre = (mm['nombre'] ?? '').toString().trim();
    final tiempo = (mm['tiempo'] ?? '30 min').toString().trim();
    final dificultad = (mm['dificultad'] ?? 'Media').toString().trim();

    final ingsRaw = mm['ingredientes'];
    final pasosRaw = mm['steps'];

    final ingredientes = (ingsRaw is List ? ingsRaw : const [])
        .map((e) => Ingrediente(e.toString().trim(), 'General'))
        .where((i) => i.nombre.isNotEmpty)
        .toList();

    final pasos = (pasosRaw is List ? pasosRaw : const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (nombre.isEmpty) return null;

    return Receta(
      nombre: nombre,
      tiempo: tiempo,
      dificultad: dificultad,
      ingredientes: ingredientes,
      steps: pasos,
    );
  }).whereType<Receta>().toList();
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeFilterSheet extends StatefulWidget {
  final RecipeFilters initial;

  const _RecipeFilterSheet({required this.initial});

  @override
  State<_RecipeFilterSheet> createState() => _RecipeFilterSheetState();
}

class _RecipeFilterSheetState extends State<_RecipeFilterSheet> {
  late final TextEditingController _alergiasCtrl;
  late final TextEditingController _preferenciasCtrl;
  late final TextEditingController _ingredienteCtrl;

  late MealType _mealType;
  late BudgetLevel _budgetLevel;

  @override
  void initState() {
    super.initState();
    _alergiasCtrl = TextEditingController(text: widget.initial.alergias);
    _preferenciasCtrl = TextEditingController(text: widget.initial.preferencias);
    _ingredienteCtrl = TextEditingController(text: widget.initial.ingredienteObligatorio);
    _mealType = widget.initial.mealType;
    _budgetLevel = widget.initial.budgetLevel;
  }

  @override
  void dispose() {
    _alergiasCtrl.dispose();
    _preferenciasCtrl.dispose();
    _ingredienteCtrl.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70, size: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white54),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF161A33), Color(0xFF1E2542), Color(0xFF14203D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Filtros de recetas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _alergiasCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _deco('Alergias (ej: maní, mariscos)', Icons.no_food_rounded),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _preferenciasCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _deco('Preferencias (ej: vegetariana, alta proteína)', Icons.favorite_rounded),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _ingredienteCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _deco('Ingrediente obligatorio', Icons.check_circle_rounded),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tipo de comida',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: MealType.values.map((m) {
                  final selected = _mealType == m;
                  String label;
                  switch (m) {
                    case MealType.desayuno:
                      label = 'Desayuno';
                    case MealType.almuerzo:
                      label = 'Almuerzo';
                    case MealType.cena:
                      label = 'Cena';
                  }
                  return ChoiceChip(
                    selected: selected,
                    label: Text(label),
                    onSelected: (_) => setState(() => _mealType = m),
                    labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Precio objetivo',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: BudgetLevel.values.map((b) {
                  final selected = _budgetLevel == b;
                  String label;
                  switch (b) {
                    case BudgetLevel.barato:
                      label = 'Barato';
                    case BudgetLevel.medio:
                      label = 'Medio';
                    case BudgetLevel.caro:
                      label = 'Caro';
                  }
                  return ChoiceChip(
                    selected: selected,
                    label: Text(label),
                    onSelected: (_) => setState(() => _budgetLevel = b),
                    labelStyle: TextStyle(color: selected ? Colors.black : Colors.white),
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(const RecipeFilters());
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        foregroundColor: Colors.white70,
                      ),
                      child: const Text('Resetear'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          RecipeFilters(
                            alergias: _alergiasCtrl.text.trim(),
                            preferencias: _preferenciasCtrl.text.trim(),
                            ingredienteObligatorio: _ingredienteCtrl.text.trim(),
                            mealType: _mealType,
                            budgetLevel: _budgetLevel,
                          ),
                        );
                      },
                      child: const Text('Aplicar filtros'),
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SavedRecipesSheet extends StatelessWidget {
  final List<Receta> recetas;
  final Future<void> Function(Receta) onOpenRecipe;
  final Future<void> Function(Receta) onRemoveRecipe;
  final bool loading;
  final String? error;

  const _SavedRecipesSheet({
    required this.recetas,
    required this.onOpenRecipe,
    required this.onRemoveRecipe,
    required this.loading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(
          colors: [Color(0xFF131833), Color(0xFF1A2140), Color(0xFF101E3A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recetas guardadas',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                        ? Center(
                            child: Text(
                              error!,
                              style: const TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : recetas.isEmpty
                            ? const Center(
                                child: Text(
                                  'No tienes recetas guardadas todavía.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : ListView.separated(
                                itemCount: recetas.length,
                                separatorBuilder: (_, separatorIndex) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final r = recetas[i];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white24),
                                    ),
                                    child: ListTile(
                                      title: Text(r.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                      subtitle: Text('${r.tiempo} • ${r.dificultad}', style: const TextStyle(color: Colors.white70)),
                                      onTap: () async {
                                        await onOpenRecipe(r);
                                      },
                                      trailing: IconButton(
                                        onPressed: () => onRemoveRecipe(r),
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeDetailSheet extends StatelessWidget {
  final Receta receta;

  const _RecipeDetailSheet({
    required this.receta,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        gradient: LinearGradient(
          colors: [
            Color(0xFF1B1740),
            Color(0xFF201A4D),
            Color(0xFF142B57),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 14 + bottom),
          child: Column(
            children: [
              Container(
                width: 54,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      receta.nombre,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _MetaPill(icon: Icons.schedule_rounded, text: receta.tiempo),
                        _MetaPill(icon: Icons.bar_chart_rounded, text: receta.dificultad),
                        _MetaPill(icon: Icons.restaurant_rounded, text: '${receta.ingredientes.length} ingredientes'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Ingredientes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...receta.ingredientes.map(
                      (i) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF2EC4B6), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                i.nombre,
                                style: const TextStyle(color: Colors.white70, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Paso a paso',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...receta.steps.asMap().entries.map(
                      (entry) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF8B5CF6),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
