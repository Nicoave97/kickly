alter table public.match_players
  add column if not exists attendance_status text not null default 'pending';

alter table public.match_players
  drop constraint if exists match_players_attendance_status_check;

alter table public.match_players
  add constraint match_players_attendance_status_check
  check (attendance_status in ('pending','confirmed','maybe','declined'));

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

  select creator_id, team_mode, max_players
  into v_creator, v_team_mode, v_max
  from public.matches
  where id = old.match_id;

  if (select auth.uid()) = v_creator then
    if old.status='waitlist' and new.status='confirmed' then
      select count(*) into v_confirmed
      from public.match_players
      where public.match_players.match_id=old.match_id
        and status='confirmed';
      if v_confirmed >= v_max then
        raise exception 'Nessun posto libero';
      end if;
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
end;
$function$;
