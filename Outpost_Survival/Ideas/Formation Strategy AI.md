# Formation Strategy AI

Deferred out of [[Formation System (Combat Sandbox)]]'s Phase 1 (2026-07-15) - captured here so the larger vision isn't lost while that pass only builds the base `Formation` entity.

The end vision, in the user's own words across that design conversation:

- Formations as a real strategic axis - a player could choose which formation they believe is most advantageous for their fighters (not just one fixed "Line" layout).
- Kiting (and other unit-behavior tactics) as a property *of the formation*, not a fixed per-unit-type stat - a formation could call for aggressive kiting, or for units to hold ground and not evade at all.
- Kiting-as-tactic is really one instance of a broader idea: formation *strategies* as a whole (spatial layout + behavioral tactics together) chosen dynamically by a macro-level strategist AI, not picked once by the player and left static - the AI would presumably swap formations/tactics in response to how a battle is actually going.

## What Phase 1 already sets up for this

`Formation` (scripts/combat/formation.gd) has a `tactics: Dictionary` field, copied from its `FormationCatalog` preset, not read by anything yet. The intended future read site is `CombatUnit._nearest_melee_threat()`'s `melee_avoid_radius` lookup - `formation.tactics.get("melee_avoid_radius", STATS[unit_type]["melee_avoid_radius"])`, falling back to the unit type's own default. `FormationCatalog` already mirrors this codebase's established catalog convention (`BuildingCatalog`/`RecruitCatalog` - static `RefCounted`, `OPTIONS` array of `{id, ...}` dicts, `get_option(id)`), so adding more named presets later is data, not a rewrite.

## Not designed yet

- What the "macro-level strategist AI" actually is - a per-tick evaluator on `CombatTestManager`? Something that reads battle state (relative HP, unit counts, positioning) and swaps `Formation.tactics`/preset mid-battle? Undesigned.
- Whether formation switching mid-battle is instant or itself takes time/has a cost (a real formation reorganizing wouldn't be instant).
- The player-facing formation-choice UI - `BuildMenu`/`RecruitPanel`'s signal-based option-picker pattern is confirmed reusable (see [[Formation System (Combat Sandbox)]]) but no panel exists yet.
