# Formation Strategy AI

Deferred out of the Formation entity's Phase 1 (2026-07-15, see [[Combat System]]'s dated changelog) - captured here so the larger vision wasn't lost while that pass only built the base `Formation` entity. Most of it was then built the same day - see the "Strategist AI + asymmetric matchups" entry in [[Combat System]] for the actual implementation writeup.

The end vision, in the user's own words across the original design conversation:

- Formations as a real strategic axis - a player could choose which formation they believe is most advantageous for their fighters (not just one fixed "Line" layout). **Built**: 4 presets now exist (Line/Rush/Skirmish/Guard), each a genuine counter-pick, not just cosmetic variety.
- Kiting (and other unit-behavior tactics) as a property *of the formation*, not a fixed per-unit-type stat. **Built**: `Formation.tactics` is read by `CombatUnit._nearest_melee_threat()`.
- Formation *strategies* chosen dynamically by a macro-level strategist AI, swapping in response to how the battle is actually going, not picked once and left static. **Built**: `StrategistAI`, one per team, re-evaluates every 4s and can switch mid-battle.

## Still not built

- **Player-facing formation-choice UI** - the `BuildMenu`/`RecruitPanel` signal-based option-picker pattern is confirmed reusable, no panel exists yet. Right now formation choice is entirely AI-driven (rule-based counter-picking), never player-selected.
- **A general scoring/utility AI** - explicitly not chosen over rule-based counter-picking this pass (screened to the user, who picked rule-based for being explainable/debuggable). `StrategistAI`'s whole decision is "counter whatever enemy type has the most total living HP" - no broader battle-state modeling (own losses, positioning, momentum).
- Additional formation presets beyond the four here.
