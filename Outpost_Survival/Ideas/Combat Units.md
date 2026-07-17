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

## Current stats

Implemented in `scripts/combat/combat_unit.gd` (`CombatUnit`), sandbox at `scenes/combat/CombatTest.tscn` (see [[Combat System]]). First-pass numbers, not tuned via playtesting. Swordsman was later split into Shieldbearer + Marauder. HP column already includes `HEALTH_MULTIPLIER` (4.0x, applied per-type rather than hand-doubling - see [[Combat System]]'s "HP multiplier" note); the design-intent HP ratios between types are a quarter of these numbers.

| Type | HP | Damage | Armor | Range | Attack interval | Move speed | Point cost |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Shieldbearer | 760 | 8 | 4 | 45 (melee) | 1.2s | 120 | 4877 |
| Marauder | 340 | 18 | 1 | 45 (melee) | 0.8s | 165 | 9474 |
| Archer | 280 | 16 | 0 | 260 | 1.2s | 170 | 3826 |
| Mage | 220 | 14 | 0 | 220 | 1.5s | 140 | 1597 |
| Outrider | 320 | 10 | 0 | 45 (melee) | 0.8s | 200 | 3707 |
| Trapper | 400 | 9 | 0 | 60 (melee) | 1.1s | 130 | 2322 |

**Armor** (`ARMOR`, `scripts/combat/combat_unit.gd`) is a flat, subtractive defense stat, separate from the percent `DAMAGE_MULTIPLIERS` table below - see Changelog (2026-07-16, "Flat armor system added") for the full design and why only Shieldbearer/Marauder have any. Applied per hit as `max(1, (attacker_damage - defender_armor) * type_multiplier)` - armor subtracts first, from the attacker's already skill-scaled damage, before the type multiplier; a hit can never be reduced below 1 regardless of armor. Point cost above already includes armor's effect (only Shieldbearer/Marauder's costs moved from the pre-armor table).

**Damage taken** (row = defender, column = attacker; >1.0 weak, <1.0 resists):

| Defender ↓ / Attacker → | Shieldbearer | Marauder | Archer | Mage | Outrider | Trapper |
| --- | --- | --- | --- | --- | --- | --- |
| Shieldbearer | 1.0 | 1.0 | 0.4 | 1.7 | 1.0 | 1.0 |
| Marauder | 1.0 | 1.0 | 0.6 | 1.0 | 1.0 | 1.0 |
| Archer | 1.5 | 1.5 | 1.0 | 0.5 | 1.0 | 1.0 |
| Mage | 1.5 | 1.5 | 1.5 | 0.5 | 1.0 | 1.0 |
| Outrider | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| Trapper | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |

**Target preference** (row = attacker, column scores how much it prefers that defender type; blank = no preference, targets nearest):

| Attacker ↓ / Defender → | Shieldbearer | Marauder | Archer | Mage | Outrider | Trapper |
| --- | --- | --- | --- | --- | --- | --- |
| Shieldbearer | - | - | - | - | - | - |
| Marauder | - | - | - | - | - | - |
| Archer | 15 | 35 | 60 | 100 | 80 | 50 |
| Mage | 100 | 30 | 40 | 20 | 50 | 40 |
| Outrider | 5 | 10 | 100 | 60 | 20 | 30 |
| Trapper | 15 | 25 | 40 | 40 | 90 | 20 |

**Other per-unit numbers:**

| Type | Formation leash multiplier | Avoids melee? | Melee-avoid radius |
| --- | --- | --- | --- |
| Shieldbearer | 0.4 (tightest) | No | - |
| Marauder | 0.9 | No | - |
| Archer | 1.0 | Yes | 150px |
| Mage | 1.0 | Yes | 170px |
| Outrider | 2.0 (loosest) | No | - |
| Trapper | 1.0 | No | - |

- Trapper's attack applies a slow: 0.5x speed for 2s, refreshes rather than stacks.
- Mage's attack splashes 50% damage (each victim's own damage-taken multiplier applied individually) to every other living enemy within 90px of the primary target - see behavior notes below.
- Combat skill (`melee_combat`/`archery`/`spellcasting`, shared by role family) minorly scales all of a unit's stats: `1.0 + (level-1) * 0.005`, so level 99 is +49%. Sandbox-only mock levels for now; not wired to real citizens.

## Behavior notes

- **Kiting**: Archer/Mage evade any nearby Shieldbearer/Marauder within their melee-avoid radius, curving toward their own target rather than fleeing straight backward, so they don't get trapped running away from what they're trying to shoot. If evading would mean never reaching an unreachable target for 3+ seconds, they give up and fight whatever's blocking them instead.
- **Outrider flank/kite/dive**: treats any Shieldbearer/Marauder/Trapper within 220px as a "blocker" to route around rather than fight - kites away from it (blending retreat, progress toward its real target, and avoidance of enemy ranged units) until that blocker has drifted 260px from its own Formation slot, then commits to the dive. Gives up waiting after 4s and commits anyway, then ignores blockers for 3s. Enter/exit thresholds are asymmetric (330px to stop kiting vs. 220px to start, same 1.5x split Archer/Mage's own melee-avoid hysteresis uses) - a single shared threshold let an Outrider whose retreat only partially outpaces its blocker flicker between kiting and committing every time it crossed back and forth across one line. With no melee blocker nearby, a live enemy Archer/Mage still close enough to actually be shooting it (attack range + a proactive margin, same enter/exit split) triggers the same kiting behavior on its own now too - previously an Outrider reverted to a blind pathfind beeline the instant no melee blocker was in the way, with zero awareness of ranged fire, letting it "flank" straight through/linger inside an enemy Archer's attack range untouched by any evasive response. See [[Combat System]] for the full diagnosis and verification.
- **Mage hold-back**: retreats toward its Formation slot instead of advancing whenever a live Archer is within 320px and no closer melee threat is forcing a fight - Mage can't outrun an Archer (140 vs 170 speed), so its only real defense is not walking into range in the first place. Resolves once archers are dead, far away, or a melee unit gets close enough to force the issue.
- **Mage AoE splash**: every Mage hit also deals 50% damage to any other living enemy within 90px of the primary target's position (not the caster's own position) - a purple expanding ring marks the blast radius. Each splash victim's damage uses *its own* row of the damage-taken table against Mage, not the primary target's, so a Marauder caught in the splash off a Shieldbearer target still only takes its own neutral (1.0x) share, not Shieldbearer's 1.7x. 90px sits in the middle of enemy Formation presets' own row_spacing range (70-110px), so a Mage naturally punishes a tightly packed enemy line without needing a separately-tuned radius.
- **Line of sight**: Archer/Mage attacks are blocked if any other living unit (ally or enemy) sits within 34px of the straight line to the target. A blocked shot is withheld; if still out of range the attacker keeps approaching, but once in range it holds position and waits for a clear shot instead of advancing further into the clash. Gives up and retargets after 2.5s stuck on the same blocked target.
- **Morale & routing** (all types equally): morale drops from a unit's own wounds and nearby ally deaths, eases toward its target rather than snapping. Below 45, a unit breaks - becomes untargetable and flees the map, escaping (surviving) after 5s. If half a team is dead-or-routing at once, everyone left breaks together. See [[Combat System]] for the full mechanic, constants, and retuning history.
- **Guarding**: a Trapper with a ward stands between it and whichever enemy is nearest to it, not a fixed offset - and periodically reconsiders its own target (not just its ward) so it doesn't stay locked onto a distant chase while a different threat reaches its ward unguarded. See [[Combat System]] for the full mechanic.
- **Formation cohesion** (all types equally): while still just approaching (not yet holding position, fleeing, kiting, holding back, or routing), a unit's speed is capped to the slowest currently-approaching teammate's pace, so a formation advances together rather than fast units leaving a slow one behind. Released the moment a unit commits to any of those other behaviors. See [[Combat System]] for the full mechanic.
- Outrider/Trapper never flee melee - both are melee-range themselves, so evading would mean never landing a hit.
- Not implemented: Swordsman-era "block other melee units" / "push ranged units" (no group positioning or knockback yet).

## Point-cost formula

`point_cost()` estimates a unit's overall value for authoring comparable test rosters. Originally just `health × damage/attack_interval`; reworked after that formula let `archer_core_vs_melee_rush` reach "point parity" while still being a 10/10 rout (see [[Combat System]]).

The new formula multiplies that base by four factors, each derived automatically from `STATS`/`DAMAGE_MULTIPLIERS`/`TYPE_PREFERENCE` (not hand-tuned per unit):

| Factor | What it rewards |
| --- | --- |
| Range | attack_range beyond melee reach (45px baseline) |
| Mobility | move_speed relative to the six-type average |
| Armor | flat `ARMOR` value relative to the six-type average raw damage (12.5) |
| Avg. offense/defense | this type's average `DAMAGE_MULTIPLIERS` dealt/taken across all six types |
| Focus-fire exposure | discount for types that draw high `TYPE_PREFERENCE` as a target (killed before their raw stats matter) |

See the "current stats" table above for resulting costs. Known gaps: no term for abilities with no STATS representation (Trapper's slow and Mage's AoE splash are the current examples) - flagged, not faked with a hand-picked bonus; and `MATCHUPS` rosters (below) were tuned for parity *before* armor existed, so Shieldbearer/Marauder-heavy rosters' documented near-parity is stale until a fresh verification pass re-checks win rates.

## Deferred / open items

- Real citizen integration is now fully wired end to end (see Changelog: both the 2026-07-16 town-side entry and the 2026-07-16 battle-deployment entry below) - a citizen assigned to a TrainingGround deploys with their real trained skill level via the HUD's "Simulate Attack" button, fights in CombatTest.tscn, and the result (including permadeath on loss) flows back to Base. What's still open, now that the core pipeline works:
  - Melee archetype (Shieldbearer/Marauder/Outrider/Trapper) is assigned round-robin, not chosen - `melee_combat` alone can't disambiguate, and nothing on `CharacterData` tracks a sub-specialization. A real archetype-selection mechanic (per-TrainingGround choice, a new CharacterData field, etc.) is future work.
  - The enemy roster is a same-composition mirror of the defending squad (mock skill levels) - a placeholder, not a real raider-generation/scaling system. See Docs/roadmap.md's "raids/sieges" long-term item.
  - The attack trigger itself is a manual debug button, not tied to any in-world threat, timer, or AI.
- Title-threshold unit upgrades (Apprentice→Legendary crossing a threshold swaps a unit into a stronger form, not just bigger numbers) - explicitly a future idea, not started.
- Swordsman-era "block other melee units" / "push ranged units" behaviors.
- `LOS_BLOCK_RADIUS` (34px) tuning - live-play feedback needed. Headless testing shows it blocking 73% of Archer shots in `archer_core_vs_melee_rush`; unclear if that reads as "satisfying cover" or "units can barely fire" without playtesting.
- Player-facing formation-choice UI (data/logic already supports it, no UI built).

## Changelog

- **2026-07-16 - Flat armor system added**, per an explicit request for armor "separate from the percent counter bonuses" `DAMAGE_MULTIPLIERS` already provides. New `ARMOR` const dict (`combat_unit.gd`) - a flat amount subtracted from the attacker's already skill-scaled damage *before* `DAMAGE_MULTIPLIERS` is applied to what's left (not after, which would let a strong resistance compound with armor toward zero and make armor least relevant exactly where a type is already weak - e.g. Shieldbearer's Archer resistance). A new `MIN_DAMAGE` floor (1.0, the classic AoE2 `max(1, ...)` rule) keeps a hit from ever being fully negated. Values are grounded in fluff already in this file rather than picked fresh: Shieldbearer (4) and Marauder (1) are the only two types with any armor, matching their existing "thicker armor"/"light gear" STATS comments; Archer/Mage/Outrider/Trapper stay at 0 since their own STATS comments already assert "no defensive edge"/"no resistances" - giving them armor would have contradicted text already in the file. Applied in both `_attack()` (primary hit) and `_splash_damage()` (Mage AoE), so armor isn't bypassable via splash. `point_cost()` extended with an `armor_multiplier` term (armor priced relative to the six-type average raw damage, 12.5, the same way `mobility_multiplier` already prices move_speed against the roster average) - only Shieldbearer (3694→4877) and Marauder (8772→9474) moved. Verified via a temporary headless autoload printing every matchup's mitigated damage and every type's point cost: no negative/NaN values, the floor never triggered on any of the 36 attacker/defender pairs at base stats, and Shieldbearer's Mage weakness still hits hard (14 dmg → 17 after 1.7x, armor barely dents a hit that strong) while Archer's countered hit against Shieldbearer is meaningfully softened (16 → 4.8) without going to zero. Known gap, not fixed in this pass: `MATCHUPS` rosters below were tuned for point-cost parity before armor existed, so their documented win-rate parity is stale until re-verified - flagged in the point-cost formula section above rather than silently re-tuned.
- **2026-07-16 - Barracks/Archery Range/Mage Tower added (town-side citizen→soldier conversion).** `TrainingGround` (`scripts/training_ground.gd`) extends `Workstation` the same way `Workshop` does for Mill/Bakery/Brewery - one class, three `BuildingCatalog` entries distinguished only by `skill_id`, no input/output at all (training isn't a resource conversion). `Character._run_training_loop` grants flat per-tick xp toward the post's skill, same "reward time worked" principle as every other work loop, but never completes (unlike `_run_construction_loop`, which it's otherwise shaped like). `melee_combat`/`archery`/`spellcasting` added to `SkillTitles.TITLE_SKILLS` (job nouns Soldier/Archer/Mage) and `SkillPanel.SKILL_DISPLAY_ORDER`, so trained combat levels show up in the title and skill panel like any job skill, and `Base._job_posts()`/`_run_job_assignment` auto-staff these buildings for free (being in `TITLE_SKILLS` is what makes a post eligible for assignment at all). Reuses `iso_workstation_workshop.svg` (tinted per building) rather than blocking on bespoke art. Deliberately did **not** touch `CombatTestManager`'s mock skill levels yet in this pass - see the 2026-07-16 battle-deployment entry below for where that got wired up.
- **2026-07-16 - Battle deployment: town ↔ CombatTest bridge added.** The other half of citizen→soldier integration - see Deferred/open items above for what's still a placeholder. New `BattleState` autoload (`autoload/battle_state.gd`) hands data across the `change_scene_to_file` boundary the same way `SaveManager.should_load_on_start` already does for Base's own boot-load path: `pending_squad` (citizen id/unit_type/skill_level per deploying soldier), `town_blob` (Base's full state, captured *in memory* via a new `Base._serialize_state()`/`_apply_state()` split rather than written through `SaveManager` - deploying used to be tempting to implement as "just save to the active slot," which would have silently clobbered the player's real save), and `result` (outcome + casualty ids, written by `CombatTestManager`). HUD's new "Simulate Attack" button (`Base._on_attack_pressed`) gathers every citizen whose `assigned_post is TrainingGround`, disambiguates `melee_combat` into a concrete archetype round-robin (`Base.MELEE_ARCHETYPES` - see Deferred items), and hands off to `CombatTest.tscn`. `CombatTestManager._spawn_battle()` branches on `BattleState.active`: real squad data replaces `MATCHUPS`/the mock `randi_range` roll for team A (a mirrored roster still fills team B), a new `CombatUnit.citizen_id` field lets a death be traced back to a real citizen, and casualties are accumulated from the `died` signal as the battle runs (not read from `team_a`'s contents at the end - team_a/team_b over-count survivors for several seconds after a mass-rout decides the result, since routing units are still "in" the array until they finish fleeing). M-cycling is disabled in this mode (nothing to cycle - the roster came from the town); Esc returns to Base with the casualty report instead of the main menu. Back in Base, `_apply_battle_result` removes each casualty via the exact same cleanup a happiness-driven departure already uses (`_character_leaves`) - a battle death isn't mechanically different from any other permanent loss. Verified end-to-end with a headless driver (temporary autoload, since `change_scene_to_file` frees whatever else was watching), in two passes: an initial pass confirmed the data plumbing (deployed unit carries a citizen's real trained level - 5000 melee_combat xp → level 20 landed on the spawned `CombatUnit` unmodified, not a mock roll - and a forced result correctly removed the citizen from Base's roster). A second pass let a real 1v1 battle actually resolve on its own (`_check_empty_teams`/`_declare_result` firing from genuine `died`/`escaped` signals, not asserted by hand) and fed a real `InputEventKey(Escape)` through `_unhandled_input` - which surfaced a real bug this integration would otherwise have inherited silently: `if event is InputEventKey and event.pressed: ... elif event.is_action_pressed("ui_cancel")` meant Escape's own keydown event always matched the first branch (an `InputEventKey` with `pressed == true`, unconditionally, before the R/M/+/- keycode checks even look at *which* key), so the `elif` checking `ui_cancel` could never run - **Esc-to-main-menu was already dead code in the free-play sandbox before this session**, not something this change broke. Fixed by checking `is_action_pressed("ui_cancel")` first and unconditionally, falling through to the R/M/+/- keycode checks only if it wasn't Escape. Re-verified after the fix: natural win, zero casualties (soldier survived), real Esc keypress correctly returned to Base with `BattleState` fully cleared and population unchanged. The standalone F6/main-menu sandbox was re-verified unaffected by both the deployment feature and the bugfix (`BattleState.active` defaults false).
- **2026-07-15 - Outrider + Trapper added.** Answers a kiting Archer/Mage that a slower melee unit could never catch. Outrider: pure speed counter, no bonuses. Trapper: crowd control via the slow debuff, not stats. `fast_movers` matchup (Outrider-heavy vs Trapper-heavy) exposed that Trapper isn't meant to solo-duel Outrider - it's a support unit; `support_vs_outrider` (Trapper+Archer vs pure Outrider) is the intended pairing and wins decisively as designed.
- **2026-07-15 - Swordsman split into Shieldbearer + Marauder.** Shieldbearer: tank, holds the line, resists Archer best, worst Mage weakness (heavy armor conducts magic). Marauder: glass cannon, highest damage/attack speed, resists Archer less, neutral to Mage (light armor doesn't conduct). All matchup rosters rebalanced around the new point costs.
- **2026-07-15 - Citizen combat-skill augmentation (sandbox prototype).** See stats table/behavior notes above.
- **2026-07-15 - Point-cost formula reworked** after `archer_core_vs_melee_rush` verified as a 10/10 rout despite old-formula parity. Rebuilding that roster to match headcount and add a Mage counter to Shieldbearer's weakness still lost 10/10 - Archer's #1 target preference is Mage, so it walked into Archer's best matchup instead. See below.
- **2026-07-15 - Outrider flank/kite/dive AI + Mage hold-back added**, still didn't flip `archer_core_vs_melee_rush` (0/5 post-fix) - delays deaths but doesn't prevent them, since there's no cover system yet.
- **2026-07-15 - Line-of-sight/cover system added.** Still 10/10 for Archer Core, but Team A's survivor count dropped from a near-untouched 6-7/7 to 5-7/7 - cover is doing real work, just not enough alone to flip a roster that's also outnumbered and hard-countered by type. See [[Combat System]] for the full diagnosis chain.
- **2026-07-15 - Morale/routing + HP doubling added**, per an explicit request to make battles less lethal for invested citizens. All 12 test battles (6 matchups × 2 runs) ended via rout instead of a wipe-out. See [[Combat System]] for the full mechanic.
- **2026-07-15 - Battle speed control added** (+/-, 0.5x-16x) - playtesting/verification convenience. See [[Combat System]].
- **2026-07-15 - Morale retuned + HP raised to 4x** after playtesting feedback (individual routs should visibly happen before death more often; survivability doubled again). Death rate 26.1%→4.7%, escape rate 29.5%→52.6% across 18 verified battles. See [[Combat System]] for the full before/after.
- **2026-07-16 - Archers charging into melee, fixed.** A ranged unit whose shot was blocked (see line of sight, above) but already in range used to keep closing distance anyway, same as if it were genuinely out of range - dragging archers into the front-line clash. Now holds and waits once in range, with a 2.5s give-up timer to avoid stalling forever on a stationary blocker. See [[Combat System]] for the full fix.
- **2026-07-16 - Guards positioned between ward and threat.** Per an explicit request. Fixed in two parts - a dynamic threat-facing leash offset (small effect alone), and periodic retargeting so a guarding Trapper stops chasing an uncatchable target while a different enemy reaches its ward unguarded (the real fix). Alignment went from 18-51% to a stable 62-70% in verification. See [[Combat System]] for the full mechanic.
- **2026-07-16 - Shieldbearers stuck behind archers in the balanced matchup, fixed.** `StrategistAI` was sending both mirror-matchup teams' Shieldbearers to the back rank at once (reusing "Guard," designed to hide a Shieldbearer from an enemy Mage, for a trigger that had no reason to retreat our own tank). New "Press" preset (everyone forward, tank stays in front) replaces Guard for the Shieldbearer/Trapper-dominant triggers. See [[Combat System]] for the full diagnosis.
- **2026-07-16 - Melee units curving toward their target, fixed.** The formation leash pull's weight scaled linearly with drift distance, so even a unit well inside its leash range was constantly blending in a real pull toward its slot, visibly bending otherwise-straight approaches. Now scales with the squared fraction instead - negligible until a unit has drifted a real distance, same full-strength pull near the actual leash range. See [[Combat System]] for the full fix.
- **2026-07-16 - Formation cohesion added.** Per an explicit request. Units now advance at their slowest still-approaching teammate's pace until individually released by engaging. Real behavior change worth noting: measurably slows Outrider's approach in mixed-speed rosters until it's kiting a blocker or close enough to engage on its own - intentional, but a departure from its previous always-full-speed approach identity. See [[Combat System]] for the full mechanic and verification.
- **2026-07-16 - Curving still visible after the squaring fix, second pass.** Not an isometric-rendering illusion - confirmed the sandbox never transforms unit positions through the iso projection, and a headless straightness trace found real remaining curvature, worst for Shieldbearer (7-8% chord deviation) specifically because its leash range is so tight. Added a dead zone (no pull at all below 50% of a role's own leash range) on top of the existing squared falloff - Shieldbearer's deviation dropped to a consistent ~1.7%. See [[Combat System]] for the full diagnosis.
- **2026-07-16 - "Press" Shieldbearers running out of position, fixed.** The single-rank version of Press (from the earlier Shieldbearer-stuck-behind-archers fix) crammed an entire roster into one 450px-wide line, leaving units at the extreme ends with a formation slot nowhere near the real fighting - and, unnoticed, pulled Outrider to the front too (no second rank left for it to default to). Split back into two ranks - melee at 380, ranged pulled up to 420 instead of Line's 520 - keeping the "bring ranged units closer" intent without the overwide single row. Max Shieldbearer drift from slot dropped from up to 288px back to a normal 64-175px range. See [[Combat System]] for the full diagnosis and the updated preset table.
- **2026-07-16 - Runaway melee units, fixed.** Reported as a long-standing, stalling issue: units "drifting apart from the formation and leading each other on wild goose chases." Two compounding bugs in `Formation._living_centroid()` - a missing exclusion for units simply chasing a far-away/evasive target (not just the four special evasive states already excluded), and a hard-snap anchor position that could teleport up to 73,436 units/second when the small "steady" unit set churned membership frame to frame, instantly relocating every unit's leash center at once. Fixed with a fifth exclusion flag plus a rate-limited anchor. See [[Combat System]] for the full root-cause diagnosis and before/after numbers.
- **2026-07-16 - Outrider flanking hysteresis + free damage from archers, fixed.** Reported alongside the runaway-units bug above. The melee-blocker "safe to commit" check used one shared threshold for entering and exiting kiting, letting an Outrider flicker between the two near the boundary; and ranged-threat avoidance only ever ran while already kiting a melee blocker, so an Outrider with no melee blocker nearby beelined blind through enemy Archer range with zero evasive response. Fixed with the same enter/exit hysteresis Archer/Mage's own melee-avoid already uses, and by having ranged exposure alone (no melee blocker needed) trigger the same kiting behavior. Verified: kite-state flip-flops per battle dropped 9-15x (246/1246/844 → 28/84/38 across the three Outrider-heavy matchups). See [[Combat System]] for the full diagnosis.
- **2026-07-16 - Mage AoE splash added.** Per an explicit request ("area of effect attacks for mages") - Mage's attack now also deals 50% damage to other living enemies within 90px of the primary target, each scaled by that victim's own damage-taken multiplier rather than the primary target's, plus a purple expanding-ring visual so the blast is actually visible. Previously Archer and Mage were mechanically identical shapes ("ranged, avoids melee, kites Shieldbearer/Marauder") differentiated only by raw numbers; this is Mage's first real *mechanical* identity - punishing clustered enemy formations over several hits rather than one-shotting a group outright. Not yet priced into `point_cost()` (same "known, deliberately-unfixed gap" as Trapper's slow - flagged there, not faked with a hand-picked bonus) and the `mage_heavy` matchup's win-rate notes in `combat_test_manager.gd` predate this change and haven't been re-verified against it. Verified via a headless run of `mage_heavy`: splash reliably lands (20+ splash hits across one battle) with no script errors introduced.
