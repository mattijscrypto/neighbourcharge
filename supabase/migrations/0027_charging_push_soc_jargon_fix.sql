-- ============================================================================
-- 0027_charging_push_soc_jargon_fix.sql
--
-- Task #288 nazorg: de target-reached-push in migratie 0025 gebruikte "SoC"
-- in de body ("Je target-SoC is bereikt"). SoC (State of Charge) is EV-jargon
-- dat gewone paal-boekers niet kennen. Dit maakt de melding onduidelijk voor
-- ~70% van de doelgroep.
--
-- Deze migratie vervangt alleen de target-body door mensentaal:
--   Oud: "Je target-SoC is bereikt. Je kunt de kabel eruit halen wanneer je wilt."
--   Nieuw: "Je auto is opgeladen tot <X>%. Je kunt de kabel eruit halen wanneer je wilt."
--
-- Alle overige teksten (start, eta10, completed) bevatten geen jargon en blijven
-- ongewijzigd.
--
-- Idempotent: create or replace op de trigger-functie.
-- ============================================================================

create or replace function public.on_charging_session_push_events()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_booker_id     uuid;
  v_target_soc    smallint;
  v_start_soc     smallint;
  v_capacity      numeric;
  v_can_track_soc boolean;
  v_charger_name  text;
  v_current_soc   numeric;
  v_eta_min       numeric;
  v_title         text;
  v_body          text;
  v_charger_lbl   text;
begin
  if new.booking_id is null then
    return new;
  end if;

  select b.user_id, b.target_soc_pct, b.start_soc_pct, p.vehicle_battery_capacity_kwh
    into v_booker_id, v_target_soc, v_start_soc, v_capacity
  from public.bookings b
  join public.profiles p on p.id = b.user_id
  where b.id = new.booking_id;

  if v_booker_id is null then
    return new;
  end if;

  v_can_track_soc := (v_start_soc is not null
                      and v_capacity is not null
                      and v_capacity > 0);

  if new.charger_id is not null then
    select c.name into v_charger_name
      from public.chargers c where c.id = new.charger_id;
  end if;
  v_charger_lbl := coalesce(v_charger_name, 'de laadpaal');

  -- a) START-push
  if new.notified_started_at is null and new.status = 'in_progress' then
    if tg_op = 'INSERT'
       or (tg_op = 'UPDATE' and coalesce(old.status, '') <> 'in_progress') then
      v_title := 'Laadsessie gestart';
      if v_can_track_soc then
        v_body := 'Je auto laadt nu op bij ' || v_charger_lbl ||
                  '. We geven je een seintje als hij bijna vol is.';
      else
        v_body := 'Je auto laadt nu op bij ' || v_charger_lbl ||
                  '. We geven je een seintje als de sessie klaar is.';
      end if;
      perform public._cs_fire_push(
        v_booker_id, v_title, v_body,
        'charging_started', new.transaction_id, new.booking_id
      );
      new.notified_started_at := now();
    end if;
  end if;

  -- b + c) alleen zinvol met SoC-tracking
  if v_can_track_soc
     and new.meter_current_wh is not null
     and new.meter_current_wh >= new.meter_start_wh then

    v_current_soc := public._cs_current_soc_pct(
      new.booking_id, new.meter_start_wh, new.meter_current_wh
    );

    -- b) Target reached — mensentaal ipv "SoC"
    if new.notified_target_at is null
       and v_current_soc is not null
       and v_target_soc is not null
       and v_current_soc >= v_target_soc then
      v_title := 'Auto is op ' || v_target_soc || '%';
      v_body  := 'Je auto is opgeladen tot ' || v_target_soc ||
                 '%. Je kunt de kabel eruit halen wanneer je wilt.';
      perform public._cs_fire_push(
        v_booker_id, v_title, v_body,
        'charging_target_reached', new.transaction_id, new.booking_id
      );
      new.notified_target_at := now();
    end if;

    -- c) ETA 10 min
    if new.notified_eta10_at is null
       and (v_current_soc is null or v_target_soc is null or v_current_soc < v_target_soc) then
      v_eta_min := public._cs_eta_minutes(
        new.booking_id,
        new.meter_start_wh,
        new.meter_current_wh,
        new.started_at,
        new.last_meter_at
      );
      if v_eta_min is not null and v_eta_min <= 10 and v_eta_min > 0 then
        v_title := 'Bijna klaar met laden';
        v_body  := 'Nog ongeveer ' || round(v_eta_min)::text ||
                   ' min tot ' || v_target_soc || '%. ' ||
                   'Tijd om terug te lopen naar je auto.';
        perform public._cs_fire_push(
          v_booker_id, v_title, v_body,
          'charging_eta_10min', new.transaction_id, new.booking_id
        );
        new.notified_eta10_at := now();
      end if;
    end if;
  end if;

  -- d) COMPLETED-push
  if new.notified_completed_at is null and new.status = 'completed' then
    if tg_op = 'INSERT'
       or (tg_op = 'UPDATE' and coalesce(old.status, '') <> 'completed') then
      v_title := 'Laadsessie afgelopen';
      v_body  := 'Je sessie bij ' || v_charger_lbl ||
                 ' is beeindigd. Open de app voor je verbruik en betaling.';
      perform public._cs_fire_push(
        v_booker_id, v_title, v_body,
        'charging_completed', new.transaction_id, new.booking_id
      );
      new.notified_completed_at := now();
    end if;
  end if;

  return new;
exception when others then
  raise notice 'on_charging_session_push_events: fout onderdrukt (%): %', tg_op, sqlerrm;
  return new;
end;
$$;

comment on function public.on_charging_session_push_events() is
  'BEFORE INSERT OR UPDATE trigger op charging_sessions. Push notifications voor start/target/eta10/completed. Target-body in mensentaal (geen "SoC"-jargon). Idempotent via notified_*_at kolommen.';
