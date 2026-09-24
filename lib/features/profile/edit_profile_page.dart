import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_app_bar.dart';
import '../../core/widgets/responsive_page.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/profile_repository.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final name = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  String role = 'Non specificato';
  DateTime? birthDate;
  String? avatar;
  bool loading = true;
  bool saving = false;
  bool uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await ProfileRepository().getMine();
      name.text = p.fullName;
      username.text = p.username;
      email.text = Supabase.instance.client.auth.currentUser?.email ?? '';
      role = p.preferredRole;
      birthDate = p.birthDate;
      avatar = p.avatarUrl;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await ProfileRepository().updateProfile(
        fullName: name.text,
        username: username.text,
        preferredRole: role,
        birthDate: birthDate,
      );
      final currentEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
      if (email.text.trim() != currentEmail) {
        await AuthRepository().updateEmail(email.text);
      }
      if (newPassword.text.isNotEmpty) {
        if (newPassword.text.length < 8) throw Exception('La nuova password deve avere almeno 8 caratteri.');
        await AuthRepository().updatePassword(
          currentPassword: currentPassword.text,
          newPassword: newPassword.text,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profilo aggiornato.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickBirth() async {
    final d = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(1995),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => birthDate = d);
  }

  Future<void> pickAvatar() async {
    setState(() => uploadingAvatar = true);
    try {
      final url = await ProfileRepository().chooseAndUploadAvatar();
      if (url != null && mounted) {
        setState(() => avatar = url);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto profilo aggiornata.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload non riuscito: $e')));
    } finally {
      if (mounted) setState(() => uploadingAvatar = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    email.dispose();
    currentPassword.dispose();
    newPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KicklyAppBar(title: 'Modifica profilo', fallbackLocation: '/profile'),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ResponsivePage(
              maxWidth: 760,
              scrollable: true,
              child: PageReveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: AppColors.surfaceAlt,
                                backgroundImage: avatar == null ? null : NetworkImage(avatar!),
                                child: avatar == null ? const Icon(Icons.person_outline_rounded, size: 42) : null,
                              ),
                              if (uploadingAvatar)
                                const Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(color: Color(0x8807111D), shape: BoxShape.circle),
                                    child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          TextButton.icon(
                            onPressed: uploadingAvatar ? null : pickAvatar,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: const Text('Cambia foto'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Profilo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome e cognome')),
                    const SizedBox(height: 10),
                    TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: role,
                      decoration: const InputDecoration(labelText: 'Ruolo preferito'),
                      items: const ['Non specificato', 'Portiere', 'Difensore', 'Centrocampista', 'Attaccante', 'Universale']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (v) => setState(() => role = v!),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: pickBirth,
                      icon: const Icon(Icons.cake_outlined),
                      label: Text(birthDate == null ? 'Imposta data di nascita' : DateFormat('dd/MM/yyyy').format(birthDate!)),
                    ),
                    const SizedBox(height: 26),
                    const Text('Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('Email e password sono gestite da Supabase Auth.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 10),
                    TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                    const SizedBox(height: 10),
                    TextField(controller: currentPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Password attuale (solo se la cambi)')),
                    const SizedBox(height: 10),
                    TextField(controller: newPassword, obscureText: true, decoration: const InputDecoration(labelText: 'Nuova password (opzionale)')),
                    const SizedBox(height: 22),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(onPressed: saving ? null : save, child: Text(saving ? 'Salvataggio...' : 'Salva modifiche')),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
    );
  }
}
