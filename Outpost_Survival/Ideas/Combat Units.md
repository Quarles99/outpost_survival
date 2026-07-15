	- Swordsman
		- Melee
		- Tough
		- Resistant to archers
		- Weak to Mages
		- Behaviour
			- Block other melee units
			- Push ranged units
	- Archer
		- Ranged
		- High Damage
		- Resistant to Magic
		- Weak to Melee
		- Behaviours
			- Avoid melee combat
			- Target mages first
	- Mage
		- Ranged
		- Spells
		- Strong attack against Melee
		- Weak defenses to melee and ranged
		- Behaviours
			- Avoid melee combat
			- Target Swordsman first

## Prototype (2026-07-15)

Implemented in `scripts/combat/combat_unit.gd` (`CombatUnit`) for the standalone sandbox at `scenes/combat/CombatTest.tscn` - see [[Combat System]] for the scene-level writeup. First-pass numbers, not tuned via playtesting (current as of the Outrider/Trapper addition below - move speeds in particular were raised significantly from their original values partway through, see [[Combat System]]'s changelog):

| Type | HP | Damage | Range | Attack interval | Move speed |
|---|---|---|---|---|---|
| Swordsman | 120 | 12 | 45 (melee) | 1.0s | 150 |
| Archer | 70 | 16 | 260 | 1.2s | 170 |
| Mage | 55 | 14 | 220 | 1.5s | 140 |
| Outrider | 80 | 10 | 45 (melee) | 0.8s | 200 |
| Trapper | 100 | 9 | 60 (melee) | 1.1s | 130 |

Resistance/weakness pairs implemented as a defender-type x attacker-type damage multiplier (0.5x resistant, 1.0x neutral, 1.5x weak) - covers every stated pair (Swordsman resistant to Archer/weak to Mage, Archer resistant to Mage/weak to Swordsman, Mage weak to both). Outrider/Trapper are flat 1.0x in every direction, including against each other - both win through mobility/crowd-control instead of the damage triangle (see below), deliberately not a 4th/5th faction in it. Target priority per type is implemented as a fallback-ordered list (first non-empty tier of "still-alive enemies of that type" wins, else nearest of anything); Swordsman has no stated priority so it always targets nearest.

"Avoid melee combat" is implemented as kiting: an Archer/Mage evades whenever a Swordsman is within its own avoid-radius (150/170px). Outrider and Trapper both have `avoids_melee = false` despite being fragile-ish - both are melee-range themselves, so fleeing would just mean never landing a hit (the same "no safe firing zone" trap the Skirmish formation's melee_avoid_radius bug fell into, see [[Combat System]]) - their design leans into aggressively closing distance instead of evading.

## Outrider + Trapper (2026-07-15)

Added per an explicit request: the existing triangle had no answer to a kiting Archer/Mage outrunning a Swordsman forever (Archer at 170 speed vs. Swordsman's 150 - a straight-line race the Swordsman can never win). Proposed 3 design directions each for "a fast unit that can catch archers" and "a unit that counters fast movers," with concrete stat previews; the user picked the lowest-complexity option each time.

**Outrider** - pure mobility counter to kiting Archers/Mages. No bonus damage or resistances at all (flat 1.0x everywhere) - wins by simply being fast enough (200) to outrun both Archer (170) and Mage (140) outright. Fragile (80 HP) with no defensive edge, so it loses a straight fight if a Swordsman catches it instead. `target_priority = [Archer, Mage, Swordsman]`.

**Trapper** - counters fast movers via genuine crowd control, not stats: its attack applies a temporary move-speed debuff (`SLOW_MULTIPLIER` 0.5x for `SLOW_DURATION` 2s, overwrites rather than stacks on repeated hits) to whatever it hits, via a new `CombatUnit._speed_multiplier`/`_speed_debuff_timer` pair that ticks down in `_process()` and scales every context that reads move_speed (combat velocity, the formation-pull's return velocity, and `nav_agent.max_speed`, so a slowed unit is actually slower everywhere, not just some of them). `target_priority = [Outrider, Archer, Mage, Swordsman]` - negating a fast diver's whole advantage is the explicit point. Also flat 1.0x in every direction; its counter-play is entirely the debuff.

Both join `FormationCatalog`/`StrategistAI`: Trapper explicitly joins Swordsman at rank 0 (front) in every preset except Guard, since intercepting fast divers before they reach the back line is its whole job; Outrider is deliberately left unlisted everywhere (defaults to the back rank), starting safe and diving in aggressively per its own target_priority rather than starting already committed to a front-line brawl. `StrategistAI.COUNTER_PRESET` picks "rush" against an Outrider-dominant enemy (close distance fast, it's fragile and doesn't kite) and "guard" against a Trapper-dominant one (low melee_avoid_radius sidesteps the mobility-negation threat instead of walking into it) - reasoned, not yet deeply tested/tuned.

A new `CombatTestManager` matchup ("fast_movers", 4 Outrider/2 Archer vs 4 Trapper/2 Swordsman, roughly comparable `CombatUnit.point_cost` totals) exercises the pair directly. Verified headless: the slow debuff visibly applies and decays correctly (up to 4 units slowed simultaneously in one run, count decreasing over the following seconds matching the 2s duration), and the full 4-matchup suite (including the original 3v3 triangle matchups) resolves cleanly with no deadlocks or regressions (17-28s per battle).

**Balance observation, not a bug:** in repeat runs of `fast_movers`, Team A (Outrider-heavy) won every time, decisively (Outrider's DPS of 12.5 beats Trapper's 8.2 outright in straight melee, and Trapper's `target_priority` sends it straight at Outriders first - a solo-duel Trapper loses the exact matchup its name implies it should win). Flagged rather than silently rebalanced, since `fast_movers` was testing the wrong pairing: per explicit clarification, Trapper was never meant to solo-duel Outriders - it's a support unit that slows them down so Archers (which win the raw DPS race against Outrider - 13.33 vs 12.5, see the stat table above - even before Trapper helps) can finish them off. The matchup that actually needs to win is Trapper+Archer together vs. pure Outrider.

Added a second matchup, `support_vs_outrider` (3 Trapper/4 Archer, cost 6188, vs. 6 Outrider, cost 6000), to test exactly that. Verified headless across 5 runs: the support composition won every time, decisively and fast (12.5-13.75s, losing at most 1-2 of 7 units) - confirms the intended design actually works as described, not just in theory.

**Kiting fix (2026-07-15):** originally "avoid melee combat" fled straight backward away from the threatening Swordsman and skipped attacking entirely that tick. Reported issue: this could run an Archer/Mage straight away from its own priority target as easily as toward it (whenever the threat happened to sit between the two), effectively trapping ranged units unable to ever close in on what they were trying to shoot. There's no pathfinding/navmesh in this project, so `CombatUnit._kite_direction()` approximates routing around the threat with a steering blend instead: it still gains distance from the threat (the radial "away" component) but curves along whichever tangent swings back toward the current target, rather than a straight line directly opposite it. Attacking was also decoupled from the movement branch entirely, so a kiting unit still fires (hit-and-run) if its target happens to be in range that tick, instead of every retreating tick costing it all its damage output. Verified via a temporary attack-logging instrumentation pass (removed after use): Archers landed their first hits around t=8s after closing in from the back rank, and kept landing hits steadily through the rest of a full battle (23 Archer + 10 Mage hits total in one run) rather than getting stuck evading indefinitely.

Not implemented: Swordsman's "block other melee units" / "push ranged units" behaviors - no group positioning or knockback yet, see [[Combat System]]'s prototype note for the full list of deferred behavior.