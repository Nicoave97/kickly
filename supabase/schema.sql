-- KICKLY V1.1 - schema Supabase/PostgreSQL
-- Il progetto remoto Kickly è già configurato. Questo file serve come riferimento/riproduzione pulita.

create extension if not exists pgcrypto;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (char_length(username) between 3 and 30),
  full_name text not null,
  avatar_url text,
  preferred_role text not null default 'Non specificato',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profile_private (
  user_id uuid primary key references auth.users(id) on delete cascade,
  birth_date date,
  updated_at timestamptz not null default now()
);

create table if not exists public.matches (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete restrict,
  title text not null check (char_length(title) between 1 and 80),
  starts_at timestamptz not null,
  venue_name text not null,
  venue_address text,
  max_players int not null default 10 check (max_players between 2 and 50),
  bench_slots int not null default 4 check (bench_slots between 0 and 50),
  team_mode text not null default 'admin' check (team_mode in ('admin','self')),
  rating_mode text not null default 'all' check (rating_mode in ('off','teammates','all','opponents')),
  team_a_name text not null default 'Squadra A',
  team_b_name text not null default 'Squadra B',
  status text not null default 'open' check (status in ('open','completed','cancelled')),
  score_a int check (score_a is null or score_a >= 0),
  score_b int check (score_b is null or score_b >= 0),
  ratings_open boolean not null default false,
  invite_code text not null unique default upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.match_players (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'confirmed' check (status in ('confirmed','waitlist')),
  team text not null default 'unassigned' check (team in ('a','b','unassigned')),
  position_x numeric(5,4) check (position_x is null or (position_x >= 0 and position_x <= 1)),
  position_y numeric(5,4) check (position_y is null or (position_y >= 0 and position_y <= 1)),
  attendance_status text not null default 'pending' check (attendance_status in ('pending','confirmed','maybe','declined')),
  joined_at timestamptz not null default now(),
  primary key (match_id,user_id)
);

create table if not exists public.match_player_stats (
  match_id uuid not null references public.matches(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  goals int not null default 0 check (goals >= 0),
  rating_avg numeric(4,2),
  rating_count int not null default 0 check (rating_count >= 0),
  primary key (match_id,user_id)
);

create table if not exists public.ratings (
  match_id uuid not null references public.matches(id) on delete cascade,
  from_user_id uuid not null references public.profiles(id) on delete cascade,
  to_user_id uuid not null references public.profiles(id) on delete cascade,
  rating numeric(3,1) not null check (rating between 5 and 10 and rating * 2 = trunc(rating * 2)),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (match_id,from_user_id,to_user_id),
  check (from_user_id <> to_user_id)
);

create index if not exists idx_matches_starts_at on public.matches(starts_at);
create index if not exists idx_matches_creator_id on public.matches(creator_id);
create index if not exists idx_match_players_user on public.match_players(user_id);
create index if not exists idx_match_stats_user on public.match_player_stats(user_id);
create index if not exists idx_ratings_from_user_id on public.ratings(from_user_id);
create index if not exists idx_ratings_to_user_id on public.ratings(to_user_id);

create or replace function private.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end; $$;
revoke all on function private.set_updated_at() from public, anon, authenticated;

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles for each row execute function private.set_updated_at();
drop trigger if exists trg_private_updated on public.profile_private;
create trigger trg_private_updated before update on public.profile_private for each row execute function private.set_updated_at();
drop trigger if exists trg_matches_updated on public.matches;
create trigger trg_matches_updated before update on public.matches for each row execute function private.set_updated_at();
drop trigger if exists trg_ratings_updated on public.ratings;
create trigger trg_ratings_updated before update on public.ratings for each row execute function private.set_updated_at();

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_username text;
  v_name text;
begin
  v_username := lower(regexp_replace(coalesce(nullif(new.raw_user_meta_data ->> 'username',''), 'player_' || substr(new.id::text,1,8)), '[^a-zA-Z0-9_]', '', 'g'));
  if char_length(v_username) < 3 then v_username := 'player_' || substr(new.id::text,1,8); end if;
  if exists(select 1 from public.profiles where username = v_username) then
    v_username := left(v_username,20) || '_' || substr(new.id::text,1,6);
  end if;
  v_name := coalesce(nullif(new.raw_user_meta_data ->> 'full_name',''), 'Giocatore');
  insert into public.profiles(id,username,full_name) values(new.id,v_username,v_name);
  insert into public.profile_private(user_id) values(new.id);
  return new;
end; $$;
revoke all on function private.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function private.handle_new_user();

create or replace function private.prepare_match_player()
returns trigger language plpgsql set search_path = '' as $$
declare
  v_match public.matches%rowtype;
  v_confirmed int;
  v_total int;
begin
  select * into v_match from public.matches where id = new.match_id;
  if not found or v_match.status <> 'open' then raise exception 'Partita non disponibile'; end if;

  select count(*) into v_total
  from public.match_players mp
  where mp.match_id = new.match_id;
  if v_total >= v_match.max_players + v_match.bench_slots then raise exception 'Lobby completa'; end if;

  select count(*) into v_confirmed
  from public.match_players mp
  where mp.match_id = new.match_id and mp.status='confirmed';

  if v_confirmed >= v_match.max_players then
    new.status := 'waitlist';
    new.team := 'unassigned';
  else
    new.status := 'confirmed';
    if v_match.team_mode = 'admin' then new.team := 'unassigned'; end if;
  end if;
  return new;
end; $$;
revoke all on function private.prepare_match_player() from public, anon, authenticated;

drop trigger if exists trg_prepare_match_player on public.match_players;
create trigger trg_prepare_match_player before insert on public.match_players for each row execute function private.prepare_match_player();

create or replace function private.guard_match_player_update()
returns trigger
language plpgsql
set search_path to ''
as $function$
declare
  v_creator uuid;
  v_team_mode text;
  v_max int;
  v_confirmed int;
begin
  if new.match_id <> old.match_id or new.user_id <> old.user_id then
    raise exception 'Identità partecipante non modificabile';
  end if;

  select creator_id,team_mode,max_players into v_creator,v_team_mode,v_max
  from public.matches where id=old.match_id;

  if (select auth.uid()) = v_creator then
    if old.status='waitlist' and new.status='confirmed' then
      select count(*) into v_confirmed
      from public.match_players
      where public.match_players.match_id=old.match_id and status='confirmed';
      if v_confirmed >= v_max then raise exception 'Nessun posto libero'; end if;
    end if;
    return new;
  end if;

  if (select auth.uid()) = old.user_id then
    if new.status <> old.status or new.joined_at <> old.joined_at then
      raise exception 'Stato partecipazione non modificabile';
    end if;

    if new.attendance_status is distinct from old.attendance_status then
      if new.team is distinct from old.team
        or new.position_x is distinct from old.position_x
        or new.position_y is distinct from old.position_y then
        raise exception 'Modifica presenza non valida';
      end if;
      return new;
    end if;

    if v_team_mode <> 'self' or old.status <> 'confirmed' then
      raise exception 'Cambio squadra non consentito';
    end if;
    return new;
  end if;

  raise exception 'Operazione non consentita';
end; $function$;
revoke all on function private.guard_match_player_update() from public, anon, authenticated;

drop trigger if exists trg_guard_match_player_update on public.match_players;
create trigger trg_guard_match_player_update before update on public.match_players for each row execute function private.guard_match_player_update();

create or replace function private.refresh_rating_summary()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_match uuid;
  v_user uuid;
  v_count int;
  v_avg numeric;
begin
  if tg_op = 'DELETE' then
    v_match := old.match_id;
    v_user := old.to_user_id;
  else
    v_match := new.match_id;
    v_user := new.to_user_id;
  end if;

  select count(*) into v_count
  from public.ratings r
  where r.match_id=v_match and r.to_user_id=v_user;

  with ordered as (
    select rating,
           count(*) over() total,
           row_number() over(order by rating asc, created_at asc, from_user_id asc) rn_low,
           row_number() over(order by rating desc, created_at desc, from_user_id desc) rn_high
    from public.ratings r
    where r.match_id=v_match and r.to_user_id=v_user
  )
  select avg(rating) into v_avg
  from ordered
  where total < 5 or (rn_low > 1 and rn_high > 1);

  insert into public.match_player_stats(match_id,user_id,rating_avg,rating_count)
  values(v_match,v_user,v_avg,v_count)
  on conflict(match_id,user_id)
  do update set rating_avg=excluded.rating_avg,rating_count=excluded.rating_count;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end; $$;
revoke all on function private.refresh_rating_summary() from public, anon, authenticated;

drop trigger if exists trg_refresh_rating_summary on public.ratings;
create trigger trg_refresh_rating_summary after insert or update or delete on public.ratings for each row execute function private.refresh_rating_summary();

alter table public.profiles enable row level security;
alter table public.profile_private enable row level security;
alter table public.matches enable row level security;
alter table public.match_players enable row level security;
alter table public.match_player_stats enable row level security;
alter table public.ratings enable row level security;

DO $$ declare r record; begin
  for r in select policyname,tablename from pg_policies where schemaname='public' and tablename in ('profiles','profile_private','matches','match_players','match_player_stats','ratings') loop
    execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename);
  end loop;
end $$;

create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_update_own on public.profiles for update to authenticated using ((select auth.uid())=id) with check ((select auth.uid())=id);

create policy private_read_own on public.profile_private for select to authenticated using ((select auth.uid())=user_id);
create policy private_insert_own on public.profile_private for insert to authenticated with check ((select auth.uid())=user_id);
create policy private_update_own on public.profile_private for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);

create policy matches_read on public.matches for select to authenticated using (true);
create policy matches_insert_own on public.matches for insert to authenticated with check ((select auth.uid())=creator_id);
create policy matches_update_admin on public.matches for update to authenticated using ((select auth.uid())=creator_id) with check ((select auth.uid())=creator_id);
create policy matches_delete_admin on public.matches for delete to authenticated using ((select auth.uid())=creator_id);

create policy match_players_read on public.match_players for select to authenticated using (true);
create policy match_players_join_self on public.match_players for insert to authenticated with check ((select auth.uid())=user_id);
create policy match_players_update on public.match_players for update to authenticated
using (
  (select auth.uid())=user_id
  or exists(select 1 from public.matches m where m.id=match_players.match_id and m.creator_id=(select auth.uid()))
)
with check (
  (select auth.uid())=user_id
  or exists(select 1 from public.matches m where m.id=match_players.match_id and m.creator_id=(select auth.uid()))
);
create policy match_players_delete on public.match_players for delete to authenticated
using (
  (select auth.uid())=user_id
  or exists(select 1 from public.matches m where m.id=match_players.match_id and m.creator_id=(select auth.uid()))
);

create policy stats_read on public.match_player_stats for select to authenticated using (true);
create policy stats_insert_admin on public.match_player_stats for insert to authenticated
with check (exists(select 1 from public.matches m where m.id=match_player_stats.match_id and m.creator_id=(select auth.uid())));
create policy stats_update_admin on public.match_player_stats for update to authenticated
using (exists(select 1 from public.matches m where m.id=match_player_stats.match_id and m.creator_id=(select auth.uid())))
with check (exists(select 1 from public.matches m where m.id=match_player_stats.match_id and m.creator_id=(select auth.uid())));

create policy ratings_read_own on public.ratings for select to authenticated using ((select auth.uid())=from_user_id);
create policy ratings_insert_allowed on public.ratings for insert to authenticated
with check (
  (select auth.uid())=ratings.from_user_id
  and exists (
    select 1
    from public.matches m
    join public.match_players a on a.match_id=m.id and a.user_id=ratings.from_user_id and a.status='confirmed'
    join public.match_players b on b.match_id=m.id and b.user_id=ratings.to_user_id and b.status='confirmed'
    where m.id=ratings.match_id
      and m.status='completed'
      and m.ratings_open=true
      and m.rating_mode<>'off'
      and (
        m.rating_mode='all'
        or (m.rating_mode='teammates' and a.team in ('a','b') and a.team=b.team)
        or (m.rating_mode='opponents' and a.team in ('a','b') and b.team in ('a','b') and a.team<>b.team)
      )
  )
);
create policy ratings_update_own on public.ratings for update to authenticated
using (
  (select auth.uid())=ratings.from_user_id
  and exists(select 1 from public.matches m where m.id=ratings.match_id and m.status='completed' and m.ratings_open=true)
)
with check (
  (select auth.uid())=ratings.from_user_id
  and exists (
    select 1
    from public.matches m
    join public.match_players a on a.match_id=m.id and a.user_id=ratings.from_user_id and a.status='confirmed'
    join public.match_players b on b.match_id=m.id and b.user_id=ratings.to_user_id and b.status='confirmed'
    where m.id=ratings.match_id
      and m.status='completed'
      and m.ratings_open=true
      and m.rating_mode<>'off'
      and (
        m.rating_mode='all'
        or (m.rating_mode='teammates' and a.team in ('a','b') and a.team=b.team)
        or (m.rating_mode='opponents' and a.team in ('a','b') and b.team in ('a','b') and a.team<>b.team)
      )
  )
);
create policy ratings_delete_own on public.ratings for delete to authenticated
using (
  (select auth.uid())=ratings.from_user_id
  and exists(select 1 from public.matches m where m.id=ratings.match_id and m.status='completed' and m.ratings_open=true)
);

create or replace function public.finish_match(
  p_match_id uuid,
  p_score_a int,
  p_score_b int,
  p_open_ratings boolean,
  p_goals jsonb default '{}'::jsonb
)
returns void
language plpgsql
security invoker
set search_path = 'public'
as $$
begin
  if p_score_a < 0 or p_score_b < 0 then raise exception 'Risultato non valido'; end if;
  if not exists(select 1 from public.matches where id=p_match_id and creator_id=(select auth.uid())) then
    raise exception 'Solo l’organizzatore può chiudere la partita';
  end if;

  update public.matches
  set score_a=p_score_a,
      score_b=p_score_b,
      status='completed',
      ratings_open=(p_open_ratings and rating_mode<>'off')
  where id=p_match_id;

  insert into public.match_player_stats(match_id,user_id,goals)
  select p_match_id,mp.user_id,0
  from public.match_players mp
  where mp.match_id=p_match_id and mp.status='confirmed'
  on conflict(match_id,user_id) do nothing;

  update public.match_player_stats s
  set goals = greatest(coalesce((p_goals ->> s.user_id::text)::int,0),0)
  where s.match_id=p_match_id;
end; $$;
revoke all on function public.finish_match(uuid,int,int,boolean,jsonb) from public, anon;
grant execute on function public.finish_match(uuid,int,int,boolean,jsonb) to authenticated;

create or replace function public.close_match_ratings(p_match_id uuid)
returns void
language plpgsql
security invoker
set search_path = 'public'
as $$
begin
  update public.matches
  set ratings_open = false
  where id = p_match_id and creator_id = (select auth.uid());
  if not found then raise exception 'Solo l’organizzatore può chiudere le votazioni'; end if;
end; $$;
revoke all on function public.close_match_ratings(uuid) from public, anon;
grant execute on function public.close_match_ratings(uuid) to authenticated;

create or replace view public.player_career_stats
with (security_invoker=true)
as
select
  p.id as user_id,
  count(m.id) filter (where m.status='completed' and mp.status='confirmed')::int as matches_played,
  coalesce(sum(s.goals) filter (where m.status='completed'),0)::int as goals,
  count(*) filter (where m.status='completed' and mp.status='confirmed' and ((mp.team='a' and m.score_a>m.score_b) or (mp.team='b' and m.score_b>m.score_a)))::int as wins,
  count(*) filter (where m.status='completed' and mp.status='confirmed' and m.score_a=m.score_b)::int as draws,
  count(*) filter (where m.status='completed' and mp.status='confirmed' and ((mp.team='a' and m.score_a<m.score_b) or (mp.team='b' and m.score_b<m.score_a)))::int as losses,
  round(avg(s.rating_avg) filter (where s.rating_avg is not null),2) as average_rating,
  max(s.rating_avg) as best_rating,
  count(*) filter (
    where s.rating_avg is not null
      and s.rating_avg = (
        select max(s2.rating_avg)
        from public.match_player_stats s2
        where s2.match_id=s.match_id and s2.rating_avg is not null
      )
  )::int as mvp_count,
  mode() within group (order by m.venue_name) filter (where m.status='completed') as favorite_venue
from public.profiles p
left join public.match_players mp on mp.user_id=p.id
left join public.matches m on m.id=mp.match_id
left join public.match_player_stats s on s.match_id=mp.match_id and s.user_id=p.id
group by p.id;

grant select on public.profiles, public.matches, public.match_players, public.match_player_stats, public.ratings, public.profile_private to authenticated;
grant insert,update,delete on public.matches, public.match_players, public.match_player_stats, public.ratings, public.profile_private to authenticated;
grant update on public.profiles to authenticated;
grant select on public.player_career_stats to authenticated;

-- Realtime: eseguire solo se le tabelle non sono già nella publication.
do $$ begin
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='match_players') then
    alter publication supabase_realtime add table public.match_players;
  end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='matches') then
    alter publication supabase_realtime add table public.matches;
  end if;
end $$;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('avatars','avatars',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update
set public=true,
    file_size_limit=5242880,
    allowed_mime_types=array['image/jpeg','image/png','image/webp'];

drop policy if exists avatar_select_own on storage.objects;
drop policy if exists avatar_insert_own on storage.objects;
drop policy if exists avatar_update_own on storage.objects;
drop policy if exists avatar_delete_own on storage.objects;
create policy avatar_select_own on storage.objects for select to authenticated
using (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid()::text));
create policy avatar_insert_own on storage.objects for insert to authenticated
with check (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid()::text));
create policy avatar_update_own on storage.objects for update to authenticated
using (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid()::text))
with check (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid()::text));
create policy avatar_delete_own on storage.objects for delete to authenticated
using (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid()::text));

-- Kickly security hardening: least-privilege grants, private lobbies,
-- secure invite join, login rate limiting and server-side input constraints.

revoke all privileges on table public.profiles from anon, authenticated;
revoke all privileges on table public.profile_private from anon, authenticated;
revoke all privileges on table public.matches from anon, authenticated;
revoke all privileges on table public.match_players from anon, authenticated;
revoke all privileges on table public.match_player_stats from anon, authenticated;
revoke all privileges on table public.ratings from anon, authenticated;
revoke all privileges on table public.player_career_stats from anon, authenticated;

grant select, update on table public.profiles to authenticated;
grant select, insert, update on table public.profile_private to authenticated;
grant select, insert, update, delete on table public.matches to authenticated;
grant select, update, delete on table public.match_players to authenticated;
grant select on table public.match_player_stats to authenticated;
grant insert(match_id, user_id, goals) on table public.match_player_stats to authenticated;
grant update(goals) on table public.match_player_stats to authenticated;
grant select, insert, update, delete on table public.ratings to authenticated;
grant select on table public.player_career_stats to authenticated;

alter table public.profiles
  drop constraint if exists profiles_username_format_check,
  add constraint profiles_username_format_check check (username ~ '^[a-z0-9_]{3,30}$'),
  drop constraint if exists profiles_full_name_length_check,
  add constraint profiles_full_name_length_check check (char_length(full_name) between 1 and 80),
  drop constraint if exists profiles_preferred_role_check,
  add constraint profiles_preferred_role_check check (preferred_role in ('Non specificato','Portiere','Difensore','Centrocampista','Attaccante','Universale')),
  drop constraint if exists profiles_avatar_url_length_check,
  add constraint profiles_avatar_url_length_check check (avatar_url is null or char_length(avatar_url) <= 2048);

alter table public.matches
  drop constraint if exists matches_venue_name_length_check,
  add constraint matches_venue_name_length_check check (char_length(venue_name) between 1 and 120),
  drop constraint if exists matches_venue_address_length_check,
  add constraint matches_venue_address_length_check check (venue_address is null or char_length(venue_address) <= 240),
  drop constraint if exists matches_team_a_name_length_check,
  add constraint matches_team_a_name_length_check check (char_length(team_a_name) between 1 and 40),
  drop constraint if exists matches_team_b_name_length_check,
  add constraint matches_team_b_name_length_check check (char_length(team_b_name) between 1 and 40),
  drop constraint if exists matches_invite_code_format_check,
  add constraint matches_invite_code_format_check check (invite_code ~ '^[A-Z0-9]{8}$');

create table if not exists private.login_attempts (
  id bigint generated by default as identity primary key,
  identifier_hash text not null,
  ip_hash text,
  attempted_at timestamptz not null default now()
);
create index if not exists login_attempts_identifier_time_idx
  on private.login_attempts(identifier_hash, attempted_at desc);
create index if not exists login_attempts_ip_time_idx
  on private.login_attempts(ip_hash, attempted_at desc) where ip_hash is not null;
revoke all on table private.login_attempts from public, anon, authenticated;

create or replace function public.consume_username_login_attempt(
  p_identifier_hash text,
  p_ip_hash text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_identifier_count integer;
  v_ip_count integer := 0;
begin
  if p_identifier_hash is null or length(p_identifier_hash) < 32 then return false; end if;
  delete from private.login_attempts where attempted_at < now() - interval '1 hour';
  select count(*) into v_identifier_count
  from private.login_attempts
  where identifier_hash = p_identifier_hash and attempted_at >= now() - interval '5 minutes';
  if p_ip_hash is not null then
    select count(*) into v_ip_count
    from private.login_attempts
    where ip_hash = p_ip_hash and attempted_at >= now() - interval '5 minutes';
  end if;
  if v_identifier_count >= 15 or v_ip_count >= 40 then return false; end if;
  insert into private.login_attempts(identifier_hash, ip_hash) values (p_identifier_hash, p_ip_hash);
  return true;
end;
$$;
revoke all on function public.consume_username_login_attempt(text,text) from public, anon, authenticated;
grant execute on function public.consume_username_login_attempt(text,text) to service_role;

create or replace function private.can_access_match(p_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.matches m
      where m.id = p_match_id
        and (
          m.status = 'completed'
          or m.creator_id = (select auth.uid())
          or exists (
            select 1 from public.match_players mp
            where mp.match_id = m.id and mp.user_id = (select auth.uid())
          )
        )
    );
$$;

grant usage on schema private to authenticated;
revoke all on function private.can_access_match(uuid) from public, anon;
grant execute on function private.can_access_match(uuid) to authenticated;

drop policy if exists matches_read on public.matches;
create policy matches_read on public.matches for select to authenticated
using (
  creator_id = (select auth.uid())
  or status='completed'
  or private.can_access_match(id)
);

drop policy if exists match_players_read on public.match_players;
create policy match_players_read on public.match_players for select to authenticated
using (private.can_access_match(match_id));

drop policy if exists match_players_join_self on public.match_players;
revoke insert on table public.match_players from authenticated;

-- Invite preview/join are intentionally handled by the authenticated
-- Edge Function `match-invite`, not by SECURITY DEFINER RPCs in the Data API.
drop function if exists public.preview_match_invite(text);
drop function if exists public.join_match_by_code(text,text);
drop function if exists public.can_access_match(uuid);
