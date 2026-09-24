# Kickly V1.1

Kickly è una web app Flutter per organizzare partite di calcetto, gestire squadre, risultato, gol, pagelle e statistiche storiche.

## Stack
- Flutter Web
- Supabase Auth
- PostgreSQL + RLS
- Supabase Realtime
- Supabase Storage per avatar
- Supabase Edge Function per login con username

## Avvio locale

```bash
flutter pub get
flutter run -d chrome --web-port 3000
```

La porta `3000` è consigliata anche per testare in locale i redirect Auth/password reset.

## Funzioni V1.1
- Registrazione e login
- Login con **email oppure username**
- Recupero password via email
- Profilo con avatar, username, ruolo e data di nascita privata
- Layout responsive mobile / tablet / desktop
- Navigazione mobile con bottom bar e desktop con NavigationRail
- Creazione partita e link invito
- Squadre gestite dall'admin oppure auto-selezionate dai giocatori
- Campo tattico visuale con drag & drop e posizioni persistenti
- Lista d'attesa / panchina
- Risultato e gol
- Pagelle post-partita
- Chiusura votazioni admin
- Statistiche e storico
- Profili pubblici e confronto
- Lobby pubbliche e tornei lasciati come Coming Soon

## Backend remoto
Il progetto Supabase `kickly` è già configurato e collegato tramite publishable key. La `service_role` non è presente nel client Flutter.

## Password reset
In sviluppo usa preferibilmente `flutter run -d chrome --web-port 3000`.
Prima della pubblicazione definitiva bisognerà impostare in Supabase Auth il Site URL e i Redirect URL del dominio pubblico di Kickly.

## Edge Function
`supabase/functions/login-with-identifier/index.ts` implementa l'accesso tramite username senza esporre l'email dell'utente al client.

## Costi iniziali
L'architettura resta utilizzabile a costo 0 con Flutter + Supabase Free + hosting statico gratuito. Dominio, piano backend superiore e donazioni PayPal/Revolut potranno essere aggiunti in seguito.
