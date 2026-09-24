import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/kickly_app_bar.dart';
import '../../core/widgets/responsive_page.dart';
import '../../repositories/auth_repository.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final email = TextEditingController();
  bool loading = false;
  bool sent = false;
  String? error;

  Future<void> submit() async {
    if (!email.text.contains('@')) {
      setState(() => error = 'Inserisci l’email associata al tuo account.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await AuthRepository().requestPasswordReset(email.text);
      if (mounted) setState(() => sent = true);
    } catch (e) {
      if (mounted) setState(() => error = 'Non è stato possibile inviare l’email. Riprova.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KicklyAppBar(title: 'Recupera password', fallbackLocation: '/login'),
      body: SafeArea(
        child: ResponsivePage(
          maxWidth: 520,
          scrollable: true,
          child: PageReveal(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 18),
                Icon(Icons.mark_email_read_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 18),
                Text('Reimposta la password', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('Ti invieremo un link all’email collegata al profilo Kickly.', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 24),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (sent) ...[
                  const SizedBox(height: 14),
                  const Text('Email inviata. Controlla anche la cartella spam.', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 20),
                FilledButton(onPressed: loading ? null : submit, child: Text(loading ? 'Invio...' : 'Invia link di recupero')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
