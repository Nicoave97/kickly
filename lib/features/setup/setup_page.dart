import 'package:flutter/material.dart';
import '../../core/widgets/kickly_logo.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const KicklyLogo(fontSize: 36),
                    const SizedBox(height: 24),
                    Text('Configurazione backend mancante',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    const Text(
                      'Kickly include già la configurazione Supabase di sviluppo. Questa schermata compare solo se URL o publishable key vengono rimossi o sovrascritti con valori vuoti.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
