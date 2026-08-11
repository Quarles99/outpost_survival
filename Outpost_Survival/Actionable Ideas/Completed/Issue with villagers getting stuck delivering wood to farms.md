- Walking to deposit wood they get stuck on the farmer and cannot make the delivery but continue to walk into the farmer

## Completion write-up (2026-07-25)

**Root cause:** commit `c1fc7cf` ("Add citizen-vs-citizen movement avoidance
(RVO)") made every citizen an 18px RVO avoidance agent, enforcing ~36px of
separation between any two citizens. A hauler's delivery target
(`post.get_worker_spot()`) is the *exact same point* the assigned worker
stands on, but arrival was judged solely by `nav_agent.is_navigation_finished()`,
which uses the engine's default 10px tolerance - unreachable once the target
is occupied by another 18px agent. The hauler re-aimed at the spot every frame,
got pushed back by RVO, and re-aimed again - reading as "walking into" the
farmer - until the existing 60s `MOVE_HANG_SAFETY_SECONDS` hatch fired,
completed the delivery as if arrival had happened, and the whole cycle
restarted on the next haul trip.

**What was built** (`scripts/character.gd`, `_move_to()` and `_ready()`):
1. `nav_agent.set_velocity(Vector2.ZERO)` on every `_move_to` exit path
   (normal/hang-hatch completion and the `is_inside_tree()` bail) - previously
   only ever set while moving, never cleared, so a citizen who'd stopped kept
   advertising motion to the RVO sim and took none of the reciprocal avoidance
   burden.
2. New `ARRIVE_TOLERANCE := 44.0` constant (2x `AVOIDANCE_RADIUS` + an 8px
   margin) - `_move_to`'s loop now also breaks once within this distance of
   the target, alongside `is_navigation_finished()`. This is the actual fix:
   it gives the loop a real way to end when the target is occupied, instead of
   waiting out the 60s hatch every single trip.
3. `nav_agent.max_speed = MAX_NAV_SPEED` (350.0) set in `_ready()` - previously
   unset, so the engine default (100.0) was silently clamping the real
   ceiling (`MOVE_SPEED(100) * a maxed speed skill's 2.96x * the dirt-path
   bonus's 1.15x` ~= 340.4). The speed-skill and dirt-path bonuses were
   partially a no-op before this.
4. `_move_to` now returns `bool` (`true` on genuine arrival, `false` if the
   hang-hatch fired) instead of `void` - groundwork for the
   [[Stuck-worker failsafe]] note, not acted on by any caller yet.

**Key files:** `scripts/character.gd` only, per the plan - no new drop-off
`Marker2D` nodes were added to post scenes (considered, rejected as more
invasive for the same outcome).

**The `ARRIVE_TOLERANCE` number (44.0) was derived from documented reasoning,
not tuned by live observation** - two 18px avoidance agents can't enforce
closer than 36px apart, so 44.0 (36 + an 8px margin) is the smallest value
guaranteed reachable, with headroom. The plan asked for this to be confirmed
or adjusted by watching it in-game; that observation step was **not** done
this session (see verification note below), so if citizens are ever seen
stopping visibly short of buildings, lower it toward 40 and re-check.

**Verification done:** headless `--quit` parse check only (clean). Interactive
in-game verification (watching a hauler deliver to an occupied Farm WorkSpot,
checking for the absence of the tell-tale over-worn dirt-path blotch, placing
a multi-builder construction site) was **not** done this session - the game
window came up on the user's live desktop alongside unrelated running
applications, and the user opted to verify manually rather than have this
session drive simulated mouse/keyboard input on a shared desktop. Please
verify: a hauler delivering to a Farm whose worker is standing on the WorkSpot
completes promptly (no ~60s stall, no dark over-worn patch next to the
farmer), and 2+ builders on one construction site no longer overlap.

**Known gaps:**
- The documented multi-worker-stacking gap (`character.gd`'s own doc comment
  conceding citizens sharing one WorkSpot "can still visually stack once
  arrived") should be reduced by change 2 above - multiple citizens converging
  on the same point now each stop ~44px+ out via RVO rather than all landing
  exactly on top of each other - but this is a plausible side effect, not
  something confirmed by observation this session.
- If a villager is ever seen hanging indefinitely with no eventual delivery
  (as opposed to the ~60s cyclic stall this fix addresses), that's a different
  mechanism - most likely a genuine navmesh hole (see `base.gd:609-618`'s
  existing handling of that case) - and needs its own investigation rather
  than more tolerance.