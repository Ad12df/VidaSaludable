class Receta {
  final String nombre;
  final String tiempo;
  final String dificultad;
  final String? imagenUrl;
  final String? imagenDesc;
  final String? porque;
  final List<Ingrediente> ingredientes;
  final List<String> steps;
  final Nutricion? nutricion;

  Receta({
    required this.nombre,
    required this.tiempo,
    required this.dificultad,
    this.porque,
    required this.ingredientes,
    required this.steps,
    this.nutricion,
    this.imagenUrl,
    this.imagenDesc,
  });

  String get recipeId {
    final ingredientesKey =
        ingredientes.map((i) => '${i.nombre}|${i.tienda}').join('||');
    final stepsKey = steps.join('||');
    final raw = '${nombre.trim().toLowerCase()}__'
        '${tiempo.trim().toLowerCase()}__'
        '${dificultad.trim().toLowerCase()}__'
        '${ingredientesKey}__'
        '$stepsKey';
    return raw.hashCode.toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'recipeId': recipeId,
      'nombre': nombre,
      'tiempo': tiempo,
      'dificultad': dificultad,
      'imagenUrl': imagenUrl,
      'imagenDesc': imagenDesc,
      'porque': porque,
      'ingredientes': ingredientes.map((i) => i.toMap()).toList(),
      'steps': steps,
      'nutricion': nutricion?.toMap(),
    };
  }

  factory Receta.fromMap(Map<String, dynamic> map) {
    final ingredientesRaw = map['ingredientes'];
    final stepsRaw = map['steps'];

    return Receta(
      nombre: (map['nombre'] ?? '').toString(),
      tiempo: (map['tiempo'] ?? '30 min').toString(),
      dificultad: (map['dificultad'] ?? 'Media').toString(),
      imagenUrl: map['imagenUrl']?.toString(),
      imagenDesc: map['imagenDesc']?.toString(),
      porque: map['porque']?.toString(),
      ingredientes: (ingredientesRaw is List ? ingredientesRaw : const [])
          .whereType<Map>()
          .map((e) => Ingrediente.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      steps: (stepsRaw is List ? stepsRaw : const [])
          .map((e) => e.toString())
          .toList(),
      nutricion: map['nutricion'] is Map
          ? Nutricion.fromMap(Map<String, dynamic>.from(map['nutricion']))
          : null,
    );
  }
}

class Ingrediente {
  final String nombre;
  final String tienda;
  Ingrediente(this.nombre, this.tienda);

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'tienda': tienda,
      };

  factory Ingrediente.fromMap(Map<String, dynamic> map) {
    return Ingrediente(
      (map['nombre'] ?? '').toString(),
      (map['tienda'] ?? 'General').toString(),
    );
  }
}

class Nutricion {
  final int kcal;
  final double proteinas;
  final double carbohidratos;
  final double grasas;
  Nutricion({
    required this.kcal,
    required this.proteinas,
    required this.carbohidratos,
    required this.grasas,
  });

  Map<String, dynamic> toMap() => {
        'kcal': kcal,
        'proteinas': proteinas,
        'carbohidratos': carbohidratos,
        'grasas': grasas,
      };

  factory Nutricion.fromMap(Map<String, dynamic> map) {
    return Nutricion(
      kcal: (map['kcal'] as num?)?.round() ?? 0,
      proteinas: (map['proteinas'] as num?)?.toDouble() ?? 0,
      carbohidratos: (map['carbohidratos'] as num?)?.toDouble() ?? 0,
      grasas: (map['grasas'] as num?)?.toDouble() ?? 0,
    );
  }
}
