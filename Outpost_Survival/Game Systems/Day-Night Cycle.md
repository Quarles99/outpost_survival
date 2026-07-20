# Day/Night Cycle

The "not ready" flag below is now lifted (per an explicit request) - the clock itself and the recruit cooldown are implemented; the rest of this note's original vision is still open backlog, not started.

## Current implementation

`DayNightCycle` autoload (`autoload/day_night_cycle.gd`) - a continuously running clock, day phase (480s/8min) then night phase (240s/4min), a 2:1 ratio per an explicit request. `day_started`/`night_started` signals fire at each transition; `day_number` increments at dawn. HUD shows "Day N - Day/Night" (`HUD.set_day_label`); `$DayNightTint` (a `CanvasModulate` under `Base`, per CLAUDE.md - only affects world `CanvasItem`s, not any UI `CanvasLayer`) tweens between a neutral day color and a dusk-blue night tint over 8s on each transition, snapped instantly (no tween) on `_ready()` to whatever phase was actually loaded/restored rather than always starting bright. Full state (day number, phase, elapsed time within the phase, last-recruit day) persists through `Base._serialize_state()`/`_apply_state()`, so it survives save/load and a battle-deployment round trip identically.

**Recruit cooldown** - the one real mechanic wired to the clock so far, per an explicit request: `DayNightCycle.can_recruit()`/`mark_recruited()`/`days_until_next_recruit()`, gated by `recruit_cooldown_days` (currently 1, exposed as a plain `var` rather than a `const` specifically so a future upgrade can lower it - nothing does yet). `Base._on_outpost_hall_clicked` checks it before even opening the recruit panel (flashes "Recruiting available in N more days" instead), and `_on_candidate_selected` calls `mark_recruited()` on a successful recruit.

**Deliberately not wired yet** (explicit scope decision when this was greenlit - see Changelog): food consumption, work schedules/sleep, and every other item below. `DayNightCycle`'s signals exist specifically so those can hook in later without reworking the clock itself.

## Deferred / original vision (not started)

- Citizens need 8 hours of sleep a day; prefer to sleep at night.
- 4 hours of free time per day (not counting sleep) where a citizen doesn't have to work — happiness bonus during this time.
- Initial 3 citizens can sleep in the Outpost Hall, but others need houses.
- Citizens eat 2 meals a day; can carry food on them for the day's meals, or pick it up from the storehouse when needed.
- Economy will need rebalancing to account for this downtime and still allow growth out of the early game.

Migrated from `Implement_Next.txt` (queued, never started) when the Ideas vault took over as the implementation backlog.

## Changelog

- **2026-07-16 - Clock + recruit cooldown implemented.** Per an explicit request scoping this pass to "core clock + recruit cooldown only" (the sleep/meals/happiness mechanics above were explicitly deferred, not forgotten) - see Current implementation above. Verified headlessly: day/night boundary transitions fire correctly with the right day numbers, the recruit cooldown blocks `_on_outpost_hall_clicked` from opening the panel and correctly re-applies itself after a real recruit via the actual `_on_candidate_selected` path (not simulated), and the full save/load round trip preserves day number, phase, elapsed time, and last-recruit day exactly.
