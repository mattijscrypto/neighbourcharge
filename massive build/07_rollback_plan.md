# 07 — Rollback plan

> Elke laag heeft een eigen rollback-pad. Rollback is per-laag, niet all-or-nothing.

---

## Beslissingsmatrix — wanneer rollback?

| Symptoom | Waarschijnlijke oorzaak | Actie |
|---|---|---|
| Oude app 1.2.3+13 kan niet meer inloggen | RLS te strict | **Rollback DB migratie** — direct |
| Oude app crashet bij boeking laden | Kolom-drop of NOT NULL zonder default | **Rollback DB migratie** — direct |
| Nieuwe app 1.3.0+14 crashes bij DAC7 banner | `Dac7Status.fromMap` mismatch met RPC return | **Hotfix Flutter build** — 1.3.1+15 |
| CSMS reageert niet, palen kunnen niet starten | VPS down / Supabase creds fout | **Restart CSMS service** eerst, dan rollback code als het blijft |
| Payouts-block blokkeert álle checkouts (niet alleen boven-drempel owners) | Bug in `create-payment-stripe` guard | **Redeploy vorige versie edge function** |
| Stripe webhooks komen niet aan | Endpoint URL of secret fout | **Verify + fix Dashboard**, geen rollback nodig |
| iOS submission wordt rejected | Reviewer notes / privacy labels | Fix + resubmit — geen productie-impact |

---

## Laag 1 — Supabase database

### Als een migratie fout is (0028 t/m 0032)

**Snelste pad:** restore van pre-deploy snapshot.

```bash
# Supabase Dashboard → Database → Backups → Restore
# Kies de snapshot van vóór de deploy
```

Dit gooit ALLES sinds snapshot weg — inclusief nieuwe boekingen en signups tussen deploy en rollback. Dus alleen als het écht crisis is (dataverlies vs. downtime trade-off).

**Zachter pad:** revert alleen de specifieke migratie:

- `0028_booking_window_auto_stop.sql` — `DROP TRIGGER ...; DROP FUNCTION ...;`
- `0029_booking_extend_flow.sql` — `DROP FUNCTION extend_booking;`
- `0030_chargers_column_grants.sql` — dit is DE fix voor #241/#188. Rollback maakt RLS-recursie weer stuk. Niet aan te raden.
- `0031_quarterly_statements.sql` — `DROP TABLE quarterly_statements;` (leeg tabel, geen data-verlies risico)
- `0032_dac7_bsn_flow.sql` — complex; `DROP TABLE dac7_reporting_state, dac7_tin_submissions; DROP FUNCTION dac7_status_for_owner;`

Maak per migratie een `down.sql` in de folder (nu doen, niet later) — zie actie hieronder.

### Actie NU vóór deploy: schrijf down.sql per migratie

- [ ] `supabase/migrations/0028_booking_window_auto_stop.down.sql`
- [ ] `supabase/migrations/0029_booking_extend_flow.down.sql`
- [ ] `supabase/migrations/0031_quarterly_statements.down.sql`
- [ ] `supabase/migrations/0032_dac7_bsn_flow.down.sql`

(0030 heeft geen down want #241 rollback == teruggaan naar RLS-recursie bug.)

---

## Laag 2 — Edge functions

### Rollback

```bash
# Zoek vorige deploy hash
supabase functions list

# Redeploy previous version (Supabase houdt versies bij)
git checkout <previous-commit> -- supabase/functions/<name>
supabase functions deploy <name>
git checkout HEAD -- supabase/functions/<name>
```

**Kritieke functies om snel te kunnen rollen:**

- `create-payment-stripe` — bij DAC7-guard bug
- `submit-tin` — bij encryption/RPC failure
- `remote-start-session` / `remote-stop-session` — bij OCPP glue-fout

Bewaar de `git rev-parse HEAD` van vóór de deploy op een sticky note.

---

## Laag 3 — CSMS (Hetzner VPS)

### Restart

```bash
ssh csms.pluggoapp.nl
systemctl restart pluggo-csms
journalctl -u pluggo-csms -f
```

### Rollback naar vorige code

```bash
cd /opt/pluggo-csms
git log  # zoek vorige commit
git checkout <hash>
npm ci --production
systemctl restart pluggo-csms
```

### Volledig VPS-verlies

- Snapshot van Hetzner (dagelijkse backups aanzetten vóór productie-go-live)
- Restore snapshot in Hetzner Console
- DNS-record `csms.pluggoapp.nl` naar nieuwe IP als provisioned op andere machine

---

## Laag 4 — Flutter mobile builds

### Play Store

- **Als staged rollout nog < 100%:** halt rollout in Play Console → Rollout tab → Halt
- **Als 100%:** kun je niet "unpublishen", MAAR:
  - Upload snel 1.3.1+15 hotfix met bug fix
  - Kan ook 1.2.3+13 opnieuw uploaden als "1.3.1" (Play staat toe zolang versionCode omhoog gaat), maar dat schaadt vertrouwen en verwarrt users

### App Store

- **Voor approval:** je kan de submission cancelen, resubmit later
- **Na approval, vóór release:** je hebt "Manual Release" gekozen (per plan). Klik niet op "Release" totdat je zeker weet dat het werkt
- **Na release:** expedited review request via Apple Developer, submit 1.3.1+15 hotfix. Duur: 24-48 uur meestal
- **Kill switch:** heb je een min-version check in-app? Als ja: force-update prompt voor 1.3.0+14 → nieuwe versie zodra hotfix live is

### Actie NU vóór deploy: verify min-version kill switch

- [ ] Check `lib/main.dart` voor een `min_supported_version` check die naar Supabase pingt bij app start
- [ ] Als NIET aanwezig: overweeg om vóór de big-bang toe te voegen. Kleine feature, grote peace of mind.

---

## Laag 5 — Comms rollback

Als je de Pluggo Pioniers-mail al hebt verstuurd en er is een groot probleem:

- Stuur ASAP follow-up mail: "Bekende issue met [X], we werken aan een fix in 1.3.1"
- LinkedIn post pinnen met status
- Update FAQ met known issue

Vermijd het verwijderen van de LinkedIn post (dat trekt aandacht). Pin een reply of update-post.

---

## Communicatie tijdens incident

**Wie doet wat:**

- **Mattijs:** technical decisions, edge function/DB rollback, incident communicatie extern
- **Raka:** support-inbox monitoring, user vragen beantwoorden, escaleren wat kritiek is

**Kanalen:**

- Support: support@pluggoapp.nl
- Interne coördinatie: WhatsApp / Signal
- Public status: `pluggoapp.nl/status` (bestaat die? Zo niet, tijdens incident LinkedIn post + FAQ update)

---

## Post-incident

- [ ] Blameless postmortem in `_internal/postmortems/`
- [ ] Wat brak, waarom, hoe voorkomen
- [ ] Runbook update

---

## Preventieve maatregelen die nu geregeld moeten worden

- [ ] Supabase snapshot vóór deploy
- [ ] Hetzner snapshot vóór CSMS-first-boot
- [ ] `git tag pre-massive-build-<datum>` op main branch
- [ ] `down.sql` per migratie (zie hierboven)
- [ ] Min-version kill switch in-app (indien nog niet aanwezig)
- [ ] Sentry / error tracking overwegen (post-deploy monitoring)
- [ ] Support-inbox voorbereiden op vragenspike
