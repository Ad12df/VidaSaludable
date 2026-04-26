import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../base_datos/firebase_service.dart';
import '../../main.dart';
import '../../modelos/user.dart';
import '../../modelos/user_settings.dart';
import '../../widgets/common/app_glass_style.dart';
import 'user_profile_edit_screen.dart';

class SettingsData {
  final Brightness brightness;
  final Color seed;
  final String? fontFamily;
  final bool followLocation;
  final String appTheme;

  const SettingsData({
    required this.brightness,
    required this.seed,
    this.fontFamily,
    required this.followLocation,
    required this.appTheme,
  });
}

class SettingsScreen extends StatefulWidget {
  final Brightness brightness;
  final Color seed;
  final String? fontFamily;
  final bool followLocation;
  final bool asTab;
  final ValueChanged<SettingsData>? onChanged;

  const SettingsScreen({
    super.key,
    required this.brightness,
    required this.seed,
    required this.fontFamily,
    required this.followLocation,
    this.asTab = false,
    this.onChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Brightness _brightness;
  late Color _seed;
  late String? _font;
  late bool _follow;
  User? _user;

  bool _pushEnabled = true;
  bool _remindersEnabled = true;
  bool _healthAlerts = true;
  bool _shareAnonymous = false;
  bool _locationPersonalized = true;
  bool _highContrast = false;
  bool _sleepAutoDetectionEnabled = true;

  int _notificationFrequency = 2;
  double _textScale = 1.0;
  String _language = 'es';
  String _appTheme = 'emerald';

  bool _isSaving = false;

  final List<(String, String?)> _fontOptions = const [
    ('Sistema', null),
    ('Roboto', 'Roboto'),
    ('Montserrat', 'Montserrat'),
    ('Poppins', 'Poppins'),
  ];

  static const List<_ThemeOption> _themeOptions = [
    _ThemeOption(
      id: 'emerald',
      title: 'Esmeralda',
      subtitle: 'Claro • Energético',
      color: Color(0xFF22C55E),
      icon: Icons.spa_rounded,
      brightness: Brightness.light,
    ),
    _ThemeOption(
      id: 'violet_night',
      title: 'Violeta Nocturno',
      subtitle: 'Oscuro • Enfoque',
      color: Color(0xFF8B5CF6),
      icon: Icons.nights_stay_rounded,
      brightness: Brightness.dark,
    ),
    _ThemeOption(
      id: 'ocean',
      title: 'Océano',
      subtitle: 'Claro • Fresco',
      color: Color(0xFF06B6D4),
      icon: Icons.water_drop_rounded,
      brightness: Brightness.light,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _brightness = widget.brightness;
    _seed = widget.seed;
    _font = widget.fontFamily;
    _follow = widget.followLocation;
    _locationPersonalized = widget.followLocation;
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadUser(), _loadSettings()]);
  }

  Future<void> _loadUser() async {
    final u = await FirebaseService.getCurrentUser();
    if (!mounted) return;
    setState(() => _user = u);
  }

  Future<void> _loadSettings() async {
    final email = await FirebaseService.getCurrentUserEmail();
    if (email == null) return;
    final s = await FirebaseService.getSettingsForUser(email);
    if (s == null || !mounted) return;

    setState(() {
      _brightness =
          (s.brightness == Brightness.dark.toString()) ? Brightness.dark : Brightness.light;
      if (s.seedColor != null) _seed = Color(s.seedColor!);
      _font = s.fontFamily;
      _follow = s.followLocation ?? _follow;
      _language = (s.language == null || s.language!.isEmpty) ? 'es' : s.language!;
      _pushEnabled = s.pushEnabled ?? _pushEnabled;
      _remindersEnabled = s.remindersEnabled ?? _remindersEnabled;
      _healthAlerts = s.healthAlerts ?? _healthAlerts;
      _shareAnonymous = s.shareAnonymous ?? _shareAnonymous;
      _locationPersonalized = s.locationPersonalized ?? _locationPersonalized;
      _highContrast = s.highContrast ?? _highContrast;
      _sleepAutoDetectionEnabled = s.sleepAutoDetectionEnabled ?? _sleepAutoDetectionEnabled;
      _notificationFrequency = (s.notificationFrequency ?? _notificationFrequency).clamp(1, 4);
      _textScale = (s.textScale ?? _textScale).clamp(0.9, 1.4);
      _appTheme = (s.appTheme == null || s.appTheme!.isEmpty) ? 'emerald' : s.appTheme!;
    });
  }

  Future<void> _save({bool showFeedback = false, bool restartWhenStandalone = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final email = await FirebaseService.getCurrentUserEmail();
      if (email == null) return;

      final s = UserSettings(
        userId: email,
        brightness: _brightness.toString(),
        seedColor: _seed.toARGB32(),
        fontFamily: _font,
        language: _language,
        followLocation: _follow,
        shareAnonymous: _shareAnonymous,
        pushEnabled: _pushEnabled,
        remindersEnabled: _remindersEnabled,
        healthAlerts: _healthAlerts,
        locationPersonalized: _locationPersonalized,
        highContrast: _highContrast,
        notificationFrequency: _notificationFrequency,
        textScale: _textScale,
        sleepAutoDetectionEnabled: _sleepAutoDetectionEnabled,
        appTheme: _appTheme,
      );
      await FirebaseService.saveSettings(s);

      widget.onChanged?.call(
        SettingsData(
          brightness: _brightness,
          seed: _seed,
          fontFamily: _font,
          followLocation: _follow,
          appTheme: _appTheme,
        ),
      );

      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ajustes guardados correctamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (!widget.asTab && restartWhenStandalone && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MyApp()),
          (route) => false,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    if (_user == null) return;
    final picker = ImagePicker();
    final xf = await picker.pickImage(source: ImageSource.gallery);
    if (xf == null) return;
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'profile_${_user!.correo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final saved = await File(xf.path).copy('${appDir.path}/$fileName');

    final updated = User(
      nombre: _user!.nombre,
      apellido: _user!.apellido,
      correo: _user!.correo,
      contrasena: _user!.contrasena,
      genero: _user!.genero,
      edad: _user!.edad,
      altura: _user!.altura,
      peso: _user!.peso,
      photoPath: saved.path,
    );
    await FirebaseService.saveCurrentUser(updated);
    if (!mounted) return;
    setState(() => _user = updated);
  }

  Future<void> _setTheme(String id) async {
    final option = _themeOptions.firstWhere((t) => t.id == id);
    setState(() {
      _appTheme = option.id;
      _brightness = option.brightness;
      _seed = option.color;
    });
    await _save(showFeedback: true);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: widget.asTab ? null : AppGlassStyle.appBar(title: 'Ajustes'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (widget.asTab) const SizedBox(height: 20),
            _ProfileHeader(
              user: _user,
              onEdit: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserProfileEditScreen()),
                );
                await _loadUser();
              },
              onPickPhoto: _pickImage,
            ),
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            const SizedBox(height: 14),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildAppearanceCard(),
                        const SizedBox(height: 12),
                        _buildAccessibilityCard(),
                        const SizedBox(height: 12),
                        _buildPrivacyCard(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        _buildActivityCard(),
                        const SizedBox(height: 12),
                        _buildSleepCard(),
                        const SizedBox(height: 12),
                        _buildNotificationsCard(),
                        const SizedBox(height: 12),
                        _buildAccountCard(),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              _buildAppearanceCard(),
              const SizedBox(height: 12),
              _buildAccessibilityCard(),
              const SizedBox(height: 12),
              _buildActivityCard(),
              const SizedBox(height: 12),
              _buildSleepCard(),
              const SizedBox(height: 12),
              _buildNotificationsCard(),
              const SizedBox(height: 12),
              _buildPrivacyCard(),
              const SizedBox(height: 12),
              _buildInfoCard(),
              const SizedBox(height: 12),
              _buildAccountCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceCard() {
    return _SettingsSectionCard(
      title: 'Apariencia',
      icon: Icons.palette_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tema de la aplicación',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Column(
            children: _themeOptions
                .map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ThemeTile(
                      option: t,
                      selected: _appTheme == t.id,
                      onTap: () => _setTheme(t.id),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          _RowField(
            title: 'Tipografía',
            child: DropdownButtonFormField<String?>(
              initialValue: _font,
              decoration: _dropdownDecoration(),
              dropdownColor: const Color(0xFF242639),
              style: const TextStyle(color: Colors.white),
              items: _fontOptions
                  .map(
                    (opt) => DropdownMenuItem<String?>(
                      value: opt.$2,
                      child: Text(opt.$1, style: const TextStyle(color: Colors.white)),
                    ),
                  )
                  .toList(),
              onChanged: (v) async {
                setState(() => _font = v);
                await _save();
              },
            ),
          ),
          const SizedBox(height: 10),
          _RowField(
            title: 'Idioma',
            child: DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: _dropdownDecoration(),
              dropdownColor: const Color(0xFF242639),
              style: const TextStyle(color: Colors.white),
              items: const [
                DropdownMenuItem(value: 'es', child: Text('Español', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) async {
                if (v == null) return;
                setState(() => _language = v);
                await _save();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessibilityCard() {
    return _SettingsSectionCard(
      title: 'Accesibilidad',
      icon: Icons.accessibility_new_rounded,
      child: Column(
        children: [
          _SwitchTile(
            icon: Icons.contrast_rounded,
            title: 'Alto contraste',
            subtitle: 'Mejora visibilidad de textos y controles',
            value: _highContrast,
            onChanged: (v) async {
              setState(() => _highContrast = v);
              await _save();
            },
          ),
          const SizedBox(height: 8),
          _SliderTile(
            icon: Icons.text_fields_rounded,
            title: 'Escala de texto',
            subtitle: '${_textScale.toStringAsFixed(2)}x',
            value: _textScale,
            min: 0.9,
            max: 1.4,
            divisions: 10,
            onChanged: (v) => setState(() => _textScale = v),
            onChangeEnd: (_) => _save(),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard() {
    return _SettingsSectionCard(
      title: 'Actividad y ubicación',
      icon: Icons.directions_walk_outlined,
      child: Column(
        children: [
          _SwitchTile(
            icon: Icons.gps_fixed,
            title: 'Seguimiento de actividad',
            subtitle: 'GPS, pasos y velocidad',
            value: _follow,
            onChanged: (v) async {
              setState(() {
                _follow = v;
                if (!v) _locationPersonalized = false;
              });
              await _save(showFeedback: true);
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.location_searching_rounded,
            title: 'Personalización por ubicación',
            subtitle: 'Rutinas y recomendaciones según zona',
            value: _locationPersonalized,
            onChanged: _follow
                ? (v) async {
                    setState(() => _locationPersonalized = v);
                    await _save();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSleepCard() {
    return _SettingsSectionCard(
      title: 'Sueño',
      icon: Icons.bedtime_outlined,
      child: _SwitchTile(
        icon: Icons.nightlight_round,
        title: 'Detección automática de sueño',
        subtitle: 'Detecta inactividad nocturna automáticamente',
        value: _sleepAutoDetectionEnabled,
        onChanged: (v) async {
          setState(() => _sleepAutoDetectionEnabled = v);
          await _save(showFeedback: true);
        },
      ),
    );
  }

  Widget _buildNotificationsCard() {
    return _SettingsSectionCard(
      title: 'Notificaciones y recordatorios',
      icon: Icons.notifications_active_outlined,
      child: Column(
        children: [
          _SwitchTile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones push',
            value: _pushEnabled,
            onChanged: (v) async {
              setState(() => _pushEnabled = v);
              if (!v) {
                _remindersEnabled = false;
                _healthAlerts = false;
              }
              await _save();
            },
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.alarm_outlined,
            title: 'Recordatorios diarios',
            value: _remindersEnabled,
            onChanged: _pushEnabled
                ? (v) async {
                    setState(() => _remindersEnabled = v);
                    await _save();
                  }
                : null,
          ),
          const SizedBox(height: 8),
          _SwitchTile(
            icon: Icons.warning_amber_rounded,
            title: 'Alertas de salud',
            value: _healthAlerts,
            onChanged: _pushEnabled
                ? (v) async {
                    setState(() => _healthAlerts = v);
                    await _save();
                  }
                : null,
          ),
          const SizedBox(height: 8),
          _SliderTile(
            icon: Icons.av_timer_outlined,
            title: 'Frecuencia de avisos',
            subtitle: _frequencyLabel(_notificationFrequency),
            value: _notificationFrequency.toDouble(),
            min: 1,
            max: 4,
            divisions: 3,
            enabled: _pushEnabled,
            onChanged: _pushEnabled
                ? (v) => setState(() => _notificationFrequency = v.round())
                : null,
            onChangeEnd: _pushEnabled ? (_) => _save() : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return _SettingsSectionCard(
      title: 'Privacidad',
      icon: Icons.privacy_tip_outlined,
      child: _SwitchTile(
        icon: Icons.analytics_outlined,
        title: 'Compartir datos anónimos',
        subtitle: 'Ayuda a mejorar recomendaciones sin exponer identidad',
        value: _shareAnonymous,
        onChanged: (v) async {
          setState(() => _shareAnonymous = v);
          await _save();
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return _SettingsSectionCard(
      title: 'Información',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.new_releases_outlined,
            title: 'Versión 1.6.9 (Build 2)',
            onTap: () {
              showDialog<void>(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.6),
                builder: (_) => _GlassInfoDialog(
                  title: 'Novedades de la versión',
                  content:
                      'Versión 1.6.9 (Build 2)\\n\\n'
                      'Base inicial: 1.2.1\\n'
                      'Actualización acumulada: 4 cambios mayores y 8 menores.\\n\\n'
                      '• Mejoras importantes en módulos clave para estabilidad general.\\n'
                      '• Refinamientos de experiencia de usuario en navegación y ajustes.\\n'
                      '• Optimización de rendimiento en vistas de uso frecuente.\\n'
                      '• Correcciones menores en componentes visuales y comportamiento.',
                  primaryText: 'Cerrar',
                  onPrimaryTap: () => Navigator.of(context).pop(),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.gavel_rounded,
            title: 'Términos y condiciones',
            onTap: () {
              showDialog<void>(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.6),
                builder: (_) => _GlassInfoDialog(
                  title: 'Términos y condiciones',
                  content:
                      'TÉRMINOS Y CONDICIONES DE USO – VITU\\n\\n'
                      'Última actualización: 2026-04-26\\n\\n'
                      '1. ACEPTACIÓN\\n'
                      'Al utilizar Vitu, usted acepta estos términos en su totalidad.\\n\\n'
                      '2. FINALIDAD INFORMATIVA\\n'
                      'La aplicación ofrece orientación general sobre bienestar, hidratación, sueño, nutrición y ejercicio. '
                      'No sustituye consejo médico profesional, diagnóstico ni tratamiento clínico.\\n\\n'
                      '3. RESPONSABILIDAD DEL USUARIO\\n'
                      'Usted es responsable de verificar que toda actividad física y recomendaciones sean adecuadas para su condición de salud.\\n\\n'
                      '4. CUENTA Y SEGURIDAD\\n'
                      'El usuario debe mantener la confidencialidad de sus credenciales y notificar usos no autorizados.\\n\\n'
                      '5. DATOS PERSONALES\\n'
                      'Vitu procesa datos para personalizar la experiencia. El tratamiento se realiza conforme a principios de minimización, seguridad y finalidad legítima.\\n\\n'
                      '6. LIMITACIÓN DE RESPONSABILIDAD\\n'
                      'Vitu no garantiza resultados específicos de salud ni continuidad ininterrumpida del servicio.\\n\\n'
                      '7. PROPIEDAD INTELECTUAL\\n'
                      'El contenido, diseño y funcionalidades de Vitu están protegidos por derechos aplicables.\\n\\n'
                      '8. MODIFICACIONES\\n'
                      'Podemos actualizar estos términos y publicaremos la versión vigente dentro de la aplicación.\\n\\n'
                      '9. CONTACTO\\n'
                      'Para consultas legales o de privacidad, contacte al equipo administrador de Vitu.',
                  primaryText: 'Aceptar',
                  onPrimaryTap: () => Navigator.of(context).pop(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    return _SettingsSectionCard(
      title: 'Cuenta y sesión',
      icon: Icons.manage_accounts_outlined,
      child: _ActionTile(
        icon: Icons.logout_rounded,
        title: 'Cerrar sesión',
        color: Colors.redAccent,
        onTap: () async {
          final nav = Navigator.of(context);
          await FirebaseService.logout();
          if (!mounted) return;
          nav.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MyApp()),
            (route) => false,
          );
        },
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.2),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
    );
  }

  String _frequencyLabel(int v) {
    switch (v) {
      case 1:
        return 'Baja';
      case 2:
        return 'Media';
      case 3:
        return 'Alta';
      case 4:
        return 'Muy alta';
      default:
        return 'Media';
    }
  }
}

class _ThemeOption {
  final String id;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  final Brightness brightness;

  const _ThemeOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.brightness,
  });
}

class _ThemeTile extends StatelessWidget {
  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: selected ? 0.14 : 0.06),
          border: Border.all(
            color: selected ? option.color : Colors.white.withValues(alpha: 0.12),
            width: selected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: option.color.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(option.icon, color: option.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    option.subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12.2),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: option.color),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User? user;
  final Future<void> Function() onEdit;
  final Future<void> Function() onPickPhoto;

  const _ProfileHeader({
    required this.user,
    required this.onEdit,
    required this.onPickPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                backgroundImage: user?.photoPath != null ? FileImage(File(user!.photoPath!)) : null,
                child: user?.photoPath == null
                    ? const Icon(Icons.person, size: 34, color: Colors.white)
                    : null,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: InkWell(
                  onTap: onPickPhoto,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user?.nombre ?? 'Usuario'} ${user?.apellido ?? ''}'.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.correo ?? 'Sin correo',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12.8,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SettingsSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _RowField extends StatelessWidget {
  final String title;
  final Widget child;

  const _RowField({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: enabled ? 0.06 : 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF8B5CF6),
        secondary: Icon(icon, color: enabled ? Colors.white70 : Colors.white38),
        title: Text(
          title,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.white54,
            fontWeight: FontWeight.w600,
            fontSize: 13.8,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: TextStyle(
                  color: enabled ? Colors.white60 : Colors.white38,
                  fontSize: 12.2,
                ),
              ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const _SliderTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.enabled = true,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.8),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white60, fontSize: 12.6, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: const Color(0xFF8B5CF6),
              inactiveColor: Colors.white24,
              onChanged: enabled ? onChanged : null,
              onChangeEnd: enabled ? onChangeEnd : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassInfoDialog extends StatelessWidget {
  final String title;
  final String content;
  final String primaryText;
  final VoidCallback onPrimaryTap;

  const _GlassInfoDialog({
    required this.title,
    required this.content,
    required this.primaryText,
    required this.onPrimaryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF14172B).withValues(alpha: 0.9),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFFA78BFA), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SingleChildScrollView(
                child: Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13.2,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onPrimaryTap,
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(primaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: c),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: c, fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
