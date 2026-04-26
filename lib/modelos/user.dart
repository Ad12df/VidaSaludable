class User {
  final String nombre;
  final String apellido;
  final String genero;
  final int edad;
  final double altura;
  final double peso;
  final String correo;
  final String contrasena;
  final String? photoPath;

  const User({
    required this.nombre,
    required this.apellido,
    required this.genero,
    required this.edad,
    required this.altura,
    required this.peso,
    required this.correo,
    required this.contrasena,
    this.photoPath,
  });

  Map<String, dynamic> toMap() => {
    'nombre': nombre,
    'apellido': apellido,
    'genero': genero,
    'edad': edad,
    'altura': altura,
    'peso': peso,
    'correo': correo,
    'contrasena': contrasena,
    'photoPath': photoPath,
  };

  factory User.fromMap(Map map) {
    return User(
      nombre: '${map['nombre'] ?? ''}',
      apellido: '${map['apellido'] ?? ''}',
      genero: '${map['genero'] ?? ''}',
      edad: (map['edad'] is int)
          ? map['edad']
          : int.tryParse('${map['edad'] ?? 0}') ?? 0,
      altura: (map['altura'] is double)
          ? map['altura']
          : double.tryParse('${map['altura'] ?? 0}') ?? 0.0,
      peso: (map['peso'] is double)
          ? map['peso']
          : double.tryParse('${map['peso'] ?? 0}') ?? 0.0,
      correo: '${map['correo'] ?? ''}',
      contrasena: '${map['contrasena'] ?? ''}',
      photoPath: map['photoPath'] == null
          ? null
          : '${map['photoPath']}',
    );
  }
}
