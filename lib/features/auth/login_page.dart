import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_logo.dart';
import '../../core/widgets/responsive_page.dart';
import '../../repositories/auth_repository.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final identifier = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscurePassword = true;
  String? error;

  Future<void> submit() async {
    if (identifier.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Inserisci email/username e password.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await AuthRepository().signIn(
        identifier: identifier.text,
        password: password.text,
      );
    } catch (_) {
      if (mounted) setState(() => error = 'Email/username o password non corretti.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    identifier.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsivePage(
          maxWidth: 460,
          scrollable: true,
          child: PageReveal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 28),
                const Center(child: KicklyLogo(fontSize: 35)),
                const SizedBox(height: 38),
                Text('Bentornato', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Accedi e riprendi da dove avevi lasciato.', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 26),
                TextField(
                  controller: identifier,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username, AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email o username',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: obscurePassword,
                  onSubmitted: (_) => submit(),
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                      icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Password dimenticata?'),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: loading ? null : submit,
                  child: Text(loading ? 'Accesso...' : 'Accedi'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text('Non hai un account? Registrati'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
