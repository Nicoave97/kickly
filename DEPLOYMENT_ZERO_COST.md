# Pubblicazione iniziale a 0 €

## Stack
- Flutter Web: gratuito/open source
- GitHub: repository gratuito
- Supabase Free: Auth + PostgreSQL + Realtime + Storage
- Cloudflare Pages: hosting frontend statico
- Dominio: nessuno inizialmente; usa il sottodominio gratuito del provider

## Crescita futura
1. Acquisto dominio Kickly.
2. Collegamento dominio a Cloudflare Pages senza cambiare il codice.
3. Upgrade Supabase quando traffico/database superano il Free tier.
4. SMTP dedicato per email transazionali.
5. Monitoring/error tracking.
6. Edge Functions per inviti privati più rigidi, notifiche, anti-no-show e tornei.
7. Eventuale app Android/iOS dallo stesso progetto Flutter.

L'obiettivo è evitare una migrazione prematura: PostgreSQL, repository e RLS restano validi anche quando il progetto cresce.

## Nota URL V1
Per la prima pubblicazione usiamo gli URL hash di Flutter. Un invito sarà simile a `https://kickly.pages.dev/#/join/AB12CD34`. È meno elegante di un URL pulito, ma funziona su hosting statico senza regole server. Quando collegheremo un dominio possiamo migrare alla Path URL Strategy con rewrite a `index.html`.
