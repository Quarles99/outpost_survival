Save units gather tick cd to prevent all units swinging at the same time after loading game.

## Completion write-up (2026-07-17)

**Done:** `Character` now tracks `_tick_remaining` - time left until its current production tick fires - persisted per-citizen in `Base._serialize_characters()`/`_restore_characters()`. Every work loop's tick-wait (`_run_generic_work_loop`, `_run_construction_loop`, `_run_training_loop`, `_run_farm_loop`, `_run_lumberjack_loop`'s chop wait) now goes through a shared `Character._wait_for_tick(interval)` helper instead of a bare `await get_tree().create_timer(interval).timeout`: if `_tick_remaining` is already set (only true immediately after a restore), it waits that long instead of the full interval, then resumes normal cadence for every tick after.

Without this, every restored worker's loop started its very first wait fresh at the *full* interval, so an entire town of farmers/lumberjacks/etc. ended up perfectly resynced (all producing on the same tick) purely because they all happened to load at the same moment - something that never happens during continuous play, since each worker's loop naturally starts whenever they were individually assigned.

`_restore_characters()` sets `character._tick_remaining` *before* calling `assign_to()` - `assign_to()` synchronously starts the work loop, and several loop shapes reach their first `_wait_for_tick()` call before ever yielding back to the caller, so setting it any later would miss that first tick.

`_wait_for_tick()` decrements via a manual per-frame loop (`get_process_delta_time()`, same pattern `_move_to` already uses) rather than a parallel `_process()` callback, specifically so the countdown only ticks down while actually inside this wait - not during whatever haul/move detour a loop takes before reaching it. Also folds in the same `is_inside_tree()` departure-guard every other awaited tree signal in `character.gd` already has, so the 5 call sites got simpler (one line instead of a guard + bare timer wait) as a side effect.

**Verified:** scripted a worker assigned to a Stone Mine, let ~half its 6.0s work_interval elapse, read back `_tick_remaining` (~3.15s, as expected), then simulated a fresh restore (a new Character with that same `_tick_remaining` set before `assign_to()`) and confirmed its first production fired ~3.15s later - not a full fresh 6.0s - matching the saved countdown almost exactly.

**Known gap:** only the *production* tick is desynced this way - haul/stockpile-pause waits and movement aren't tracked, since those aren't what "swinging in sync" refers to and re-randomize naturally via normal pathing variance anyway.
