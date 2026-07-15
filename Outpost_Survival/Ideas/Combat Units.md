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

Implemented in `scripts/combat/combat_unit.gd` (`CombatUnit`) for the standalone sandbox at `scenes/combat/CombatTest.tscn` - see [[Combat System]] for the scene-level writeup. First-pass numbers, not tuned via playtesting:

| Type | HP | Damage | Range | Attack interval | Move speed |
|---|---|---|---|---|---|
| Swordsman | 120 | 12 | 45 (melee) | 1.0s | 90 |
| Archer | 70 | 16 | 260 | 1.2s | 100 |
| Mage | 55 | 14 | 220 | 1.5s | 85 |

Resistance/weakness pairs implemented as a defender-type x attacker-type damage multiplier (0.5x resistant, 1.0x neutral, 1.5x weak) - covers every stated pair (Swordsman resistant to Archer/weak to Mage, Archer resistant to Mage/weak to Swordsman, Mage weak to both). Target priority per type is implemented as a fallback-ordered list (first non-empty tier of "still-alive enemies of that type" wins, else nearest of anything); Swordsman has no stated priority so it always targets nearest. "Avoid melee combat" is implemented as kiting: an Archer/Mage evades whenever a Swordsman is within its own avoid-radius (150/170px).

**Kiting fix (2026-07-15):** originally "avoid melee combat" fled straight backward away from the threatening Swordsman and skipped attacking entirely that tick. Reported issue: this could run an Archer/Mage straight away from its own priority target as easily as toward it (whenever the threat happened to sit between the two), effectively trapping ranged units unable to ever close in on what they were trying to shoot. There's no pathfinding/navmesh in this project, so `CombatUnit._kite_direction()` approximates routing around the threat with a steering blend instead: it still gains distance from the threat (the radial "away" component) but curves along whichever tangent swings back toward the current target, rather than a straight line directly opposite it. Attacking was also decoupled from the movement branch entirely, so a kiting unit still fires (hit-and-run) if its target happens to be in range that tick, instead of every retreating tick costing it all its damage output. Verified via a temporary attack-logging instrumentation pass (removed after use): Archers landed their first hits around t=8s after closing in from the back rank, and kept landing hits steadily through the rest of a full battle (23 Archer + 10 Mage hits total in one run) rather than getting stuck evading indefinitely.

Not implemented: Swordsman's "block other melee units" / "push ranged units" behaviors - no group positioning or knockback yet, see [[Combat System]]'s prototype note for the full list of deferred behavior.