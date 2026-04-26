import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../modelos/user.dart';
import '../../base_datos/firebase_service.dart';
import '../../widgets/common/app_glass_style.dart';

// Pantalla para editar el perfil del usuario (datos y foto)
class UserProfileEditScreen extends StatefulWidget {
  const UserProfileEditScreen({super.key});
  @override
  State<UserProfileEditScreen> createState() => _UserProfileEditScreenState();
}

class _UserProfileEditScreenState extends State<UserProfileEditScreen> {
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  final _alturaCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  String? _genero;
  String? _photoPath;
  FileImage? _profileImage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final u = await FirebaseService.getCurrentUser();
    if (u == null || !mounted) return;
    setState(() {
      _nombreCtrl.text = u.nombre;
      _apellidoCtrl.text = u.apellido;
      _edadCtrl.text = '${u.edad}';
      _alturaCtrl.text = '${u.altura}';
      _weightCtrl.text = '${u.peso}';
      _genero = u.genero.isEmpty ? null : u.genero;
      _photoPath = u.photoPath;
      if (_photoPath != null && _photoPath!.isNotEmpty) {
        _profileImage = FileImage(File(_photoPath!));
      } else {
        _profileImage = null;
      }
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _edadCtrl.dispose();
    _alturaCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (xfile == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '${dir.path}/vitu_profile_$ts.jpg';
      final file = File(path);
      await file.writeAsBytes(await xfile.readAsBytes());
      if (!mounted) return;
      setState(() {
        _photoPath = path;
        _profileImage = FileImage(File(path));
      });

      final u = await FirebaseService.getCurrentUser();
      if (u != null) {
        final updated = User(
          nombre: u.nombre,
          apellido: u.apellido,
          genero: u.genero,
          edad: u.edad,
          altura: u.altura,
          peso: u.peso,
          correo: u.correo,
          contrasena: u.contrasena,
          photoPath: _photoPath,
        );
        await FirebaseService.saveCurrentUser(updated);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la foto')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0B25),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Editar perfil'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: GlassBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 28, 20, 20),
            child: Column(
              children: [
                GlassCard(
                  child: Column(
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _changePhoto,
                          child: CircleAvatar(
                            radius: 56,
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            backgroundImage: _profileImage,
                            child: _profileImage == null
                                ? const Icon(Icons.person, size: 64, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _changePhoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Cambiar foto'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Builder(
                    builder: (context) {
                      InputDecoration deco(String labelText) => InputDecoration(
                        labelText: labelText,
                        labelStyle: const TextStyle(color: Colors.white70),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white30),
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                      );
                      const fieldStyle = TextStyle(color: Colors.white);
                      return Column(
                        children: [
                          TextField(
                            controller: _nombreCtrl,
                            style: fieldStyle,
                            decoration: deco('Nombre'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _apellidoCtrl,
                            style: fieldStyle,
                            decoration: deco('Apellido'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _genero,
                            dropdownColor: const Color(0xFF242639),
                            style: fieldStyle,
                            items: const [
                              DropdownMenuItem(value: 'Masculino', child: Text('Masculino')),
                              DropdownMenuItem(value: 'Femenino', child: Text('Femenino')),
                              DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                            ],
                            onChanged: (v) => setState(() => _genero = v),
                            decoration: deco('Género'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _edadCtrl,
                                  style: fieldStyle,
                                  keyboardType: TextInputType.number,
                                  decoration: deco('Edad'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _alturaCtrl,
                                  style: fieldStyle,
                                  keyboardType: TextInputType.number,
                                  decoration: deco('Altura (cm)'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _weightCtrl,
                            style: fieldStyle,
                            keyboardType: TextInputType.number,
                            decoration: deco('Peso (kg)'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final u = await FirebaseService.getCurrentUser();
                      if (u == null) return;
                      final updated = User(
                        nombre: _nombreCtrl.text.trim(),
                        apellido: _apellidoCtrl.text.trim(),
                        genero: _genero ?? '',
                        edad: int.tryParse(_edadCtrl.text.trim()) ?? u.edad,
                        altura: double.tryParse(_alturaCtrl.text.trim()) ?? u.altura,
                        peso: double.tryParse(_weightCtrl.text.trim()) ?? u.peso,
                        correo: u.correo,
                        contrasena: u.contrasena,
                        photoPath: _photoPath,
                      );
                      await FirebaseService.saveCurrentUser(updated);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Guardar cambios',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
