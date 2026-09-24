# Struttura Kickly

## `lib/core`
Configurazione, tema, router e widget riutilizzabili. Qui non c'è logica specifica di una singola feature.

## `lib/models`
Oggetti Dart che rappresentano dati del dominio: partita, profilo, partecipante e statistiche.

## `lib/repositories`
È il confine fra UI e backend. Le pagine Flutter chiedono dati ai repository; i repository parlano con Supabase.

Questo evita di spargere query Supabase dentro ogni widget e ci permetterà, in futuro, di cambiare implementazione senza riscrivere tutte le schermate.

## `lib/features`
Schermate raggruppate per area funzionale:
- `auth`: login/registrazione
- `home`: dashboard
- `matches`: creazione, lobby, risultato, pagelle
- `stats`: carriera/storico
- `profile`: profilo e modifica account
- `shell`: navigazione principale

## `supabase/schema.sql`
Backend V1: schema PostgreSQL, RLS, trigger, funzioni e storage.

## Flusso partita

```text
Admin crea partita
     ↓
match + match_players(admin)
     ↓
condivide /match/<uuid>
     ↓
giocatori entrano
     ↓
trigger assegna confermato o waitlist
     ↓
admin/self assegna squadra
     ↓
admin chiude partita
     ↓
finish_match() salva risultato + righe statistiche
     ↓
pagelle
     ↓
trigger aggiorna media voto
     ↓
player_career_stats aggiornata automaticamente dalla view
```

## Sicurezza
- Il client Flutter usa solo la Publishable Key.
- Nessuna Service Role è inclusa nel progetto.
- Tutte le tabelle pubbliche hanno RLS.
- Email/password sono gestite da Supabase Auth, non da tabelle Kickly.
- Data di nascita è in `profile_private`, invisibile agli altri utenti.
- I voti grezzi sono leggibili solo da chi li ha inseriti; gli altri vedono soltanto la media aggregata.
