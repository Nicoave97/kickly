# Kickly - backend Supabase remoto

Progetto Supabase: `kickly`
Project ref: `hrbcxlbozhjxefuebtwg`
Regione: `eu-central-1`
Piano: Free

Migrazioni applicate:
- `kickly_v1_core_schema`
- `kickly_v1_access_realtime_storage`
- `kickly_v1_foreign_key_indexes`

Servizi configurati:
- Supabase Auth
- PostgreSQL
- Row Level Security su tutte le tabelle pubbliche Kickly
- Realtime su `matches` e `match_players`
- Storage bucket pubblico `avatars`, upload/modifica/cancellazione limitati alla cartella dell'utente
- trigger automatico creazione profilo alla registrazione
- gestione capienza e lista d'attesa
- chiusura partita e marcatori
- votazioni con media robusta
- vista statistiche carriera

La publishable key client e configurata in `lib/core/config/app_config.dart`.
Non inserire mai service_role o secret key nell'app Flutter.
