import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/kickly_app_bar.dart';
import '../../core/widgets/responsive_page.dart';
import '../../repositories/auth_repository.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final password = TextEditingController();
  final confirm = TextEditingController();
  bool loading = false;
  String? error;

  Future<void> submit() async {
    if (password.text.length < 8) {
      setState(() => error = 'La password deve avere almeno 8 caratteri.');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = 'Le due password non coincidono.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await AuthRepository().setRecoveredPassword(password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password aggiornata.')));
      context.go('/');
    } catch (_) {
      if (mounted) setState(() => error = 'Il link potrebbe essere scaduto. Richiedine uno nuovo.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KicklyAppBar(title: 'Nuova password', fallbackLocation: '/login'),
      body: SafeArea(
        child: ResponsivePage(
          maxWidth: 520,
          scrollable: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Text('Scegli una nuova password', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 22),
              TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Nuova password')),
              const SizedBox(height: 12),
              TextField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Ripeti password')),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Aggiornamento...' : 'Aggiorna password')),
            ],
          ),
        ),
      ),
    );
  }
}
