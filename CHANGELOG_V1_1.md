# Kickly V1.1 – revisione UX/functional

- Responsive mobile/tablet/desktop con NavigationRail su schermi larghi.
- Logo SVG Kickly integrato negli asset.
- Login con email **o username** tramite Edge Function server-side.
- Recupero password e pagina nuova password.
- Avatar Storage corretto (policy SELECT necessaria per upsert) e cache-busting.
- `Prossime partite` ora mostra solo match `open`; le concluse restano nello storico.
- Campo tattico visuale con drag & drop, squadra e coordinate persistenti su Supabase.
- Bottone indietro coerente sulle pagine secondarie.
- `Chiudi votazioni` spostato su RPC dedicata con controllo organizzatore.
- Home: sottotitolo “Gestisci le tue partite, le squadre e le statistiche.”
- Micro-animazioni brevi di ingresso/cambio pagina.
- UI meno da mockup: radius ridotti, gerarchia tipografica meno estrema, emoji rimosse dalla UI principale, icone Material coerenti.
- Form creazione/chiusura partita, profili e statistiche adattati a schermi piccoli e grandi.
