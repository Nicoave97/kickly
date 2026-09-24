import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_logo.dart';
import '../../core/widgets/responsive_page.dart';
import '../../repositories/auth_repository.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final fullName = TextEditingController();
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String? message;

  Future<void> submit() async {
    if (fullName.text.trim().isEmpty ||
        username.text.trim().length < 3 ||
        !email.text.contains('@') ||
        password.text.length < 8) {
      setState(() => message = 'Controlla nome, username, email e password (minimo 8 caratteri).');
      return;
    }
    setState(() { loading = true; message = null; });
    try {
      final res = await AuthRepository().register(
        email: email.text,
        password: password.text,
        fullName: fullName.text,
        username: username.text,
      );
      if (!mounted) return;
      if (res.session == null) {
        setState(() => message = 'Account creato. Controlla la tua email per confermare la registrazione.');
      }
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    fullName.dispose();
    username.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsivePage(
          maxWidth: 500,
          scrollable: true,
          child: PageReveal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                const Center(child: KicklyLogo(fontSize: 35)),
                const SizedBox(height: 34),
                Text('Crea il tuo profilo', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Ti bastano pochi dati. Le statistiche nasceranno dalle partite che giochi.', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                TextField(controller: fullName, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Nome e cognome', prefixIcon: Icon(Icons.badge_outlined))),
                const SizedBox(height: 12),
                TextField(controller: username, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email_rounded))),
                const SizedBox(height: 12),
                TextField(controller: email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded))),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: obscure,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(message!, style: const TextStyle(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 20),
                FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Creazione...' : 'Crea account')),
                const SizedBox(height: 10),
                TextButton(onPressed: () => context.go('/login'), child: const Text('Hai già un account? Accedi')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
