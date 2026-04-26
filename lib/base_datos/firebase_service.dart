import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:shared_preferences/shared_preferences.dart';

import '../modelos/user.dart';
import '../modelos/user_settings.dart';

/// Servicio centralizado para persistencia con Firebase (Cloud Firestore)
class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;

  static const String _currentUserEmailKey = 'current_user_email';
  static SharedPreferences? _prefsCache;
  static Future<SharedPreferences> _prefs() async {
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  static CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('users');
  static CollectionReference<Map<String, dynamic>> get _settingsCol =>
      _db.collection('user_settings');
  static CollectionReference<Map<String, dynamic>> get _exerciseCol =>
      _db.collection('daily_exercise');
  static CollectionReference<Map<String, dynamic>> get _hydrationCol =>
      _db.collection('hydration');
  static CollectionReference<Map<String, dynamic>> get _sleepCol =>
      _db.collection('sleep');
  static CollectionReference<Map<String, dynamic>> get _savedRecipesCol =>
      _db.collection('saved_recipes');

  /// Inicializa servicios locales necesarios (sesión local)
  static Future<void> init() async {
    _prefsCache ??= await SharedPreferences.getInstance();
  }

  // --- Gestión de Usuarios ---

  /// Registra o actualiza un usuario y lo establece como actual
  static Future<void> saveCurrentUser(User user) async {
    final normalizedEmail = user.correo.trim().toLowerCase();
    final sanitizedUser = User(
      nombre: user.nombre,
      apellido: user.apellido,
      genero: user.genero,
      edad: user.edad,
      altura: user.altura,
      peso: user.peso,
      correo: normalizedEmail,
      contrasena: '',
      photoPath: user.photoPath,
    );

    await _usersCol
        .doc(normalizedEmail)
        .set(sanitizedUser.toMap(), SetOptions(merge: true));
    await login(normalizedEmail);
  }

  /// Registra credenciales en Firebase Auth y guarda el perfil en Firestore.
  static Future<void> registerUser(User user) async {
    final normalizedEmail = user.correo.trim().toLowerCase();

    final cred = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: user.contrasena,
    );

    final sanitizedUser = User(
      nombre: user.nombre,
      apellido: user.apellido,
      genero: user.genero,
      edad: user.edad,
      altura: user.altura,
      peso: user.peso,
      correo: normalizedEmail,
      contrasena: '',
      photoPath: user.photoPath,
    );

    await _usersCol.doc(normalizedEmail).set({
      ...sanitizedUser.toMap(),
      'uid': cred.user?.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await login(normalizedEmail);
  }

  /// Verifica credenciales con Firebase Auth.
  static Future<bool> verifyLogin(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _auth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    await login(normalizedEmail);
    return true;
  }

  /// Obtiene un usuario por su correo
  static Future<User?> getUserByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final doc = await _usersCol.doc(normalizedEmail).get();
    final data = doc.data();
    if (data == null) return null;
    return User.fromMap(data);
  }

  /// Inicia sesión (guarda correo localmente)
  static Future<void> login(String email) async {
    final prefs = await _prefs();
    await prefs.setString(_currentUserEmailKey, email.trim());
  }

  /// Cierra sesión
  static Future<void> logout() async {
    await _auth.signOut();
    final prefs = await _prefs();
    await prefs.remove(_currentUserEmailKey);
  }

  /// Obtiene correo del usuario actual
  static Future<String?> getCurrentUserEmail() async {
    final authEmail = _auth.currentUser?.email;
    final prefs = await _prefs();
    if (authEmail != null && authEmail.isNotEmpty) {
      await prefs.setString(_currentUserEmailKey, authEmail);
      return authEmail;
    }
    return prefs.getString(_currentUserEmailKey);
  }

  /// Obtiene el usuario actual
  static Future<User?> getCurrentUser() async {
    final email = await getCurrentUserEmail();
    if (email == null) return null;
    return getUserByEmail(email);
  }

  // --- Gestión de Ajustes ---

  /// Obtiene ajustes de un usuario
  static Future<UserSettings?> getSettingsForUser(String email) async {
    final doc = await _settingsCol.doc(email).get();
    final data = doc.data();
    if (data == null) return null;
    return UserSettings.fromMap(data);
  }

  /// Guarda ajustes de un usuario
  static Future<void> saveSettings(UserSettings settings) async {
    await _settingsCol
        .doc(settings.userId)
        .set(settings.toMap(), SetOptions(merge: true));
  }

  // --- Hidratación ---

  static String _dailyDocId(String email, String dateKey) => '${email}_$dateKey';

  /// Obtiene hidratación del día en ml
  static Future<int> getHydration(String email, String dateKey) async {
    final doc = await _hydrationCol.doc(_dailyDocId(email, dateKey)).get();
    final data = doc.data();
    if (data == null) return 0;
    final v = data['ml'];
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  /// Actualiza hidratación del día en ml
  static Future<void> setHydration(String email, String dateKey, int ml) async {
    await _hydrationCol.doc(_dailyDocId(email, dateKey)).set({
      'email': email,
      'dateKey': dateKey,
      'ml': ml,
    }, SetOptions(merge: true));
  }

  /// Añade ml a hidratación actual
  static Future<void> addHydrationMl(String email, String dateKey, int ml) async {
    final current = await getHydration(email, dateKey);
    await setHydration(email, dateKey, current + ml);
  }

  // --- Ejercicio ---

  /// Obtiene datos de ejercicio de un día
  static Future<Map<String, dynamic>?> getDailyExercise(
    String email,
    String dateKey,
  ) async {
    final doc = await _exerciseCol.doc(_dailyDocId(email, dateKey)).get();
    final data = doc.data();
    if (data == null) return null;
    return Map<String, dynamic>.from(data['data'] ?? <String, dynamic>{});
  }

  /// Guarda datos de ejercicio de un día
  static Future<void> saveDailyExercise(
    String email,
    String dateKey,
    Map<String, dynamic> data,
  ) async {
    await _exerciseCol.doc(_dailyDocId(email, dateKey)).set({
      'email': email,
      'dateKey': dateKey,
      'data': data,
    }, SetOptions(merge: true));
  }

  // --- Sueño ---

  /// Obtiene horas de sueño de un día
  static Future<double> getSleep(String email, String dateKey) async {
    final doc = await _sleepCol.doc(_dailyDocId(email, dateKey)).get();
    final data = doc.data();
    if (data == null) return 0.0;
    final v = data['hours'];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse('$v') ?? 0.0;
  }

  /// Guarda horas de sueño de un día
  static Future<void> setSleep(String email, String dateKey, double hours) async {
    await _sleepCol.doc(_dailyDocId(email, dateKey)).set({
      'email': email,
      'dateKey': dateKey,
      'hours': hours,
    }, SetOptions(merge: true));
  }

  /// Añade horas de sueño al día actual
  static Future<void> addSleep(String email, String dateKey, double hours) async {
    final current = await getSleep(email, dateKey);
    await setSleep(email, dateKey, current + hours);
  }

  // --- Recetas guardadas por usuario ---

  static String _savedRecipeDocId(String email, String recipeId) => '${email}_$recipeId';

  static Future<void> saveRecipeForUser({
    required String email,
    required String recipeId,
    required Map<String, dynamic> recipeData,
  }) async {
    await _savedRecipesCol.doc(_savedRecipeDocId(email, recipeId)).set({
      'email': email,
      'recipeId': recipeId,
      'savedAt': FieldValue.serverTimestamp(),
      'recipe': recipeData,
    }, SetOptions(merge: true));
  }

  static Future<List<Map<String, dynamic>>> getSavedRecipesForUser(String email) async {
    final snap = await _savedRecipesCol.where('email', isEqualTo: email).get();
    return snap.docs
        .map((d) => Map<String, dynamic>.from(d.data()))
        .toList();
  }

  static Future<void> deleteSavedRecipeForUser({
    required String email,
    required String recipeId,
  }) async {
    await _savedRecipesCol.doc(_savedRecipeDocId(email, recipeId)).delete();
  }

  // --- Utilidades ---

  /// Genera clave de fecha YYYY-MM-DD
  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Calcula objetivo diario de hidratación basado en usuario
  static double computeDailyHydrationGoalMl(User u) {
    final base = (u.peso > 0 ? u.peso : 70.0) * 35.0;
    double adj = base;
    if (u.edad > 0 && u.edad < 14) adj = base * 0.9;
    if (u.edad >= 65) adj = base * 0.95;
    if (u.genero.toLowerCase() == 'masculino') adj += 200;
    return adj.clamp(1200.0, 4500.0);
  }

  /// Prompt de personalización basado en usuario actual
  static Future<String> buildUserPromptPersonalization() async {
    final u = await getCurrentUser();
    if (u == null) return '';
    final g = u.genero.isEmpty ? 'No especificado' : u.genero;
    final edad = u.edad > 0 ? u.edad : 0;
    final altura = u.altura > 0 ? u.altura : 0;
    final peso = u.peso > 0 ? u.peso : 0;
    return '\nDatos del usuario: edad $edad años, peso ${peso.toStringAsFixed(peso % 1 == 0 ? 0 : 1)} kg, altura ${altura.toStringAsFixed(altura % 1 == 0 ? 0 : 1)} cm, género $g. Personaliza las recomendaciones considerando estas características.\n';
  }
}
