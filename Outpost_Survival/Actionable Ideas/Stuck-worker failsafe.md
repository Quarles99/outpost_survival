Requested directly in chat: "Implement a fail safe if a worker has been stuck on the same job without progress for too long." Not started yet - research done, findings below so a future session doesn't have to re-derive them.

## What already exists

`Character._move_to()` has a **per-call** escape hatch: `MOVE_HANG_SAFETY_SECONDS := 60.0` stops an individual navigation attempt from awaiting forever if `is_navigation_finished()` never becomes true. It does NOT recover the citizen or signal failure to the caller - the loop just falls through as if arrival happened (`_move_to()` returns normally either way), so a work loop calling `_move_to()` again next iteration toward the same unreachable point silently repeats the 60s stall forever. This is the actual gap: no cross-iteration "I've been stuck on this for N total minutes" tracking exists anywhere in `character.gd`.

`assign_to(post)` (character.gd:414) is the existing clean recovery mechanism - already proven for an analogous case (`flee_home_from_raid()` interrupts work mid-task, `Base._on_day_started` calls `assign_to(assigned_post)` again next dawn to resume). A failsafe's recovery action should just call `assign_to(assigned_post)` (retry in place) or `assign_to(null)` (drop into hauling instead) once triggered - no new recovery machinery needed.

## Per-loop stuck risk (character.gd)

| Loop | Existing fallback | Real risk |
|---|---|---|
| `_run_farm_loop` | Yes - `_assist_haul_or_wait` when input is short | Only if NO haul job exists anywhere - cycles Idle/Hauling forever without settling on one `current_task` string (wouldn't trip a naive same-string-for-N-seconds detector) |
| `_run_lumberjack_loop` | Yes - same `_assist_haul_or_wait` fallback when no tree in range | Same shape as Farm |
| `_run_generic_work_loop` (StoneMine) | **No fallback at all** | If the post's worker spot or nearest stockpile becomes unreachable mid-game, every haul trip eats a 60s `_move_to` stall forever, `current_task` genuinely pinned on `"Hauling %s"` the whole time |
| `_run_construction_loop` | N/A (only assigned once materials_ready) | Not a hang risk itself |
| `_run_training_loop` | N/A by design (never completes) | Not a bug scenario - a failsafe must NOT flag indefinite `"Training"` as stuck |
| `_run_hauler_loop` (idle/unassigned) | Legitimate idling (`"Idle"`, retries every 2.5s) is fine | Real risk: a *found* job whose target becomes unreachable - `_find_haul_job()`'s scoring is deterministic given unchanged buffers, so it keeps re-picking the same job, `current_task` stays pinned (e.g. `"Delivering Wood"`) while repeatedly eating 60s stalls forever |
| `_run_demolish_harvest` (Demolish Mode, new) | No fallback for an unreachable target | Same risk via its two `_move_to` calls, `current_task` pinned on `"Demolishing (%s)"` |

**Net finding**: the two scenarios the user's phrasing most obviously describes (Farm with no wood anywhere, LumberCamp with no reachable tree) already cycle rather than truly hang via `_assist_haul_or_wait` - though that cycling can still be permanently non-productive, so may still be worth catching. The loops with zero fallback and genuine risk of `current_task` staying pinned on one exact string forever are `_run_generic_work_loop`, `_run_hauler_loop`'s job execution, and `_run_demolish_harvest`.

## Existing pattern to model the detector on

No "accumulate stuck-time, decay on progress, give up past a threshold" pattern exists in `character.gd` yet, but `scripts/combat/combat_unit.gd` already has exactly this shape twice - not directly reusable code (different class/domain), but the right design template:
- `CHASE_STALL_GIVE_UP`/`_DECAY`/`_PROGRESS_EPSILON` (combat_unit.gd:375) - tracks `_chase_last_dist` frame-to-frame, accumulates stall time when distance-closed-per-frame falls below an epsilon, decays when progress resumes, gives up past a threshold.
- `THREAT_STRUGGLE_GIVE_UP`/`_DECAY` (combat_unit.gd:361) - same shape, different trigger condition.

## Open question to resolve before implementing

What counts as "progress" per loop differs (resource output for Farm/LumberCamp/StoneMine vs. distance-to-target for a haul trip vs. labor_completed for construction) - a single generic "same `current_task` string for N seconds" check would misfire on `_run_training_loop`'s intentionally-infinite state and under-trigger on Farm/LumberCamp's alternating-but-still-unproductive Idle/Hauling cycle. Worth deciding whether this is one shared generic mechanism (e.g. track a per-citizen "last time any resource/labor counter it touches actually changed") or several loop-specific checks before writing code.
