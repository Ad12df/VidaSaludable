import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../../base_datos/firebase_service.dart';
import '../../modelos/user.dart';
import '../../modelos/user_settings.dart';
import '../inicio/vida_plus_app.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _AuthBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isDesktop = width >= 1000;
              final isTablet = width >= 700 && width < 1000;
              final maxContentWidth = isDesktop ? 1160.0 : (isTablet ? 800.0 : 560.0);

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: isDesktop
                        ? _DesktopAuthLayout(
                            isLogin: _isLogin,
                            onToggle: () => setState(() => _isLogin = !_isLogin),
                          )
                        : _MobileTabletAuthLayout(
                            isLogin: _isLogin,
                            onToggle: () => setState(() => _isLogin = !_isLogin),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopAuthLayout extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;

  const _DesktopAuthLayout({
    required this.isLogin,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final title = isLogin ? 'Bienvenido de nuevo' : 'Crea tu cuenta';
    final subtitle = isLogin
        ? 'Inicia sesión para continuar con tu plan saludable.'
        : 'Regístrate para empezar una experiencia personalizada.';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: _GlassCard(
            padding: const EdgeInsets.all(32),
            child: _AuthShowcase(
              title: title,
              subtitle: subtitle,
            ),
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          flex: 6,
          child: _GlassCard(
            padding: const EdgeInsets.all(28),
            child: _AuthPanel(
              isLogin: isLogin,
              onToggle: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileTabletAuthLayout extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;

  const _MobileTabletAuthLayout({
    required this.isLogin,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final title = isLogin ? 'Bienvenido' : 'Crear cuenta';
    final subtitle = isLogin
        ? 'Ingresa y continúa cuidando tu bienestar.'
        : 'Regístrate y empieza hoy tu nueva rutina.';

    return Column(
      children: [
        _GlassCard(
          padding: EdgeInsets.all(isLogin ? 22 : 18),
          child: _AuthShowcase(
            title: title,
            subtitle: subtitle,
            compact: true,
            minimal: !isLogin,
          ),
        ),
        const SizedBox(height: 14),
        _GlassCard(
          padding: const EdgeInsets.all(20),
          child: _AuthPanel(
            isLogin: isLogin,
            onToggle: onToggle,
          ),
        ),
      ],
    );
  }
}

class _AuthPanel extends StatelessWidget {
  final bool isLogin;
  final VoidCallback onToggle;

  const _AuthPanel({
    required this.isLogin,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final headline = isLogin ? 'Iniciar sesión' : 'Registro';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AuthSegmentedSwitch(
          isLogin: isLogin,
          onChanged: (login) {
            if (login != isLogin) onToggle();
          },
        ),
        const SizedBox(height: 20),
        Text(
          headline,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isLogin
              ? 'Accede con tus credenciales'
              : 'Completa tus datos para comenzar',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.82),
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: isLogin
              ? const _LoginForm(key: ValueKey('login_form'))
              : const _RegisterForm(key: ValueKey('register_form')),
        ),
      ],
    );
  }
}

class _AuthShowcase extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool compact;
  final bool minimal;

  const _AuthShowcase({
    required this.title,
    required this.subtitle,
    this.compact = false,
    this.minimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 64 : 74,
          height: compact ? 64 : 74,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFF22D3EE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x665A4BFF),
                blurRadius: 26,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 34),
        ),
        SizedBox(height: compact ? 14 : 18),
        Text(
          title,
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 27 : 34,
            height: 1.08,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          textAlign: compact ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.84),
            fontSize: compact ? 14 : 16,
            height: 1.45,
          ),
        ),
        if (!compact && !minimal) ...[
          const SizedBox(height: 24),
          _FeatureRow(icon: Icons.check_circle_rounded, text: 'Diseño moderno y cómodo'),
          const SizedBox(height: 10),
          _FeatureRow(icon: Icons.security_rounded, text: 'Acceso seguro a tu cuenta'),
          const SizedBox(height: 10),
          _FeatureRow(icon: Icons.auto_awesome_rounded, text: 'Experiencia personalizada'),
        ],
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14.5),
          ),
        ),
      ],
    );
  }
}

class _AuthSegmentedSwitch extends StatelessWidget {
  final bool isLogin;
  final ValueChanged<bool> onChanged;

  const _AuthSegmentedSwitch({
    required this.isLogin,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SwitchItem(
              label: 'Ingresar',
              selected: isLogin,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _SwitchItem(
              label: 'Registro',
              selected: !isLogin,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SwitchItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: selected
            ? const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
              )
            : null,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: selected ? 1 : 0.8),
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({super.key});

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label es obligatorio';
    return null;
  }

  String? _emailValidator(String? value) {
    final req = _requiredField(value, 'El correo');
    if (req != null) return req;
    final v = value!.trim();
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v);
    if (!ok) return 'Ingresa un correo válido';
    return null;
  }

  String? _passwordValidator(String? value) {
    final req = _requiredField(value, 'La contraseña');
    if (req != null) return req;
    if (value!.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    try {
      final email = _emailCtrl.text.trim();
      await FirebaseService.verifyLogin(email, _passCtrl.text);

      final user = await FirebaseService.getUserByEmail(email);
      if (user == null) {
        throw Exception('Tu cuenta existe en Auth, pero no en Firestore (users).');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VidaPlusApp()),
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'No se pudo iniciar sesión.';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        message = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'wrong-password') {
        message = 'Contraseña incorrecta.';
      } else if (e.code == 'invalid-email') {
        message = 'El correo no es válido.';
      } else if (e.code == 'too-many-requests') {
        message = 'Demasiados intentos. Intenta más tarde.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar sesión: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _ModernInput(
            controller: _emailCtrl,
            label: 'Correo',
            hint: 'tuemail@dominio.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          const SizedBox(height: 12),
          _ModernInput(
            controller: _passCtrl,
            label: 'Contraseña',
            hint: '••••••••',
            icon: Icons.lock_rounded,
            obscureText: _hidePassword,
            validator: _passwordValidator,
            suffix: IconButton(
              splashRadius: 20,
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _AuthButton(
            label: _loading ? 'Ingresando...' : 'Entrar',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _AuthSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _AuthSectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.88), size: 17),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _AuthSectionDivider extends StatelessWidget {
  const _AuthSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm({super.key});

  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  String? _genero;
  final _edadCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _pesoCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _edadCtrl.dispose();
    _alturaCtrl.dispose();
    _pesoCtrl.dispose();
    _correoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String? _requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label es obligatorio';
    return null;
  }

  String? _emailValidator(String? value) {
    final req = _requiredField(value, 'El correo');
    if (req != null) return req;
    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value!.trim());
    if (!ok) return 'Ingresa un correo válido';
    return null;
  }

  String? _passwordValidator(String? value) {
    final req = _requiredField(value, 'La contraseña');
    if (req != null) return req;
    if (value!.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  String? _numberValidator(String? value, String label, {bool allowDecimal = false}) {
    final req = _requiredField(value, label);
    if (req != null) return req;
    final text = value!.trim();
    final num? n = allowDecimal ? double.tryParse(text) : int.tryParse(text);
    if (n == null) return '$label debe ser numérico';
    if (n <= 0) return '$label debe ser mayor que 0';
    return null;
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_genero == null || _genero!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un género'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final u = User(
        nombre: _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        genero: _genero ?? '',
        edad: int.tryParse(_edadCtrl.text.trim()) ?? 0,
        altura: double.tryParse(_alturaCtrl.text.trim()) ?? 0.0,
        peso: double.tryParse(_pesoCtrl.text.trim()) ?? 0.0,
        correo: _correoCtrl.text.trim(),
        contrasena: _passCtrl.text,
      );

      await FirebaseService.registerUser(u);
      await FirebaseService.saveSettings(
        UserSettings(
          userId: u.correo,
          seedColor: const Color(0xFF8B5CF6).toARGB32(),
          metaHydratationMl: FirebaseService.computeDailyHydrationGoalMl(u),
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VidaPlusApp()),
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'No se pudo crear la cuenta.';
      if (e.code == 'email-already-in-use') {
        message = 'Este correo ya está registrado.';
      } else if (e.code == 'invalid-email') {
        message = 'El correo ingresado no es válido.';
      } else if (e.code == 'weak-password') {
        message = 'La contraseña es muy débil.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Auth por correo/contraseña no está habilitado en Firebase Console.';
      } else if (e.code == 'network-request-failed') {
        message = 'Error de red al conectar con Firebase.';
      } else if (e.message != null && e.message!.trim().isNotEmpty) {
        message = 'No se pudo crear la cuenta: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear la cuenta: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const _AuthSectionTitle(
            title: 'Datos personales',
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),
          _ModernInput(
            controller: _nombreCtrl,
            label: 'Nombre',
            icon: Icons.person_rounded,
            validator: (v) => _requiredField(v, 'El nombre'),
          ),
          const SizedBox(height: 10),
          _ModernInput(
            controller: _apellidoCtrl,
            label: 'Apellido',
            icon: Icons.badge_rounded,
            validator: (v) => _requiredField(v, 'El apellido'),
          ),
          const SizedBox(height: 10),
          _ModernDropdown(
            label: 'Género',
            value: _genero,
            icon: Icons.wc_rounded,
            items: const ['Masculino', 'Femenino', 'Otro'],
            onChanged: (v) => setState(() => _genero = v),
          ),
          const _AuthSectionDivider(),
          const _AuthSectionTitle(
            title: 'Datos físicos',
            icon: Icons.monitor_heart_outlined,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ModernInput(
                  controller: _edadCtrl,
                  label: 'Edad',
                  icon: Icons.cake_rounded,
                  keyboardType: TextInputType.number,
                  validator: (v) => _numberValidator(v, 'La edad'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ModernInput(
                  controller: _alturaCtrl,
                  label: 'Altura (cm)',
                  icon: Icons.height_rounded,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => _numberValidator(v, 'La altura', allowDecimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ModernInput(
            controller: _pesoCtrl,
            label: 'Peso (kg)',
            icon: Icons.monitor_weight_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => _numberValidator(v, 'El peso', allowDecimal: true),
          ),
          const _AuthSectionDivider(),
          const _AuthSectionTitle(
            title: 'Acceso a la cuenta',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 10),
          _ModernInput(
            controller: _correoCtrl,
            label: 'Correo',
            hint: 'tuemail@dominio.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: _emailValidator,
          ),
          const SizedBox(height: 10),
          _ModernInput(
            controller: _passCtrl,
            label: 'Contraseña',
            hint: '••••••••',
            icon: Icons.lock_rounded,
            obscureText: _hidePassword,
            validator: _passwordValidator,
            suffix: IconButton(
              splashRadius: 20,
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _AuthButton(
            label: _loading ? 'Creando cuenta...' : 'Crear cuenta',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _AuthButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66544CFF),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: loading
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ModernInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _ModernInput({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
    );

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.11),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.3),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF7B7B), width: 1.2),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFFFF7B7B), width: 1.2),
        ),
        errorStyle: const TextStyle(color: Color(0xFFFFC7C7)),
      ),
    );
  }
}

class _ModernDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _ModernDropdown({
    required this.label,
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
    );

    return DropdownButtonFormField<String>(
      initialValue: value,
      iconEnabledColor: Colors.white.withValues(alpha: 0.9),
      dropdownColor: const Color(0xFF1D1240),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.11),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.3),
        ),
      ),
      items: items
          .map((g) => DropdownMenuItem<String>(
                value: g,
                child: Text(g, style: const TextStyle(color: Colors.white)),
              ))
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: Colors.white.withValues(alpha: 0.09),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55210B45),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  final Widget child;

  const _AuthBackground({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-1.0, -1.0),
          end: Alignment(1.0, 1.0),
          colors: [
            Color(0xFF0F0B25),
            Color(0xFF1D1240),
            Color(0xFF102A5E),
          ],
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

