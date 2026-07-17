extends Node2D
class_name CombatUnit

## Standalone combat-sandbox actor (see scenes/combat/CombatTest.tscn) - not
## wired into Character/the job-assignment system yet. Per Outpost_Survival/
## Ideas/Combat Units.md, the real design is citizens training a combat
## skill at a job post the same as any other trade; this class exists to
## prototype targeting/damage/kiting feel in isolation before that
## integration happens, so its stats/logic are expected to migrate into a
## Character work loop later rather than stay a separate class forever.

signal died(unit: CombatUnit)
## Fired when a routing unit successfully flees the battle - see _escape().
## Deliberately separate from died: an escaped unit survives (no death
## visuals, no floating damage text), it's just no longer part of this
## fight. CombatTestManager removes it from its team array exactly like a
## death, since either way the unit is no longer available to fight.
signal escaped(unit: CombatUnit)

enum UnitType { SHIELDBEARER, MARAUDER, ARCHER, MAGE, OUTRIDER, TRAPPER }
enum Team { A, B }

const TYPE_NAMES := {
	UnitType.SHIELDBEARER: "Shieldbearer",
	UnitType.MARAUDER: "Marauder",
	UnitType.ARCHER: "Archer",
	UnitType.MAGE: "Mage",
	UnitType.OUTRIDER: "Outrider",
	UnitType.TRAPPER: "Trapper",
}

## Which types count as a "melee threat" ranged units evade - see
## _nearest_melee_threat(). Both Shieldbearer and Marauder qualify (the
## Swordsman split, see Ideas/Combat Units.md); Outrider/Trapper are also
## melee-range but deliberately excluded (see their own STATS comments -
## both are built around aggressively closing distance, not evading, so
## they'd have nothing to fear from either even if they weren't).
const MELEE_THREAT_TYPES := [UnitType.SHIELDBEARER, UnitType.MARAUDER]

## Which combat skill each type trains - shared by role family rather than
## one skill per type (an explicit choice: mirrors the precedent where
## Mill/Bakery/Brewery were deliberately unified back into one "farming"
## skill rather than kept separate, see CLAUDE.md). All four melee-range
## types share "melee_combat" even though their formation roles differ a
## lot (Shieldbearer holds the line, Outrider dives) - they're all trained
## by the same kind of close-quarters practice. Not wired to a real skill
## yet - see skill_level/_skill_multiplier below for what this pass
## actually builds (a sandbox-only stand-in for a citizen's trained skill);
## the real version would be trained at a future Barracks building, the
## same way farming/lumberjacking/etc. are trained at their own posts - see
## Outpost_Survival/Ideas/Combat Units.md for the full deferred design.
const SKILL_ID := {
	UnitType.SHIELDBEARER: "melee_combat",
	UnitType.MARAUDER: "melee_combat",
	UnitType.OUTRIDER: "melee_combat",
	UnitType.TRAPPER: "melee_combat",
	UnitType.ARCHER: "archery",
	UnitType.MAGE: "spellcasting",
}

## Deliberately much smaller than SkillCurve.MULTIPLIER_PER_LEVEL (0.02,
## ~2.96x at max level for the real citizen job skills) - per an explicit
## request, a combat skill should only "minorly" increase stats, not
## snowball the way gathering output does. At MAX_LEVEL (99, reusing
## SkillCurve's own level range) this caps out around 1.49x; a more
## realistic early-game level (~30) is a genuinely minor ~1.15x.
const COMBAT_SKILL_MULTIPLIER_PER_LEVEL := 0.005

## Applied to every unit type's base "health" value below (not damage,
## speed, or anything else) - per an explicit request to make battles less
## lethal for what are, in the real game, invested/named citizens, not
## disposable stock. A flat multiplier on the one shared factor rather
## than hand-doubling six numbers keeps every type's *relative* HP (and
## therefore point_cost, itself proportional to health - see that
## function) exactly as designed; only the absolute numbers, and how long
## a battle takes to resolve, change. Raised from 2.0 to 4.0 (a further
## explicit "increase survivability by another factor of 2") alongside
## ROUT_MORALE_THRESHOLD/MORALE_WOUND_WEIGHT below - see those consts for
## why HP alone wasn't what needed retuning to reduce fatalities per
## battle.
const HEALTH_MULTIPLIER := 4.0

## First-pass stats, not tuned via playtesting - see Ideas/Combat Units.md
## for the qualitative traits these are meant to express (a tanky line-
## holder and a glass-cannon brawler split out of what used to be one
## generic Swordsman, a high-damage kiting archer, a fragile-but-punishing
## kiting mage). melee_avoid_radius is only read for units with
## avoids_melee = true - a nearby enemy Shieldbearer/Marauder inside that
## radius makes the unit retreat instead of attacking that tick (see
## _process). Outrider and Trapper both have avoids_melee = false despite
## being fragile-ish - both are melee-range themselves (can't attack at all
## without being in melee anyway, so fleeing would just mean never landing
## a hit - the exact "no safe firing zone" trap the Skirmish preset's
## melee_avoid_radius bug fell into for ranged units) and their whole
## design is built around aggressively closing distance, not evading.
const STATS := {
	## "Holds the line for as long as possible" - highest HP in the game,
	## lowest damage, slow, and the tightest formation leash (see
	## LEASH_MULTIPLIER) of anyone - deliberately doesn't wander even to
	## chase a kill. Thicker armor stops arrows better than a Marauder's
	## light gear (see DAMAGE_MULTIPLIERS), but that same heavy armor
	## conducts magic more effectively (like electricity) - the single most
	## magic-vulnerable unit in the game as a direct consequence.
	UnitType.SHIELDBEARER: {
		"health": 190.0 * HEALTH_MULTIPLIER, "damage": 8.0, "attack_range": 45.0,
		"attack_interval": 1.2, "move_speed": 120.0, "ranged": false,
		"avoids_melee": false, "melee_avoid_radius": 0.0,
	},
	## "Sacrifices durability for raw melee DPS" - lowest HP of any melee
	## type, highest damage and attack speed, fastest melee unit, and a
	## looser leash (still broadly holds a line, just less rigidly than
	## Shieldbearer). Light armor means it stops arrows worse than a
	## Shieldbearer, but doesn't conduct magic - the only melee-classed unit
	## with no bonus damage taken from Mage attacks at all (see
	## DAMAGE_MULTIPLIERS). Targets nearest, same as Shieldbearer - a
	## berserker that stands and fights harder, not a diver like Outrider.
	UnitType.MARAUDER: {
		"health": 85.0 * HEALTH_MULTIPLIER, "damage": 18.0, "attack_range": 45.0,
		"attack_interval": 0.8, "move_speed": 165.0, "ranged": false,
		"avoids_melee": false, "melee_avoid_radius": 0.0,
	},
	UnitType.ARCHER: {
		"health": 70.0 * HEALTH_MULTIPLIER, "damage": 16.0, "attack_range": 260.0,
		"attack_interval": 1.2, "move_speed": 170.0, "ranged": true,
		"avoids_melee": true, "melee_avoid_radius": 150.0,
	},
	UnitType.MAGE: {
		"health": 55.0 * HEALTH_MULTIPLIER, "damage": 14.0, "attack_range": 220.0,
		"attack_interval": 1.5, "move_speed": 140.0, "ranged": true,
		"avoids_melee": true, "melee_avoid_radius": 170.0,
	},
	## Pure-mobility counter to kiting Archers/Mages: fast enough (200) to
	## outrun both outright (170/140) with no bonus damage or resistances
	## at all - the whole answer to "my melee can't catch archers" is
	## literally catching them, nothing else. Fragile (80 HP, no defensive
	## edge) so it loses a straight fight to either melee type if it's
	## forced into one.
	UnitType.OUTRIDER: {
		"health": 80.0 * HEALTH_MULTIPLIER, "damage": 10.0, "attack_range": 45.0,
		"attack_interval": 0.8, "move_speed": 200.0, "ranged": false,
		"avoids_melee": false, "melee_avoid_radius": 0.0,
	},
	## Counter to fast movers (Outrider specifically, but the slow applies
	## to anything it hits) - see SLOW_MULTIPLIER/SLOW_DURATION and _attack().
	## No bonus damage or resistances either; its counter-play is entirely
	## the debuff, not the damage triangle.
	UnitType.TRAPPER: {
		"health": 100.0 * HEALTH_MULTIPLIER, "damage": 9.0, "attack_range": 60.0,
		"attack_interval": 1.1, "move_speed": 130.0, "ranged": false,
		"avoids_melee": false, "melee_avoid_radius": 0.0,
	},
}

## Role behavior: target selection is a weighted score, not a strict ordered
## list (target_priority, removed) - the old approach couldn't express
## "prefer whoever's wounded" or "defend my ward" without special-casing,
## both of which the role system below needs. See _score_target().
##
## attacker type -> defender type -> preference bonus. Replaces the old
## ordered target_priority lists with equivalent (or richer) weighted
## preferences - e.g. Archer's old [Mage, Archer, Swordsman] tiers become
## descending bonuses here, plus new entries for Outrider/Trapper that
## didn't exist when target_priority was ordered-list-only. Shieldbearer/
## Marauder both stay empty (no type preference at all) - they hold the
## line and fight whoever's in front of them, not a specific type; Marauder
## in particular is a berserker, not a diver like Outrider, so it doesn't
## get a "hunt the squishy stuff" preference either.
##
## Archer/Mage/Outrider/Trapper's own preferences differentiate Shieldbearer
## from Marauder rather than treating "melee" as one bucket: Archer weighs
## Marauder (85 HP, hits hard) higher than Shieldbearer (190 HP, barely
## worth focusing) since "consistent DPS to squishy targets" should
## actually read Marauder as squishy-and-dangerous; Mage weighs Shieldbearer
## far higher than Marauder, since Shieldbearer's heavy armor conducts
## magic (1.7x incoming, see DAMAGE_MULTIPLIERS) while Marauder's light
## armor doesn't (1.0x, neutral) - "kill the swordsmen" is now specifically
## "kill the Shieldbearers."
const TYPE_PREFERENCE := {
	UnitType.SHIELDBEARER: {},
	UnitType.MARAUDER: {},
	UnitType.ARCHER: {
		UnitType.MAGE: 100.0, UnitType.OUTRIDER: 80.0, UnitType.ARCHER: 60.0,
		UnitType.TRAPPER: 50.0, UnitType.MARAUDER: 35.0, UnitType.SHIELDBEARER: 15.0,
	},
	UnitType.MAGE: {
		UnitType.SHIELDBEARER: 100.0, UnitType.OUTRIDER: 50.0, UnitType.ARCHER: 40.0,
		UnitType.TRAPPER: 40.0, UnitType.MAGE: 20.0, UnitType.MARAUDER: 30.0,
	},
	UnitType.OUTRIDER: {
		UnitType.ARCHER: 100.0, UnitType.MAGE: 60.0, UnitType.TRAPPER: 30.0,
		UnitType.MARAUDER: 10.0, UnitType.SHIELDBEARER: 5.0, UnitType.OUTRIDER: 20.0,
	},
	UnitType.TRAPPER: {
		UnitType.OUTRIDER: 90.0, UnitType.ARCHER: 40.0, UnitType.MAGE: 40.0,
		UnitType.MARAUDER: 25.0, UnitType.SHIELDBEARER: 15.0, UnitType.TRAPPER: 20.0,
	},
}

## Bonus per point of "how wounded" a candidate target is (0 at full health,
## WOUNDED_WEIGHT at 0 health) - "consistent DPS to squishy targets" reads
## as focus-firing already-wounded enemies to secure kills rather than
## spreading damage, applies to every role (not just Archer) since it's
## generally good behavior. Deliberately smaller than a typical
## TYPE_PREFERENCE gap so it nudges rather than overrides type preference.
const WOUNDED_WEIGHT := 40.0
## Added when a candidate is near this unit's `ward` (see _update_ward()) -
## deliberately the largest single term, so a Trapper reliably peels onto
## whatever's actually threatening its ward rather than a preferred-type
## enemy standing safely elsewhere. Falls off smoothly to 0 at
## WARD_THREAT_RADIUS rather than a hard cutoff.
const WARD_THREAT_WEIGHT := 120.0
const WARD_THREAT_RADIUS := 220.0
## Small tiebreaker so "no other reason to prefer A over B" falls back to
## nearest, without letting distance alone override a real type/wounded/
## ward preference for a far-but-juicier target.
const DISTANCE_WEIGHT := 0.05

## See _nearest_melee_threat()'s hysteresis - once already fleeing, the
## threat has to retreat to melee_avoid_radius * this before a unit stops
## evading and re-engages, instead of the same radius that triggered the
## flee in the first place. 1.5 first-pass, not tuned via playtesting - big
## enough that a chasing Shieldbearer/Marauder's closing speed can't
## realistically re-cross the gap in a single tick and flip the state
## right back.
const MELEE_THREAT_EXIT_MULTIPLIER := 1.5

## See _process()'s "give up and fight the blocker" logic - how many
## cumulative seconds of dealing with a melee threat (not necessarily
## consecutive - see THREAT_STRUGGLE_DECAY) before a unit abandons its
## current (unreachable) target and just fights whatever's blocking it.
## First-pass, not tuned via playtesting.
const THREAT_STRUGGLE_GIVE_UP := 3.0
## How fast _threat_struggle_time decays, relative to how fast it
## accumulates, once no threat is present - deliberately slower than 1:1 so
## the hysteresis band's brief non-fleeing frames don't reset progress
## toward "stuck" back to zero every time, but a genuinely sustained
## escape (no threat for a real stretch) still recovers it, just not
## instantly.
const THREAT_STRUGGLE_DECAY := 0.5

## Give-up mechanism for a unit whose _target simply never gets any closer -
## e.g. a Trapper (TYPE_PREFERENCE strongly favors Outrider, 90 vs. its next
## highest at 40) locked onto an Outrider that's actively kiting it (Trapper
## is one of OUTRIDER_BLOCKER_TYPES, so the Outrider's own AI is specifically
## built to stay away from this exact unit). _retarget() only ever re-fires
## when the current target dies or routs, so without this a unit chasing
## something with its own active evasion AI had no way to ever give up -
## confirmed via a headless trace: every one of 13 captured "runaway"
## episodes across 15 battles was a Trapper chasing a kiting Outrider, with
## dist growing without bound for the rest of the battle, zero damage
## exchanged either way. Same accumulate-while-stalled/decay-while-not
## pattern as THREAT_STRUGGLE_GIVE_UP, keyed on "closing distance per
## approach frame" instead of "threat present."
const CHASE_STALL_GIVE_UP := 6.0
const CHASE_STALL_DECAY := 0.5
## Below this much distance closed since the last check, the approach counts
## as stalled - small enough that normal closing speed (tens of px/frame)
## never trips it, but an evasive target holding station or slowly losing
## ground doesn't reset the timer either.
const CHASE_STALL_PROGRESS_EPSILON := 4.0
## How long _retarget() hard-excludes a just-given-up-on target (see its own
## doc comment) before it's eligible to be picked again - not permanent, so
## a target that's genuinely the only enemy left still eventually gets
## re-picked rather than leaving this unit with no target at all.
const CHASE_STALL_EXCLUDE_DURATION := 8.0

## "Blockers" an Outrider can always outmaneuver on raw move_speed alone
## (200, faster than all three) - every melee-range type except itself.
## Used by the flank/kite/dive maneuver below (_nearest_outrider_blocker,
## _outrider_kite_direction), not MELEE_THREAT_TYPES: that list is about
## squishy ranged units fleeing real danger, whereas an Outrider isn't
## afraid of any of these three types' raw damage (see STATS/
## DAMAGE_MULTIPLIERS - flat 1.0 everywhere) - only their ability to
## either catch/slow it (Trapper, see SLOW_MULTIPLIER) or simply stand
## between it and the enemy archer line it's actually trying to reach.
const OUTRIDER_BLOCKER_TYPES := [UnitType.SHIELDBEARER, UnitType.MARAUDER, UnitType.TRAPPER]
## How close a blocker has to be before an Outrider starts actively
## maneuvering around it instead of beelining its real target - bigger
## than any blocker's own attack_range (max 60, Trapper) so the Outrider
## reacts and opens distance before it could ever actually be hit/slowed,
## not after.
const OUTRIDER_BLOCKER_DANGER_RADIUS := 220.0
## Exit threshold once already kiting a blocker (see _kiting_blocker),
## vs. OUTRIDER_BLOCKER_DANGER_RADIUS as the entry threshold - the same
## 1.5x enter/exit split Archer/Mage's own melee-avoid flee-state already
## uses (see _nearest_melee_threat()'s exit-radius comment). Added after a
## reported hysteresis bug: with a single shared threshold, an Outrider
## whose kite retreat only partially outpaces its blocker (it blends 65%
## retreat with 35% pull toward its real target - see
## OUTRIDER_KITE_RETREAT_WEIGHT) could hover right around
## OUTRIDER_BLOCKER_DANGER_RADIUS and flicker between kiting and
## committing every time it crossed back and forth across that single
## line, instead of decisively breaking contact before committing.
const OUTRIDER_BLOCKER_SAFE_RADIUS := OUTRIDER_BLOCKER_DANGER_RADIUS * 1.5
## Proactive margin added on top of a ranged enemy's own attack_range
## (+UNIT_RADIUS) before an Outrider starts evading it - same "react
## before it's too late" principle as OUTRIDER_BLOCKER_DANGER_RADIUS being
## bigger than any melee blocker's own attack_range, applied to ranged
## threats too. See _nearest_outrider_ranged_exposure().
const OUTRIDER_RANGED_REACT_MARGIN := 60.0
## Exit margin once already evading a ranged threat, same enter/exit
## split as OUTRIDER_BLOCKER_SAFE_RADIUS above and for the same reason.
const OUTRIDER_RANGED_SAFE_MARGIN := OUTRIDER_RANGED_REACT_MARGIN * 2.5
## How far a blocker has to have drifted from its own Formation slot (see
## Formation/slot_offset, _apply_formation_pull) before an Outrider judges
## the archer line behind it "exposed" and commits to the dive. Reuses
## the same slot-offset distance _apply_formation_pull() already tracks
## as a direct stand-in for "how far has this blocker been pulled off the
## line it's supposed to be protecting," rather than computing a separate
## notion of "distance to the archer line" from scratch.
const OUTRIDER_DIVE_SEPARATION := 260.0
## How much of the kite direction is "retreat straight away from the
## blocker" vs "curve toward the real target" while kiting - high enough
## that the Outrider reliably opens distance instead of getting caught
## mid-curve, but not a pure 100% retreat (which would never make any
## progress toward the target at all). First-pass, not tuned via
## playtesting.
const OUTRIDER_KITE_RETREAT_WEIGHT := 0.65
## If a blocker never actually gives chase (e.g. it's leashed to a
## Formation slot far from this Outrider and the pull keeps reeling it
## back), kiting could stall forever with the "sufficient separation"
## condition never met. Mirrors THREAT_STRUGGLE_GIVE_UP's role for the
## flee-vs-fight-the-blocker case: after this many cumulative seconds (see
## _outrider_kite_time/THREAT_STRUGGLE_DECAY for the same slower-decay
## pattern), give up waiting and commit to the dive anyway.
const OUTRIDER_KITE_GIVE_UP := 4.0
## Once OUTRIDER_KITE_GIVE_UP triggers, blockers are ignored entirely for
## this many seconds - without a commit window, the very next frame's
## _nearest_outrider_blocker() would just find the same still-too-close
## blocker again and immediately resume kiting, flip-flopping instead of
## actually using the commitment to close distance on the real target.
const OUTRIDER_COMMIT_DURATION := 3.0

## Mage-specific "don't advance into a longer-ranged threat" list (see
## _mage_should_hold_back). Deliberately not folded into a generic
## "ranged" check via STATS.ranged: an enemy Mage (same 220 range) is a
## fair fight, not a threat to hold back from - only Archer (260) sits
## strictly outside Mage's own 220 attack_range, meaning there's no
## position where Mage can hit its own target without Archer already
## being able to hit back. Reported issue: Archers "completely
## annihilate" Mages for exactly this reason - approaching at all is the
## mistake, not the approach itself, and a straight-line retreat can't
## fix it either (Archer's move_speed 170 beats Mage's own 140 outright,
## so retreating only delays getting caught, unlike the real separation
## Archer/Mage's existing melee-avoidance kiting can create against a
## slower Shieldbearer/Marauder).
const MAGE_RANGED_THREAT_TYPES := [UnitType.ARCHER]
## How close a live enemy Archer has to be before a Mage holds back
## (retreats toward its own Formation slot) instead of advancing on its
## own target - bigger than Archer's own attack_range (260) so the Mage
## reacts to an approaching Archer before it's already in range, not the
## instant it's already close enough to be hit.
const MAGE_ARCHER_AVOID_RADIUS := 320.0

## Mage's attack splashes to nearby enemies instead of hitting only its
## primary target - per an explicit request ("area of effect attacks for
## mages"), this is the actual mechanical differentiator from Archer beyond
## raw numbers (both are otherwise "ranged, avoids melee" in the same
## shape). 90px sits right in the middle of the row_spacing values enemy
## Formation presets actually use (70-110, see FormationCatalog) so a Mage
## hitting one unit in a tightly packed line formation routinely catches
## its neighbors too - "punishes clustering" falls out of the existing
## formation spacing rather than needing a separately-tuned number.
const MAGE_SPLASH_RADIUS := 90.0
## Fraction of the primary hit's damage applied to each other enemy caught
## in the splash (see _splash_damage()) - well under 1.0 so a Mage's value
## is attrition against clustered formations over several hits, not
## one-shotting a whole group outright.
const MAGE_SPLASH_DAMAGE_MULTIPLIER := 0.5

## Morale/routing - per an explicit request to make battles less lethal
## for what are, in the real game, invested/named citizens: a unit whose
## morale collapses breaks and flees the battle (see _escape()) rather
## than fighting to the death, and if enough of a team breaks at once the
## whole remaining force routs together (see Formation.MASS_ROUT_THRESHOLD/
## force_rout_all()). morale (0-100, same scale as the real game's citizen
## happiness - GameState/CharacterData) eases toward a target each frame
## rather than snapping, mirroring that system's own "ease toward a
## target, don't jump" philosophy (_update_morale). The target is dragged
## down by this unit's own missing HP and by a decaying "shock" from
## nearby ally deaths (_notify_nearby_allies_of_death) - wounds alone
## rarely cross the rout threshold on their own (a unit would already be
## close to dead), but a wounded unit that also just watched an ally die
## nearby often will, and multiple deaths in quick succession can break
## even a healthy unit - deliberately not a single-cause trigger.
##
## Below this, a unit breaks - see _begin_routing(). No hysteresis/
## recovery band the way flee-state has one: per an explicit choice,
## routing is a one-way trip once triggered (a unit commits to fleeing
## off the map, see _process_routing/_escape), not something morale
## recovering afterward can cancel.
##
## Raised from 30 to 45 (alongside MORALE_WOUND_WEIGHT below, 60 to 85)
## per explicit follow-up feedback after playtesting: individually-routed
## units should visibly break and flee *before* dying more often, not
## mostly via the mass-rout cascade catching survivors of a battle that's
## already mostly decided by casualties. At the old 60/30 pairing, a
## wound alone needed a unit near 100% HP lost to matter at all (100-60=40,
## still above 30) - by the time a unit was wounded enough to rout on its
## own, it was usually already close to actually dying, so morale rarely
## got a real chance to save anyone: verified headless across 18 battles,
## 26.1% of all spawned units still died outright. At 85/45, a unit alone
## (no nearby ally death) crosses the threshold once it's lost about 65%
## of its HP (100 - 85*0.65 ≈ 45) - roughly a third of its max health
## still in hand when it breaks, a real buffer to actually survive
## fleeing rather than routing at the literal edge of death.
const ROUT_MORALE_THRESHOLD := 45.0
## How much of max_health, missing, drags morale's target down - see
## ROUT_MORALE_THRESHOLD's own comment for the retuning history/reasoning
## (raised from 60 alongside that threshold moving from 30 to 45). Even a
## lightly-wounded unit (30% HP lost) that's just watched one nearby ally
## die (MORALE_ALLY_DEATH_PENALTY) now crosses the threshold immediately
## (100 - 85*0.3 - 35 = 39.5 < 45) - wounds and ally deaths both
## meaningfully drive routing on their own now, not just in combination
## with a unit already nearly dead.
const MORALE_WOUND_WEIGHT := 85.0
## Flat morale-target hit per nearby ally death (see
## _notify_nearby_allies_of_death/MORALE_ALLY_DEATH_RADIUS) - stacks if
## several deaths land in quick succession (a real "the line is
## collapsing" moment can break even a healthy unit), but decays back out
## over a few seconds (MORALE_ALLY_DEATH_DECAY_RATE) so a single early
## loss doesn't permanently shadow morale for the rest of the fight.
const MORALE_ALLY_DEATH_PENALTY := 35.0
const MORALE_ALLY_DEATH_RADIUS := 260.0
const MORALE_ALLY_DEATH_DECAY_RATE := 5.0
## Points/second morale eases toward its current target - deliberately
## slow enough that even an instant catastrophic target drop (several
## nearby deaths at once) takes several real seconds to actually cross
## ROUT_MORALE_THRESHOLD, giving a battle room to develop before morale
## mechanics start deciding it.
const MORALE_EASE_RATE := 8.0
## How long a routing unit has to keep fleeing before it's considered to
## have escaped the battle (see _escape()) - time-based rather than
## position-based, since play_bounds already hard-clamps position at the
## map edge (a routing unit visibly runs to the boundary and pauses there
## briefly before vanishing, rather than continuing off-camera - a known,
## acceptable first-pass simplification).
const ROUT_ESCAPE_TIME := 5.0

## How often a Trapper reconsiders which ally it's guarding (see
## _update_ward()) - dynamic/periodic rather than assigned once, so it
## follows whichever ally is actually in danger as the battle shifts,
## rather than committing to one ward for the whole fight regardless of
## where the real threat moves.
const WARD_REEVAL_INTERVAL := 3.0
## Fallback for _guard_offset() when there's no living enemy to place
## itself toward (e.g. the last one just died) - just behind/beside the
## ward, not exactly overlapping. In the normal case (a live threat
## exists) _guard_offset() ignores this and computes a threat-facing
## offset of the same magnitude instead - see that function.
const WARD_OFFSET := Vector2(0.0, 40.0)
## How far a guard stands from its ward, toward the nearest threat - see
## _guard_offset(). Roughly matches melee attack_range, so the guard
## naturally sits about where an approaching melee attacker would first
## reach engagement range of it, rather than the threat, on its way to
## the ward it's screening.
const WARD_GUARD_DISTANCE := 45.0
## Leash range used in place of FORMATION_LEASH_RANGE * LEASH_MULTIPLIER
## while guarding a ward - deliberately much tighter than Trapper's
## ordinary 550px (1.0x multiplier) leash. A bodyguard that wanders far
## off chasing its own kills defeats the entire point of guarding - per
## an explicit request that a guard actually stand between its ward and
## the threat, the pull back toward that position needs to dominate
## combat intent much sooner than the loose general-purpose leash would
## ever allow, not just compute the "correct" position and hope a weak
## pull happens to win.
const WARD_LEASH_RANGE := 150.0
## See _ward_score() - deliberately larger than any possible danger-score
## gap (bounded by the map's own diagonal, ~2800px) so spreading coverage
## across every available ward always wins over concentrating it,
## regardless of relative danger.
const WARD_COVERAGE_PENALTY := 5000.0

## Per-role multiplier on FORMATION_LEASH_RANGE. Shieldbearer "holds the
## line for as long as possible" - the single tightest leash in the game,
## barely leaves its post even to chase a kill. Marauder is looser than the
## old Swordsman baseline (0.6) but still noticeably tighter than a fully
## unleashed unit - it pushes aggressively but is still fundamentally part
## of the line, not a diver. Outrider is the real outlier: its whole job is
## intentionally breaking formation cohesion to run down a specific enemy
## Archer, so it gets a much looser leash instead of being exempted from
## one entirely - still can't literally run to the map edge chasing
## something forever (see Combat System.md's "runs to the edge" history),
## just has far more room than everyone else before being reeled back.
const LEASH_MULTIPLIER := {
	UnitType.SHIELDBEARER: 0.4,
	UnitType.MARAUDER: 0.9,
	UnitType.ARCHER: 1.0,
	UnitType.MAGE: 1.0,
	UnitType.OUTRIDER: 2.0,
	UnitType.TRAPPER: 1.0,
}

## Applied by a Trapper's attack (see _attack()) to whatever it hits -
## overwrites rather than stacks on repeated hits (no duration-refresh or
## multiplicative-stacking logic), the simplest version that still directly
## negates a fast mover's whole advantage. First-pass numbers.
const SLOW_MULTIPLIER := 0.5
## Raised 2.0 -> 4.0 via Outpost_Survival/Balance.md's edit-and-hand-back
## workflow.
const SLOW_DURATION := 4.0

## defender type -> attacker type -> incoming damage multiplier. Encodes
## every resistance/weakness pair from Ideas/Combat Units.md directly
## rather than deriving it at runtime from separate resistance lists.
## Archer/Mage's own weakness to melee is a property of *their* row (both
## take 1.5x from either melee type equally - "weak to melee" doesn't
## depend on which kind of melee unit hit them) rather than something
## Shieldbearer/Marauder individually grant, so both deal the same bonus
## damage to Archer/Mage despite otherwise being very differently statted.
## What genuinely differs between them is their own defense: Shieldbearer's
## heavy armor stops arrows noticeably better than Marauder's light gear
## (0.4x vs 0.6x incoming from Archer) but conducts magic more effectively -
## like electricity - making it the single most magic-vulnerable unit in
## the game (1.7x incoming from Mage) while Marauder's light armor doesn't
## conduct at all (1.0x, neutral - the only melee-classed unit with no
## bonus damage taken from Mage). Outrider/Trapper are both flat 1.0 in
## every direction, including against each other - both were explicitly
## designed to win through mobility/crowd-control instead of the damage
## triangle, not to be a faction in it.
const DAMAGE_MULTIPLIERS := {
	UnitType.SHIELDBEARER: {UnitType.SHIELDBEARER: 1.0, UnitType.MARAUDER: 1.0, UnitType.ARCHER: 0.4, UnitType.MAGE: 1.7, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
	UnitType.MARAUDER: {UnitType.SHIELDBEARER: 1.0, UnitType.MARAUDER: 1.0, UnitType.ARCHER: 0.6, UnitType.MAGE: 1.0, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
	UnitType.ARCHER: {UnitType.SHIELDBEARER: 1.5, UnitType.MARAUDER: 1.5, UnitType.ARCHER: 1.0, UnitType.MAGE: 0.5, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
	UnitType.MAGE: {UnitType.SHIELDBEARER: 1.5, UnitType.MARAUDER: 1.5, UnitType.ARCHER: 1.5, UnitType.MAGE: 0.5, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
	UnitType.OUTRIDER: {UnitType.SHIELDBEARER: 1.0, UnitType.MARAUDER: 1.0, UnitType.ARCHER: 1.0, UnitType.MAGE: 1.0, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
	UnitType.TRAPPER: {UnitType.SHIELDBEARER: 1.0, UnitType.MARAUDER: 1.0, UnitType.ARCHER: 1.0, UnitType.MAGE: 1.0, UnitType.OUTRIDER: 1.0, UnitType.TRAPPER: 1.0},
}

## Flat, subtractive defense - per an explicit request for an armor system
## "separate from the percent counter bonuses" DAMAGE_MULTIPLIERS already
## provides. Deliberately a second, independent axis rather than folded into
## the multiplier table: DAMAGE_MULTIPLIERS answers "how well does this
## type's gear/build counter that attack type" (a per-matchup ratio), while
## ARMOR answers "how much raw force does this type's gear stop outright"
## (a flat, matchup-agnostic amount) - see _attack()/_splash_damage() for the
## exact order of operations (armor subtracted first, from the attacker's
## already skill-scaled damage, *then* the type multiplier is applied to
## what's left - not the other way around, which would let a strong
## resistance multiplier compound with armor toward zero and make armor
## least relevant on exactly the matchups where a type is already weak).
##
## Values are grounded in fluff already written elsewhere in this file, not
## picked fresh: Shieldbearer's and Marauder's STATS comments already
## describe "thicker armor" vs. "light gear" as the in-fiction reason
## Shieldbearer resists Archer harder (see DAMAGE_MULTIPLIERS), so they're
## the only two types with any armor at all here, roughly in that same
## ratio. Archer/Mage/Outrider/Trapper are all explicitly documented
## elsewhere as having "no defensive edge"/"no bonus damage or resistances"
## (see their own STATS/const comments above) - giving any of them nonzero
## armor would contradict text already asserting they have none, so they
## stay at 0.0 rather than inventing new fluff to justify a number.
## Magnitude is capped low relative to raw damage (8-18, see STATS) - see
## MIN_DAMAGE below for why a hit can never be reduced past a hard floor.
const ARMOR := {
	UnitType.SHIELDBEARER: 4.0,
	UnitType.MARAUDER: 1.0,
	UnitType.ARCHER: 0.0,
	UnitType.MAGE: 0.0,
	UnitType.OUTRIDER: 0.0,
	UnitType.TRAPPER: 0.0,
}

## Hard floor every hit deals regardless of armor - mirrors the classic
## RTS "armor can blunt a hit but never fully stop it" rule (this project's
## AoE2 inspiration uses the exact same max(1, ...) floor) so a high-armor
## target can't become literally unkillable to a low-damage attacker, and a
## unit with 0 armor taking a hit through a strong resistance multiplier
## (e.g. Shieldbearer vs. Archer's 0.4x) still always registers as *some*
## damage.
const MIN_DAMAGE := 1.0

const TEAM_COLORS := {
	Team.A: Color(0.35, 0.55, 1.0),
	Team.B: Color(1.0, 0.4, 0.35),
}

## Melee reach, in px - every current melee type sits at exactly this or
## close to it (Trapper's 60 is the sole exception). Range beyond this is
## what range_multiplier below prices in; a unit that can already hit at
## melee range gets its raw dps counted at full sticker price with none
## of "attacks before it can ever be hit back."
const RANGE_BASELINE := 45.0
## Cost premium per px of attack_range beyond RANGE_BASELINE. Tuned so
## Archer (260, 215px over) lands near a 1.5x premium and Mage (220,
## 175px over) near 1.4x - deliberately modest, since range's value is
## already partly expressed in play via the kiting/avoids_melee behavior
## it enables, not purely a raw-numbers force multiplier on top of that.
const RANGE_VALUE_PER_PIXEL := 0.0025
## Divides the average TYPE_PREFERENCE bonus a type draws as a target
## (preference bonuses run roughly 0-100) down into a sane discount
## range, so focus_fire_multiplier below doesn't need its own unrelated
## magic number at the call site.
const PRIORITY_NORMALIZER := 100.0

## "How much army is this worth" cost - second pass. The original version
## (health * damage-per-second alone) undercounted every other factor
## that measurably affects a unit's average value, which is exactly what
## let `archer_core_vs_melee_rush` reach "point-cost parity" while still
## being a 10/10 rout in verification: Melee Rush's 6825 bought only 5
## bodies against Archer Core's 7 (headcount itself was never priced),
## Marauder got zero credit for its punishing dps/attack-speed/mobility
## combination, and neither Marauder nor Outrider paid anything for being
## the exact pair Trapper+Archer was already built to hard-counter. See
## Outpost_Survival/Ideas/Combat Units.md's "Point-cost formula rework"
## section for the full diagnosis and the resulting archer_core_vs_melee_rush
## rebalance.
##
## Every added factor below is still an average across the *whole
## roster*, deliberately not a specific opposing composition's numbers -
## reacting to a specific enemy comp is what a counter-pick (Formation
## presets, StrategistAI) is *for*, not something point_cost should average
## away by baking one match's numbers into a supposedly composition-
## agnostic cost:
## - range_multiplier: attack_range beyond melee reach, priced via
##   RANGE_BASELINE/RANGE_VALUE_PER_PIXEL above.
## - mobility_multiplier: move_speed relative to the six-type average -
##   mobility is both offense (choosing/forcing engagements, running down
##   a fleeing target) and defense (evading a threat), priced relative to
##   the roster average so a later across-the-board speed pass doesn't
##   silently invalidate every cost.
## - avg_offense_multiplier / avg_defense_multiplier: this type's own
##   DAMAGE_MULTIPLIERS row/column, averaged across all six types - a
##   type that's typically strong into most matchups (or typically
##   resistant to most incoming damage) is worth more than the same raw
##   dps/hp number on a type with no such edge.
## - armor_multiplier: ARMOR's flat damage reduction, priced relative to
##   the roster's average raw damage (12.5, see STATS) the same way
##   mobility_multiplier prices move_speed relative to the roster average -
##   a point of armor is worth proportionally more/less as the overall
##   damage scale changes, rather than a fixed price that'd go stale the
##   next time STATS damage values get retuned. Only Shieldbearer/Marauder
##   have nonzero ARMOR, so this only raises those two types' cost.
## - focus_fire_multiplier: this type's average TYPE_PREFERENCE bonus
##   received as a *target*, across every attacker type's own preference
##   table - a type sitting near the top of several roles' target lists
##   (Outrider: #1 for Trapper, #2 for Archer) gets killed before its raw
##   hp/dps numbers ever fully matter in a real fight, so it should cost
##   less than the same stats on a type nobody specifically hunts.
##
## Known, deliberately-unfixed gap: nothing here represents an ability
## with no direct STATS entry - Trapper's on-hit slow and Mage's AoE splash
## (MAGE_SPLASH_RADIUS/MAGE_SPLASH_DAMAGE_MULTIPLIER, see _splash_damage())
## are the current examples. There's no general "ability value" system to
## derive a number from yet, and a hand-picked bonus would just be a
## differently-shaped magic number, not a real fix - flagged rather than
## faked. Consequence
## observed in play: Trapper-inclusive rosters (support_vs_outrider)
## still noticeably outperform what this formula alone would predict.
## Second known gap, added alongside ARMOR: existing MATCHUPS rosters (see
## CombatTestManager) were tuned for point-cost parity *before* armor
## existed - Shieldbearer/Marauder now cost modestly more than those
## rosters assumed, so their documented near-parity in Ideas/Combat
## Units.md is stale until a fresh verification pass re-checks win rates,
## not re-derived here.
static func point_cost(unit_type: UnitType) -> float:
	var stats: Dictionary = STATS[unit_type]
	var base := float(stats["health"]) * float(stats["damage"]) / float(stats["attack_interval"])
	var range_multiplier := 1.0 + maxf(0.0, float(stats["attack_range"]) - RANGE_BASELINE) * RANGE_VALUE_PER_PIXEL

	var all_types: Array = TYPE_NAMES.keys()
	var total_speed := 0.0
	var total_damage := 0.0
	for t in all_types:
		total_speed += float(STATS[t]["move_speed"])
		total_damage += float(STATS[t]["damage"])
	var mobility_multiplier := float(stats["move_speed"]) / (total_speed / all_types.size())
	var armor_multiplier := 1.0 + float(ARMOR[unit_type]) / (total_damage / all_types.size())

	var offense_sum := 0.0
	var defense_sum := 0.0
	var priority_sum := 0.0
	for other in all_types:
		offense_sum += float(DAMAGE_MULTIPLIERS[other][unit_type])
		defense_sum += float(DAMAGE_MULTIPLIERS[unit_type][other])
		priority_sum += float(TYPE_PREFERENCE[other].get(unit_type, 0.0))
	var avg_offense_multiplier := offense_sum / all_types.size()
	var avg_defense_multiplier := defense_sum / all_types.size()
	var focus_fire_multiplier := 1.0 / (1.0 + (priority_sum / all_types.size()) / PRIORITY_NORMALIZER)

	return base * range_multiplier * mobility_multiplier * armor_multiplier * avg_offense_multiplier \
		* (1.0 / avg_defense_multiplier) * focus_fire_multiplier

## Collision radius fed to NavigationAgent2D's avoidance (RVO) simulation -
## same for every type, first pass, roughly matching the character token's
## visual footprint.
const UNIT_RADIUS := 22.0

## Distance from this unit's Formation slot at which the return-to-formation
## pull (see _apply_formation_pull) fully dominates combat intent - not a
## hard wall, a saturation point for a smooth gradient. Loose enough to
## cover a normal frontal engagement (teams start 760px apart at the front
## rank, see FormationCatalog's "line" preset - two units pulled back at 550
## each can still close a 760px gap with room to spare) but tight enough
## that a unit chasing something faster than itself all the way across the
## map gets reeled back in well before it, rather than dragging the fight to
## the map edge.
const FORMATION_LEASH_RANGE := 550.0

## Fraction of a role's own leash range within which _apply_formation_pull()
## applies zero pull at all - see that function's own doc comment for why
## squaring pull_fraction alone wasn't enough. Confirmed via a headless
## path-straightness trace (perpendicular deviation from the straight
## chord between a unit's first and last sampled position during an
## ordinary approach) after the squared-only fix: Shieldbearer (the
## tightest-leashed type, LEASH_MULTIPLIER 0.4x, only a 220px range) still
## showed 7-8% chord deviation, notably worse than every other type's
## 1-3% - because the *same* absolute drift is a much larger fraction of
## Shieldbearer's small range than of a looser-leashed type's, so even
## squared it was still engaging early, and the deviation grew smoothly
## across most of the approach with a constant nearby-unit count
## throughout (ruling out RVO crowd-avoidance as the cause - that would
## show localized spikes coinciding with crowding, not one smooth hump).
## 0.3 wasn't enough on its own (Shieldbearer still at 4.2%); 0.5 brought
## it down to a consistent ~1.7% across repeated runs, with Marauder
## (0.9x multiplier) essentially flat at ~0%. A flat dead zone fixes this
## uniformly across every role's own range (fractional, not a fixed pixel
## amount) rather than needing a per-type tweak, and formation cohesion
## (see Formation.slowest_approach_speed()) already keeps a synchronized
## approach's drift small in the first place, so there's little real
## "reeling in" work for the pull to do until a unit has genuinely
## wandered off on its own. Full 6-matchup suite (3 runs each)
## re-verified clean at this value - no deadlocks/timeouts, so the larger
## dead zone doesn't reopen the original "runs to the map edge" issue the
## leash exists to prevent (the pull still reaches full strength at the
## actual leash range, just starts later).
const LEASH_DEAD_ZONE_FRACTION := 0.5

var unit_type: UnitType
var team: Team
## Live roster of the opposing team - a shared Array reference owned by
## CombatTestManager, which removes a unit from it (via the died signal)
## rather than this class querying the scene tree/groups itself.
var enemies: Array = []

var max_health: float
var health: float
var _attack_cooldown := 0.0
var _target: CombatUnit = null
var _dead := false
## The delta passed to the _process() call that most recently called
## nav_agent.set_velocity() - avoidance computes asynchronously, so
## _on_velocity_computed() needs a delta from whenever it eventually fires,
## not necessarily the current frame's.
var _delta := 0.0
## True whenever this unit is in range of _target with nothing to evade -
## see _process()'s "stand and fight" branch. Read by _on_velocity_computed()
## to hold ground instead of applying avoidance's suggested nudge.
var _holding_position := false
## True whenever this unit is actively kiting away from a melee threat -
## read by Formation._living_centroid() so a legitimately-retreating Archer/
## Mage doesn't drag its whole team's leash anchor backward with it (a real
## bug: including fleeing units in the centroid created a feedback loop
## where kiting dragged the anchor back, which pulled every other unit's
## leash back too, compounding into the whole team retreating).
var _fleeing := false
## See THREAT_STRUGGLE_GIVE_UP/THREAT_STRUGGLE_DECAY.
var _threat_struggle_time := 0.0
## See CHASE_STALL_GIVE_UP/CHASE_STALL_DECAY. _chase_tracked_target lets the
## stall timer reset cleanly whenever _target changes for any reason (died,
## routed, or this same give-up firing) rather than comparing against stale
## distance data from a different target.
var _chase_stall_time := 0.0
var _chase_last_dist := -1.0
var _chase_tracked_target: CombatUnit = null
## See CHASE_STALL_EXCLUDE_DURATION.
var _chase_stalled_target: CombatUnit = null
var _chase_stalled_target_timer := 0.0
## True whenever an Outrider is actively maneuvering around a blocker
## instead of beelining its real target - see _nearest_outrider_blocker/
## _outrider_kite_direction. Read by Formation._living_centroid() the
## same way _fleeing already is, so a legitimately-maneuvering Outrider
## doesn't drag its whole team's leash anchor along with it.
var _kiting_blocker := false
## See OUTRIDER_KITE_GIVE_UP/OUTRIDER_COMMIT_DURATION.
var _outrider_kite_time := 0.0
var _outrider_committed_timer := 0.0
## True whenever a Mage is holding back from an Archer threat instead of
## advancing on its real target - see _mage_should_hold_back(). Also read
## by Formation._living_centroid(), same reasoning as _fleeing/
## _kiting_blocker above.
var _holding_back := false
## True whenever _apply_formation_pull() is actively reeling this unit back
## toward its own leash center (past LEASH_DEAD_ZONE_FRACTION of its leash
## range - see that function). Also read by Formation._living_centroid(),
## same reasoning as _fleeing/_kiting_blocker/_holding_back - and the fix
## for a real, previously-unhandled feedback loop reported directly as
## "melee units drifting apart from the formation and leading each other
## on wild goose chases." Those three flags only cover units in a special
## *evasive* state; an ordinary unit just approaching a target that
## happens to be far away (a kiting Outrider, a fleeing Archer leading its
## pursuer on) was never excluded, so as it drifted, the formation's own
## anchor (Formation._living_centroid(), which this unit's own leash
## center is computed from) drifted right along with it - keeping
## dist_from_slot artificially small and defeating FORMATION_LEASH_RANGE's
## own documented purpose of reeling a unit back "before it drags the
## fight to the map edge." Worse, once the anchor moved, *every other*
## unit's own leash center moved with it too, pulling them off their own
## slots toward the runaway unit's direction - the reported "leading each
## other" part. Reset to false every frame in _process() (not just when
## _apply_formation_pull() is skipped) so a unit that catches its target
## and settles into _holding_position immediately rejoins the centroid
## rather than staying excluded on a stale value from mid-chase.
var _leashing_home := false
## See ROUT_MORALE_THRESHOLD's own doc comment for the full morale/rout
## design. morale is 0-100, starts full; _ally_death_shock is a decaying
## contribution to morale's target, bumped by _notify_nearby_allies_of_death.
## _routing/_rout_timer track this unit's one-way transition from fighting
## to fleeing the map (see _process_routing/_escape). Also read by
## Formation._living_centroid(), same reasoning as _fleeing/_kiting_blocker/
## _holding_back above - a routing unit shouldn't drag the team's leash
## anchor with it either.
var morale := 100.0
var _ally_death_shock := 0.0
var _routing := false
var _rout_timer := 0.0
## See LOS_BLOCK_GIVE_UP.
var _los_block_time := 0.0
## 1.0 = no slow. Set by take_damage_from_trapper-equivalent logic in
## _attack() when hit by a Trapper (see SLOW_MULTIPLIER/SLOW_DURATION);
## counts down and resets to 1.0 in _process(). Applied everywhere
## STATS.move_speed would otherwise be read directly (combat_velocity,
## the formation-pull's own return velocity, and nav_agent.max_speed) so a
## slowed unit is actually slower in every context, not just some of them.
var _speed_multiplier := 1.0
var _speed_debuff_timer := 0.0
## Hard clamp applied after every avoidance-driven move - RVO avoidance
## isn't aware of the navmesh's own bounds (it only reasons about nearby
## agents, not terrain), so heavy crowding at the initial engagement can
## genuinely push a unit's "safe velocity" outward for several frames in a
## row with nothing to stop it walking clean off the map. Set by
## CombatTestManager to the bounding box of the ground's own isometric
## footprint (_iso_ground_bounds_rect()), inset by this unit's radius - a
## deliberately loose superset backstop, not the real boundary (see that
## function's own doc comment; BattlefieldTerrain's border wall is the
## actual edge).
var play_bounds := Rect2()
## This unit's team formation and its assigned slot offset within it (both
## set by CombatTestManager in setup()) - see _apply_formation_pull(). The
## slot is relative to the Formation's own (dynamic) position, not a fixed
## world point.
var formation: Formation = null
var slot_offset := Vector2.ZERO
## Mid-battle preset switches (StrategistAI) used to snap slot_offset to
## its new value in a single frame - correct for the *destination*, but a
## unit already deep into approaching a target would suddenly find itself
## far outside FORMATION_LEASH_RANGE of a slot that teleported out from
## under it, and the leash pull in _apply_formation_pull() responds with a
## full-speed, straight-line reversal the same frame (no ramp - pull_weight
## is already 1.0 the instant dist_from_slot clears the leash range). From
## the player's view that reads as a frontline fighter bolting backward for
## no reason, even though the underlying preset choice (e.g. Guard pulling
## a magic-vulnerable Shieldbearer out of an enemy Mage's line of fire) is
## deliberate. begin_slot_transition() instead has slot_offset itself glide
## from its old value to the new one over SLOT_TRANSITION_DURATION, so the
## leash center moves gradually and the pull it produces ramps up with it
## rather than snapping to full force instantly.
const SLOT_TRANSITION_DURATION := 2.5
var _slot_transition_from := Vector2.ZERO
var _slot_transition_to := Vector2.ZERO
var _slot_transition_time := SLOT_TRANSITION_DURATION
## Set by CombatTestManager in setup() - see _terrain_speed_multiplier()/
## BattlefieldTerrain.blocks_line_of_sight(). Nullable so a unit still
## works (at 1.0x speed, no terrain cover) if ever spawned without one.
var terrain: BattlefieldTerrain = null
## Only meaningfully used by Trapper (see _update_ward()) - the ally this
## unit is currently protecting. When set, _apply_formation_pull() leashes
## to the ward's live position instead of the static formation slot.
var ward: CombatUnit = null
var _ward_reeval_timer := 0.0

## Sandbox stand-in for "this unit is also a citizen from the player's
## town" - a mock trained level (1-99, same range as SkillCurve) in
## SKILL_ID[unit_type], set by CombatTestManager at spawn (randomized, so a
## given battle actually shows the effect varying unit-to-unit) rather than
## coming from a real CharacterData. See COMBAT_SKILL_MULTIPLIER_PER_LEVEL
## for why this doesn't use SkillCurve.multiplier_for_level() directly -
## same curve shape, deliberately smaller effect.
var skill_level := 1
var _skill_multiplier := 1.0

## Non-empty only for a real citizen deployed from Base (see
## CombatTestManager's BattleState.active branch) - CharacterData.id of the
## citizen this unit represents, so a death can be traced back to a real
## town citizen once the battle ends. Left "" for every sandbox/enemy unit
## (both teams in the standalone F6/main-menu MATCHUPS sandbox, and the
## generated enemy roster in a real deployment) - nothing reads this field
## for those, it's purely a lookup key for the deployment casualty report.
var citizen_id := ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var health_bar_bg: ColorRect = $HealthBarBg
@onready var health_bar_fill: ColorRect = $HealthBarFill
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D


func setup(p_unit_type: UnitType, p_team: Team, p_enemies: Array, p_play_bounds: Rect2 = Rect2(), p_formation: Formation = null, p_slot_offset: Vector2 = Vector2.ZERO, p_skill_level: int = 1, p_terrain: BattlefieldTerrain = null) -> void:
	unit_type = p_unit_type
	team = p_team
	enemies = p_enemies
	play_bounds = p_play_bounds
	formation = p_formation
	slot_offset = p_slot_offset
	skill_level = p_skill_level
	terrain = p_terrain
	_skill_multiplier = 1.0 + float(skill_level - 1) * COMBAT_SKILL_MULTIPLIER_PER_LEVEL
	var stats: Dictionary = STATS[unit_type]
	max_health = stats["health"] * _skill_multiplier
	health = max_health
	name_label.text = "%s Lv%d" % [TYPE_NAMES[unit_type], skill_level]
	name_label.add_theme_color_override("font_color", TEAM_COLORS[team])
	sprite.modulate = TEAM_COLORS[team]
	_update_health_bar()

	nav_agent.radius = UNIT_RADIUS
	nav_agent.max_speed = stats["move_speed"] * _skill_multiplier
	nav_agent.avoidance_enabled = true
	# Defaults (neighbor_distance 500, time_horizon_agents ~20s) are tuned
	# for large crowds reacting to far-off traffic; with only ~12 units
	# total, that made every unit factor in nearly the whole battle as
	# "nearby," producing wide preemptive detours instead of tight,
	# local dodges - a real contributor to combat reading as sluggish.
	nav_agent.neighbor_distance = 200.0
	nav_agent.time_horizon_agents = 2.0
	nav_agent.velocity_computed.connect(_on_velocity_computed)


## Called by Formation.apply_preset() in place of setting slot_offset
## directly - see slot_offset's own doc comment.
func begin_slot_transition(new_offset: Vector2) -> void:
	_slot_transition_from = slot_offset
	_slot_transition_to = new_offset
	_slot_transition_time = 0.0


func _process(delta: float) -> void:
	if _dead:
		return
	_delta = delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_chase_stalled_target_timer = maxf(_chase_stalled_target_timer - delta, 0.0)

	if _slot_transition_time < SLOT_TRANSITION_DURATION:
		_slot_transition_time = minf(_slot_transition_time + delta, SLOT_TRANSITION_DURATION)
		var t := _slot_transition_time / SLOT_TRANSITION_DURATION
		slot_offset = _slot_transition_from.lerp(_slot_transition_to, t)

	_update_morale(delta)
	if _routing:
		_process_routing(delta)
		return

	if _speed_debuff_timer > 0.0:
		_speed_debuff_timer -= delta
		if _speed_debuff_timer <= 0.0:
			_speed_multiplier = 1.0

	if unit_type == UnitType.TRAPPER:
		_ward_reeval_timer -= delta
		if _ward_reeval_timer <= 0.0 or not is_instance_valid(ward) or ward._dead:
			_ward_reeval_timer = WARD_REEVAL_INTERVAL
			_update_ward()
			# A guard's whole job is reacting to wherever the danger
			# currently is, not maximizing personal kill efficiency - but
			# _retarget() otherwise only re-runs when the current target
			# dies, so a Trapper could stay committed to chasing a distant
			# Outrider indefinitely while a *different* one slips in next
			# to its ward (confirmed via a direct position trace: a
			# Trapper chased one Outrider it could never catch for a full
			# 20s while its ward sat right next to another). Piggybacks on
			# the same periodic cadence as the ward reassignment above
			# rather than a separate timer, and skips it while already
			# _holding_position so an active fight isn't interrupted just
			# because 3 seconds passed.
			if is_instance_valid(ward) and not _holding_position:
				_retarget()

	if not is_instance_valid(_target) or (_target as CombatUnit)._dead or (_target as CombatUnit)._routing:
		_retarget()
	if not is_instance_valid(_target):
		_holding_position = false
		_fleeing = false
		nav_agent.set_velocity(Vector2.ZERO)
		return

	var stats: Dictionary = STATS[unit_type]
	var effective_speed: float = float(stats["move_speed"]) * _speed_multiplier * _skill_multiplier * _terrain_speed_multiplier()
	nav_agent.max_speed = effective_speed
	var threat: CombatUnit = _nearest_melee_threat() if stats["avoids_melee"] else null

	# Never flee the thing you've already committed to fighting - without
	# this, a unit that had (for whatever reason) targeted the very
	# Shieldbearer/Marauder threatening it would flee its own target every
	# tick, guaranteeing it can never actually engage. Also the second half
	# of the "give up and fight the blocker" logic just below: once that
	# reassigns _target to `threat`, this stops the same threat from
	# immediately triggering a flee this same frame.
	if threat == _target:
		threat = null

	# Reported live-play issue: an Archer/Mage whose real target (picked by
	# TYPE_PREFERENCE, which favors squishy targets far behind the enemy's
	# own front line) sits behind an enemy Shieldbearer/Marauder ends up
	# perpetually trying to run past it - every attempt to close in on the
	# real target re-enters melee_avoid_radius and triggers another flee,
	# so it never gets anywhere and never fires a shot. _threat_struggle_time
	# accumulates while a threat is present (decaying, not resetting
	# instantly, once it isn't - see the const's own comment) as a proxy for
	# "stuck," and once it crosses THREAT_STRUGGLE_GIVE_UP, gives up on the
	# unreachable target and just fights whatever's actually blocking it
	# instead - directly what was asked for: attack the melee unit blocking
	# the way if reaching the real target would keep re-entering its flee
	# range.
	if threat:
		_threat_struggle_time += delta
		if _threat_struggle_time >= THREAT_STRUGGLE_GIVE_UP:
			_target = threat
			threat = null
			_threat_struggle_time = 0.0
	else:
		_threat_struggle_time = maxf(_threat_struggle_time - delta * THREAT_STRUGGLE_DECAY, 0.0)

	# Outrider-only flank/kite/dive maneuver (see OUTRIDER_BLOCKER_TYPES and
	# _nearest_outrider_blocker's own doc comment) - skipped entirely if
	# `threat` is already set (never happens for Outrider today since
	# avoids_melee is false, but keeps the two mutually exclusive on
	# principle if that ever changes). OUTRIDER_COMMIT_DURATION suppresses
	# blocker detection for a few seconds after a give-up, so the very next
	# frame's detection doesn't just immediately resume kiting the same
	# still-too-close blocker.
	#
	# A melee blocker takes priority when both are present, but a live
	# ranged enemy still close enough to actually be shooting this Outrider
	# (_nearest_outrider_ranged_exposure()) counts too, even with no melee
	# blocker at all - reported directly: "flanking inside the archer's
	# attack range before committing to the dive, allowing the archer to
	# get free damage." Without this, once no melee blocker was in the
	# way, an Outrider immediately reverted to a blind pathfind beeline at
	# its real target with zero awareness of ranged fire - the existing
	# ranged-avoidance blend inside _outrider_kite_direction only ever ran
	# while already kiting a melee blocker, never on its own. Reusing
	# `blocker` (rather than a parallel variable) for either case is
	# deliberate: _outrider_kite_direction() only needs *some* unit to
	# retreat from, melee or ranged, so both cases flow through the exact
	# same kiting/give-up machinery below with no extra branching.
	var blocker: CombatUnit = null
	if unit_type == UnitType.OUTRIDER and not threat:
		if _outrider_committed_timer > 0.0:
			_outrider_committed_timer -= delta
		else:
			blocker = _nearest_outrider_blocker()
			if not blocker:
				blocker = _nearest_outrider_ranged_exposure()
			if blocker:
				_outrider_kite_time += delta
				if _outrider_kite_time >= OUTRIDER_KITE_GIVE_UP:
					blocker = null
					_outrider_kite_time = 0.0
					_outrider_committed_timer = OUTRIDER_COMMIT_DURATION
			else:
				_outrider_kite_time = maxf(_outrider_kite_time - delta * THREAT_STRUGGLE_DECAY, 0.0)

	# Mage-only "don't advance into Archer range" hold-back (see
	# MAGE_RANGED_THREAT_TYPES/_mage_should_hold_back) - also skipped while
	# `threat` is set, since a closer melee threat already takes priority
	# via the existing flee branch below (a Mage that's already fleeing a
	# Shieldbearer/Marauder has bigger problems than an Archer it isn't
	# even trying to approach right now).
	var mage_holding_back := unit_type == UnitType.MAGE and not threat and _mage_should_hold_back()

	var to_target: Vector2 = _target.global_position - global_position
	var dist := to_target.length()

	# Only ranged units (Archer/Mage) ever check line of sight - melee
	# range makes the question moot (see _has_line_of_sight's own doc
	# comment). A unit that's out of range still approaches normally
	# regardless of blocked_los (it needs to close distance either way);
	# once in range, a blocked shot holds position and waits rather than
	# advancing further (see the movement branch below) and is withheld
	# entirely (see the attack trigger below).
	var blocked_los: bool = bool(stats["ranged"]) and not _has_line_of_sight(_target)

	# See LOS_BLOCK_GIVE_UP - a shot blocked for too long (e.g. a
	# stationary allied Shieldbearer holding the line directly in the
	# way) forces a fresh retarget rather than waiting on a blocker that
	# isn't going anywhere; to_target/dist/blocked_los are recomputed
	# against whatever _retarget() picked so the rest of this frame's
	# logic isn't acting on stale data from the old target.
	if blocked_los:
		_los_block_time += delta
		if _los_block_time >= LOS_BLOCK_GIVE_UP:
			_los_block_time = 0.0
			_retarget()
			if not is_instance_valid(_target):
				_holding_position = false
				_fleeing = false
				nav_agent.set_velocity(Vector2.ZERO)
				return
			to_target = _target.global_position - global_position
			dist = to_target.length()
			blocked_los = bool(stats["ranged"]) and not _has_line_of_sight(_target)
	else:
		_los_block_time = maxf(_los_block_time - delta * LOS_BLOCK_DECAY, 0.0)

	# combat_velocity is this unit's raw combat intent - actual routing
	# around other units (including a threat this unit is fleeing, or an
	# ally standing in the way while approaching) is NavigationAgent2D's
	# avoidance (RVO) simulation's job, not this branch's. That split is
	# what fixed archers/mages getting stuck: fleeing is a full-speed,
	# straight-line retreat (no more hand-rolled "curve toward the target"
	# blend diluting the escape speed below the pursuer's own speed - see
	# git history for that earlier, insufficient fix), and the routing
	# around whatever's actually in the way happens for free via avoidance.
	var combat_velocity := Vector2.ZERO
	# Speed actually used for combat_velocity's magnitude this frame - same
	# as effective_speed except in the approach branch below, where it's
	# clamped for formation cohesion. Passed to _apply_formation_pull() too
	# (instead of effective_speed) so the leash-return component can't push
	# a cohesion-clamped unit's blended velocity back past the cap.
	var movement_speed := effective_speed
	_holding_position = false
	_fleeing = false
	_kiting_blocker = false
	_holding_back = false
	_leashing_home = false
	if threat:
		_fleeing = true
		combat_velocity = (global_position - threat.global_position).normalized() * effective_speed
	elif blocker:
		_kiting_blocker = true
		combat_velocity = _outrider_kite_direction(blocker, effective_speed)
	elif mage_holding_back:
		_holding_back = true
		var slot_pos: Vector2 = formation.global_position + slot_offset if is_instance_valid(formation) else global_position
		var to_slot := slot_pos - global_position
		combat_velocity = to_slot.normalized() * effective_speed if to_slot.length_squared() > 100.0 else Vector2.ZERO
	elif dist > float(stats["attack_range"]):
		# See CHASE_STALL_GIVE_UP - track whether this unit is actually
		# closing distance on _target. Reset whenever _target itself
		# changed since the last frame (a fresh chase gets a clean slate,
		# not credit/blame from whatever the old target's distance was).
		if _target != _chase_tracked_target:
			_chase_tracked_target = _target
			_chase_last_dist = dist
			_chase_stall_time = 0.0
		else:
			var progress: float = _chase_last_dist - dist
			if progress < CHASE_STALL_PROGRESS_EPSILON:
				_chase_stall_time += delta
			else:
				_chase_stall_time = maxf(_chase_stall_time - delta * CHASE_STALL_DECAY, 0.0)
			_chase_last_dist = dist
			if _chase_stall_time >= CHASE_STALL_GIVE_UP:
				_chase_stalled_target = _target
				_chase_stalled_target_timer = CHASE_STALL_EXCLUDE_DURATION
				_chase_stall_time = 0.0
				_retarget()
				if not is_instance_valid(_target):
					_holding_position = false
					_fleeing = false
					nav_agent.set_velocity(Vector2.ZERO)
					return
				to_target = _target.global_position - global_position
				dist = to_target.length()
				_chase_tracked_target = _target
				_chase_last_dist = dist
		# Formation cohesion: while still just approaching (not yet
		# engaged in any of the other branches here), clamp to the
		# slowest currently-approaching teammate's pace - see
		# Formation.slowest_approach_speed() for the full reasoning and
		# what "given the command to engage" maps to in an AI-driven
		# battle with no literal player commands. Only this branch's
		# speed is affected; nav_agent.max_speed is lowered to match so
		# RVO avoidance can't push the actual movement past it either.
		if is_instance_valid(formation):
			movement_speed = minf(effective_speed, formation.slowest_approach_speed())
			nav_agent.max_speed = movement_speed
		nav_agent.target_position = _target.global_position
		var next_pos := nav_agent.get_next_path_position()
		var dir := next_pos - global_position
		if dir.length_squared() > 0.0001:
			combat_velocity = dir.normalized() * movement_speed
	else:
		# In range and no threat to evade - hold the line and finish this
		# target rather than drift. A zero *preferred* velocity alone isn't
		# enough: RVO still treats separation from crowded neighbors as a
		# hard constraint, not just this unit's own preference, so a
		# unit standing still mid-fight could still get physically jostled
		# by everyone else's avoidance around it. _holding_position tells
		# _on_velocity_computed() to ignore whatever avoidance computes and
		# not move this frame - engaged units still register their
		# (stationary) presence via set_velocity() below, so they remain a
		# proper obstacle for everyone else's avoidance, they just can't be
		# pushed around by it themselves anymore.
		#
		# This also covers blocked_los now (reported live-play issue:
		# archers were walking straight into the front-line clash trying
		# to find a clear angle, since "in range but blocked" used to fall
		# into the approach branch above just like "out of range" did).
		# Once already in range, closing distance further doesn't
		# reliably improve the shot and just drags a ranged unit deeper
		# into melee chasing one - holding and waiting for the blocker to
		# move (or die, or the target to reposition) is both safer and, in
		# a battle where units are constantly repositioning anyway, often
		# resolves on its own within a few seconds. See _los_block_time
		# below for the escape hatch if it doesn't.
		_face(to_target)
		_holding_position = true

	if [0, 1, 5].has(unit_type) and is_instance_valid(formation) and not is_instance_valid(ward):
		var dbg_leash_range: float = FORMATION_LEASH_RANGE * float(LEASH_MULTIPLIER.get(unit_type, 1.0))
		var dbg_slot_dist: float = global_position.distance_to(formation.global_position + slot_offset)
		if dbg_slot_dist / dbg_leash_range > 1.0 and Engine.get_process_frames() % 15 == 0:
			print("BRANCHDBG id=%d type=%s slot_ratio=%.2f holding=%s fleeing=%s kiting=%s holding_back=%s dist_to_target=%.0f" % [
				get_instance_id(), TYPE_NAMES[unit_type], dbg_slot_dist / dbg_leash_range,
				_holding_position, _fleeing, _kiting_blocker, _holding_back, dist
			])
	if _holding_position:
		nav_agent.set_velocity(Vector2.ZERO)
	else:
		var desired_velocity := _apply_formation_pull(combat_velocity, movement_speed)
		if desired_velocity.length_squared() > 0.0001:
			_face(desired_velocity.normalized())
		nav_agent.set_velocity(desired_velocity)

	# Attacking is independent of the movement branch above - a kiting or
	# avoidance-deflected unit still fires if its target happens to be in
	# range that tick (hit-and-run), rather than every retreat costing it
	# the whole tick's damage. blocked_los additionally withholds the shot
	# entirely for a ranged unit with no clear line to its target, even if
	# technically in range - see _has_line_of_sight.
	if dist <= float(stats["attack_range"]) and not blocked_los and _attack_cooldown <= 0.0:
		_attack(_target)
		# Inverse scaling (divide, not multiply) - a higher skill level
		# attacks *more often*, same direction as the damage/health/speed
		# bumps above, just expressed as a shorter cooldown rather than a
		# bigger number.
		_attack_cooldown = float(stats["attack_interval"]) / _skill_multiplier


## NavigationAgent2D avoidance computes off-thread - set_velocity() doesn't
## move the unit itself, this signal (fired once the safe/collision-adjusted
## velocity is ready, using whichever _process's delta was current at the
## time) is what actually does.
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if _holding_position:
		return
	global_position += safe_velocity * _delta
	if play_bounds.size != Vector2.ZERO:
		global_position = global_position.clamp(play_bounds.position, play_bounds.end)


## Blends combat_velocity with a pull back toward this unit's leash center,
## weighted by how far it's already drifted - a smooth gradient, not a hard
## clamp (an earlier version hard-clamped position to a fixed radius around
## the unit's own static spawn point, which caused real deadlocks: two units
## each leashed to their own far-apart, never-updating point could end up
## with no reachable overlap once the battle drifted from where it started -
## see Formation, whose whole job is being a leash center that moves with
## the battle instead). At dist_from_slot >= this role's own leash range the
## pull fully dominates (weight 1.0); below that it's a proportional mix, so
## a unit chasing something can still drift meaningfully off its slot
## without a sudden snap back the instant it crosses some threshold.
##
## pull_weight uses a dead zone plus the *squared* remaining fraction, not
## a plain linear one - reported live-play issue: melee units visibly
## curved toward their target instead of approaching in a straight line.
## Root cause was this function, not the approach/pathing code -
## dist_from_slot is essentially never exactly 0 (the formation anchor
## itself drifts as the team's centroid shifts), so a linear weight meant
## even a unit sitting well inside its leash range (a Shieldbearer 40-58px
## off a ~220px range, say) was already blending in an 18-26% pull toward
## its slot on every single frame - never enough to matter for actually
## reeling the unit in, just enough to visibly bend an otherwise-ordinary
## approach for no benefit. Squaring the fraction alone helped but wasn't
## enough for tightly-leashed types specifically (see
## LEASH_DEAD_ZONE_FRACTION's own comment - Shieldbearer's small leash
## range meant even squared, ordinary drift was still a big enough
## fraction of it to matter); LEASH_DEAD_ZONE_FRACTION zeroes the pull
## entirely below that fraction of the range, then the squared curve takes
## over for the remainder - same "smooth gradient, no deadlocks" property
## and the same full-strength pull at the actual leash range, without any
## curvature at all on a normal, formation-synchronized approach.
##
## The leash center itself is role-dependent: a Trapper with a live ward
## leashes to a point near the ward's own current position (see
## _guard_offset()) instead of a fixed formation slot, so it actually
## follows its charge around rather than sitting in a static spot.
## Everyone else (and a ward-less Trapper) uses the usual formation-slot
## center.
func _apply_formation_pull(combat_velocity: Vector2, speed: float) -> Vector2:
	if not is_instance_valid(formation):
		return combat_velocity
	var leash_center: Vector2
	var leash_range: float
	if is_instance_valid(ward):
		leash_center = ward.global_position + _guard_offset(ward)
		leash_range = WARD_LEASH_RANGE
	else:
		leash_center = formation.global_position + slot_offset
		leash_range = FORMATION_LEASH_RANGE * float(LEASH_MULTIPLIER.get(unit_type, 1.0))
	if play_bounds.size != Vector2.ZERO:
		leash_center = leash_center.clamp(play_bounds.position, play_bounds.end)
	var offset := global_position - leash_center
	var dist_from_slot := offset.length()
	if dist_from_slot < 0.001:
		return combat_velocity
	var raw_fraction := clampf(dist_from_slot / leash_range, 0.0, 1.0)
	var pull_fraction := clampf((raw_fraction - LEASH_DEAD_ZONE_FRACTION) / (1.0 - LEASH_DEAD_ZONE_FRACTION), 0.0, 1.0)
	var pull_weight := pull_fraction * pull_fraction
	if pull_weight <= 0.0:
		return combat_velocity
	_leashing_home = true
	var return_velocity := (-offset / dist_from_slot) * speed
	return combat_velocity.lerp(return_velocity, pull_weight)


## Per an explicit request: a guard should stand *between* its ward and
## whatever's actually threatening it, not just park at some fixed offset
## regardless of where the danger is. Finds the enemy nearest to the
## ward (not to this unit) and returns a WARD_GUARD_DISTANCE-long offset
## pointing from the ward toward it - so the guard's leash center sits on
## the ward's threat-facing side, interposing its own body between the
## two. This also means a guard now provides real line-of-sight cover for
## its ward (see _has_line_of_sight) as a natural side effect of standing
## there, not a separate mechanic. Falls back to the old fixed WARD_OFFSET
## if there's no living enemy to face right now (e.g. the last one just
## died) - a direction can't be computed from nothing.
func _guard_offset(target_ward: CombatUnit) -> Vector2:
	var live := _live_enemies()
	if live.is_empty():
		return WARD_OFFSET
	var nearest := _nearest_from(target_ward.global_position, live)
	var to_threat: Vector2 = nearest.global_position - target_ward.global_position
	if to_threat.length_squared() < 0.0001:
		return WARD_OFFSET
	return to_threat.normalized() * WARD_GUARD_DISTANCE


## This unit's own move speed for the current frame - base move_speed
## scaled by the slow debuff and combat skill, before any formation-
## cohesion clamping (see Formation.slowest_approach_speed(), which calls
## this on every teammate to find the group's pace). Same formula
## _process() computes locally as `effective_speed`; exposed here so
## Formation can query any unit's speed without duplicating it.
##
## Deliberately excludes _terrain_speed_multiplier() - unlike the Trapper
## slow debuff (a real, if temporary, change to a unit's own pace),
## whichever teammate's *path* happens to cross a BattlefieldTerrain rough
## patch is incidental, not a statement about the group's pace. Including
## it here would mean one unit's approach route brushing a single mud
## patch throttles the *entire formation's* cohesion speed to that patch's
## multiplier for as long as it's on it - confirmed via headless testing
## to roughly double battle length even in the "balanced" mirror matchup
## (engagement not starting until ~50s in, vs. the pre-terrain 14-39s
## typical range) purely from cohesion clamping, not actual combat
## slowdown. Terrain still slows that individual unit's own movement (see
## _process()'s effective_speed and _process_routing()), it just doesn't
## drag its teammates down with it.
func _uncapped_move_speed() -> float:
	return float(STATS[unit_type]["move_speed"]) * _speed_multiplier * _skill_multiplier


## 1.0 outside any BattlefieldTerrain rough patch, ROUGH_TERRAIN_SPEED_
## MULTIPLIER inside one - stacks multiplicatively with the Trapper slow
## debuff (_speed_multiplier) rather than overriding it, so a slowed unit
## caught on rough ground is slower still, not just re-slowed to the same
## floor.
func _terrain_speed_multiplier() -> float:
	if not is_instance_valid(terrain):
		return 1.0
	return terrain.get_speed_multiplier(global_position)


func _face(dir: Vector2) -> void:
	if absf(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0.0


## Deliberately never reassigns `enemies` itself - it's the exact same Array
## object CombatTestManager holds as team_a/team_b and prunes on death, so
## every unit on a side sees deaths on the other side for free. Filtering
## into a new Array here (as an earlier version of this function did) would
## silently detach this unit's view from that shared array, leaving stale
## freed-object references behind for _nearest_melee_threat() to crash on
## later - caught via the headless battle-simulation verification run.
##
## Only called when the current _target dies/goes invalid, or (see
## LOS_BLOCK_GIVE_UP) a ranged unit's shot has been blocked long enough to
## give up waiting on it - not re-run every frame in the ordinary case:
## "consistent DPS to squishy targets" means committing to a kill, not
## constantly re-scoring and flip-flopping toward marginally-better
## targets mid-fight, which would spread damage around instead of securing
## kills.
func _retarget() -> void:
	var live := _live_enemies()
	if live.is_empty():
		_target = null
		return
	# See CHASE_STALL_GIVE_UP: hard-exclude (not just penalize) a target
	# just given up on for making no progress, while any other living
	# enemy exists. A soft score penalty alone proved unreliable in
	# practice - DISTANCE_WEIGHT still favored the nearby-but-unreachable
	# target over a genuinely distant alternative often enough (confirmed
	# via headless trace: a Trapper kept re-picking the same kiting
	# Outrider it had just given up on) since the stalled target, by
	# construction, is usually still close (that's *why* it was worth
	# chasing in the first place), while a real alternative may be much
	# farther away on a large map - a gap DISTANCE_WEIGHT alone can outweigh
	# any score penalty short of making it larger than TYPE_PREFERENCE's
	# entire range. Falls back to the full list if excluding it leaves
	# nothing (it's genuinely the only enemy left) rather than going
	# targetless.
	var candidates := live
	if _chase_stalled_target_timer > 0.0:
		var filtered: Array = live.filter(func(u): return u != _chase_stalled_target)
		if not filtered.is_empty():
			candidates = filtered
	var best: CombatUnit = candidates[0]
	var best_score := _score_target(best)
	for c in candidates:
		var score := _score_target(c)
		if score > best_score:
			best = c
			best_score = score
	_target = best


## Weighted target score: type preference (TYPE_PREFERENCE) + how wounded
## the candidate already is (WOUNDED_WEIGHT) + how close it is to this
## unit's ward, if any (WARD_THREAT_WEIGHT) - distance to the candidate
## itself only ever factors in as a small tiebreaker (DISTANCE_WEIGHT). See
## each const's own comment for why it's weighted the way it is. Ranged
## attackers also apply LOS_BLOCKED_PENALTY against a candidate they
## currently have no clear shot at - moderate, not exclusionary (a much
## higher-value blocked target can still win), but enough to usually steer
## a fresh retarget toward something actually reachable right now rather
## than immediately re-picking the same blocked target it just gave up on
## (see LOS_BLOCK_GIVE_UP). See _retarget() for CHASE_STALL_GIVE_UP's
## equivalent handling - a hard exclusion there rather than a score term
## here, since DISTANCE_WEIGHT would otherwise keep undermining a soft
## penalty for exactly the targets this is meant to steer away from.
func _score_target(candidate: CombatUnit) -> float:
	var score: float = TYPE_PREFERENCE[unit_type].get(candidate.unit_type, 0.0)
	var hp_frac := candidate.health / candidate.max_health if candidate.max_health > 0.0 else 0.0
	score += (1.0 - hp_frac) * WOUNDED_WEIGHT
	if is_instance_valid(ward):
		var dist_to_ward := candidate.global_position.distance_to(ward.global_position)
		score += WARD_THREAT_WEIGHT * clampf(1.0 - dist_to_ward / WARD_THREAT_RADIUS, 0.0, 1.0)
	if bool(STATS[unit_type]["ranged"]) and not _has_line_of_sight(candidate):
		score -= LOS_BLOCKED_PENALTY
	score -= global_position.distance_to(candidate.global_position) * DISTANCE_WEIGHT
	return score


## Trapper-only (see _process()) - picks whichever living Archer/Mage ally
## is currently in the most danger (nearest enemy closest to them), falling
## back to nearest ally if no enemies are alive to threaten anyone. Reads
## formation.living_units rather than a separate "allies" reference - it's
## already the exact same array CombatTestManager points a team's Formation
## at, so there's nothing new to keep in sync.
##
## Each Trapper decides independently, with no central assignment step, so
## danger alone isn't enough: every Trapper would agree on the single
## most-threatened archer and all pile onto it, leaving every other archer
## completely unguarded (confirmed via a headless trace before this fix -
## all 3 Trappers in one test converged on the same ward). _ward_score()
## folds in how many *other* living Trappers already guard a candidate as a
## strong penalty, so coverage spreads across every available ward first;
## only once everyone already has at least one guard does it become worth
## doubling up on whichever is most endangered.
func _update_ward() -> void:
	if not is_instance_valid(formation):
		ward = null
		return
	var candidates: Array = formation.living_units.filter(func(u):
		var c: CombatUnit = u
		return is_instance_valid(c) and not c._dead and c != self and (c.unit_type == UnitType.ARCHER or c.unit_type == UnitType.MAGE)
	)
	if candidates.is_empty():
		ward = null
		return
	var live_enemies := _live_enemies()
	var best: CombatUnit = candidates[0]
	var best_score := _ward_score(best, live_enemies)
	for c in candidates:
		var score := _ward_score(c, live_enemies)
		if score > best_score:
			best = c
			best_score = score
	ward = best


## WARD_COVERAGE_PENALTY is deliberately far larger than any possible
## _danger_to() gap (bounded by the map's own diagonal, ~2800px) - "already
## guarded by one more Trapper than some alternative" always outweighs any
## danger difference, guaranteeing an unguarded ward beats a guarded one
## regardless of relative threat, not just usually.
func _ward_score(candidate: CombatUnit, live_enemies: Array) -> float:
	var guard_count := 0
	for u in formation.living_units:
		var other: CombatUnit = u
		if other == self or not is_instance_valid(other) or other._dead:
			continue
		if other.unit_type == UnitType.TRAPPER and other.ward == candidate:
			guard_count += 1
	return _danger_to(candidate, live_enemies) - guard_count * WARD_COVERAGE_PENALTY


## Higher = more in danger (nearest enemy is closer). -INF with no living
## enemies at all, so any real ally beats "no candidate yet" in the caller's
## first-iteration comparison without needing a special case there.
func _danger_to(ally: CombatUnit, live_enemies: Array) -> float:
	if live_enemies.is_empty():
		return -INF
	var nearest := INF
	for e in live_enemies:
		nearest = minf(nearest, ally.global_position.distance_to((e as CombatUnit).global_position))
	return -nearest


## Excludes routing enemies too, not just dead ones - a unit that's broken
## and fleeing is out of the fight (see ROUT_MORALE_THRESHOLD's doc
## comment), so nothing should be able to target, ward-threat-score, or
## treat it as a blocker/threat any more than an already-dead one. Every
## targeting/threat-detection helper in this file goes through this (or
## _nearest_of_types, which calls it), so this one filter is the whole
## mechanism.
func _live_enemies() -> Array:
	return enemies.filter(func(e): return is_instance_valid(e) and not (e as CombatUnit)._dead and not (e as CombatUnit)._routing)


func _nearest(candidates: Array) -> CombatUnit:
	return _nearest_from(global_position, candidates)


## Same as _nearest(), but relative to an arbitrary point instead of this
## unit's own position - used by _guard_offset() to find the enemy
## nearest to a *ward*, not to the guard itself.
func _nearest_from(pos: Vector2, candidates: Array) -> CombatUnit:
	var best: CombatUnit = candidates[0]
	var best_dist := pos.distance_squared_to(best.global_position)
	for c in candidates:
		var d := pos.distance_squared_to((c as CombatUnit).global_position)
		if d < best_dist:
			best = c
			best_dist = d
	return best


## Only Shieldbearer/Marauder count as a "melee threat" to kite (see
## MELEE_THREAT_TYPES) - matches Ideas/Combat Units.md, where those are the
## only two melee-range types built to be evaded rather than to aggressively
## close distance themselves.
##
## Uses a hysteresis band, not a single threshold, to decide whether the
## nearest melee threat still counts as one: reported live-play issue -
## Archers rapidly flip-flopping between fleeing and turning back to engage
## right at the start of an engagement, never settling long enough to
## shoot. Root cause: a single radius used for both "start fleeing" and
## "stop fleeing" is unstable whenever a chasing Shieldbearer/Marauder's
## closing speed roughly matches the Archer's own evasive speed - the two
## hover right at the exact boundary distance, and a single _process()
## tick's worth of movement is enough to cross it back and forth, toggling
## every frame. _fleeing still holds *last* frame's value when this runs
## (_process() computes `threat` here before resetting _fleeing for the
## current frame), so it can cheaply tell which threshold to apply without
## extra state: already fleeing requires the threat to retreat past a
## noticeably larger exit radius before giving up and re-engaging, instead
## of the same trigger radius immediately flipping it back.
func _nearest_melee_threat() -> CombatUnit:
	var melee_enemies: Array = _live_enemies().filter(func(e): return MELEE_THREAT_TYPES.has((e as CombatUnit).unit_type))
	if melee_enemies.is_empty():
		return null
	var nearest := _nearest(melee_enemies)
	# The per-type default from STATS, unless this unit's current Formation
	# overrides it (e.g. "Skirmish" wants far more evasive ranged units,
	# "Guard" wants its front-line Archers holding ground like a tank
	# instead) - the tactics-as-a-formation-property extension point noted
	# in Ideas/Formation Strategy AI.md, now actually read.
	var radius: float = STATS[unit_type]["melee_avoid_radius"]
	if is_instance_valid(formation):
		radius = formation.tactics.get("melee_avoid_radius", radius)
	if _fleeing:
		radius *= MELEE_THREAT_EXIT_MULTIPLIER
	return nearest if global_position.distance_to(nearest.global_position) < radius else null


func _nearest_of_types(types: Array) -> CombatUnit:
	var matches: Array = _live_enemies().filter(func(e): return types.has((e as CombatUnit).unit_type))
	return _nearest(matches) if not matches.is_empty() else null


## See OUTRIDER_BLOCKER_TYPES/OUTRIDER_BLOCKER_DANGER_RADIUS/
## OUTRIDER_BLOCKER_SAFE_RADIUS/OUTRIDER_DIVE_SEPARATION for the reasoning
## behind each threshold below. Returns null (safe to dive) once the
## nearest blocker is either too far away to matter right now, or has
## already drifted far enough from its own Formation slot that the line
## it's protecting counts as exposed.
##
## Uses OUTRIDER_BLOCKER_SAFE_RADIUS (not the smaller _DANGER_RADIUS) as
## the distance check once _kiting_blocker is already true - see that
## constant's own doc comment for the hysteresis bug this fixes. _kiting_
## blocker still holds *last* frame's value here (CombatUnit._process()
## calls this before resetting it for the current frame), the same timing
## every other per-frame behavior flag in this class relies on.
func _nearest_outrider_blocker() -> CombatUnit:
	var nearest := _nearest_of_types(OUTRIDER_BLOCKER_TYPES)
	if not nearest:
		return null
	var exit_radius := OUTRIDER_BLOCKER_SAFE_RADIUS if _kiting_blocker else OUTRIDER_BLOCKER_DANGER_RADIUS
	if global_position.distance_to(nearest.global_position) >= exit_radius:
		return null
	if _blocker_drift(nearest) >= OUTRIDER_DIVE_SEPARATION:
		return null
	return nearest


## How far a blocker currently sits from its own Formation slot - a
## formation-less blocker (shouldn't happen in practice, every spawned
## unit gets one) is treated as already maximally drifted (INF) rather
## than blocking the dive forever on a null check.
func _blocker_drift(blocker: CombatUnit) -> float:
	if not is_instance_valid(blocker.formation):
		return INF
	var slot: Vector2 = blocker.formation.global_position + blocker.slot_offset
	return blocker.global_position.distance_to(slot)


## A live ranged enemy currently close enough to actually be shooting this
## Outrider (or about to) - only reached once no melee OUTRIDER_BLOCKER_
## TYPES unit is a concern (see the call site in _process()), so an
## Outrider already busy kiting a Shieldbearer doesn't need a second,
## independent reason to evade (the existing ranged-avoidance blend inside
## _outrider_kite_direction already nudges it away from ranged fire while
## kiting a melee blocker). This is what makes an otherwise "safe to
## commit" Outrider (no melee blocker in the way) keep maneuvering instead
## of blind-beelining through, or lingering inside, an enemy Archer's
## attack range. Same _kiting_blocker-aware enter/exit split as
## _nearest_outrider_blocker() above, for the same hysteresis reason.
func _nearest_outrider_ranged_exposure() -> CombatUnit:
	var nearest := _nearest_ranged_enemy()
	if not nearest:
		return null
	var margin := OUTRIDER_RANGED_SAFE_MARGIN if _kiting_blocker else OUTRIDER_RANGED_REACT_MARGIN
	var buffer: float = float(STATS[nearest.unit_type]["attack_range"]) + UNIT_RADIUS + margin
	if global_position.distance_to(nearest.global_position) >= buffer:
		return null
	return nearest


## Blends three concerns into an Outrider's kiting movement while a
## blocker is still too close to safely commit to the dive: retreat from
## the blocker (the dominant term - getting caught ends the maneuver
## immediately), a pull toward the real target (so kiting still makes net
## progress instead of pure evasion), and a steer away from any enemy
## Archer/Mage's own attack_range (no point maneuvering around one threat
## only to eat free ranged damage from another while doing it).
func _outrider_kite_direction(blocker: CombatUnit, effective_speed: float) -> Vector2:
	var away_vec := global_position - blocker.global_position
	var away := away_vec.normalized() if away_vec.length_squared() > 0.0001 else Vector2.UP
	var dir := away
	if is_instance_valid(_target):
		var toward_target_vec := _target.global_position - global_position
		if toward_target_vec.length_squared() > 0.0001:
			dir = away.slerp(toward_target_vec.normalized(), 1.0 - OUTRIDER_KITE_RETREAT_WEIGHT)

	var ranged_threat := _nearest_ranged_enemy()
	if is_instance_valid(ranged_threat):
		# Same OUTRIDER_RANGED_REACT_MARGIN proactive buffer _nearest_
		# outrider_ranged_exposure() uses - previously just attack_range +
		# UNIT_RADIUS with no margin, i.e. purely reactive (only nudging
		# away once already in range to be shot), which is exactly how an
		# Outrider could take "free damage" while still maneuvering around
		# a melee blocker per the reported issue.
		var buffer: float = float(STATS[ranged_threat.unit_type]["attack_range"]) + UNIT_RADIUS + OUTRIDER_RANGED_REACT_MARGIN
		if global_position.distance_to(ranged_threat.global_position) < buffer:
			var away_from_ranged_vec := global_position - ranged_threat.global_position
			if away_from_ranged_vec.length_squared() > 0.0001:
				dir = dir.slerp(away_from_ranged_vec.normalized(), 0.5)

	if dir.length_squared() < 0.0001:
		dir = away
	return dir.normalized() * effective_speed


func _nearest_ranged_enemy() -> CombatUnit:
	var ranged: Array = _live_enemies().filter(func(e): return bool(STATS[(e as CombatUnit).unit_type]["ranged"]))
	return _nearest(ranged) if not ranged.is_empty() else null


## See MAGE_RANGED_THREAT_TYPES/MAGE_ARCHER_AVOID_RADIUS.
func _mage_should_hold_back() -> bool:
	var nearest_archer := _nearest_of_types(MAGE_RANGED_THREAT_TYPES)
	if not nearest_archer:
		return false
	return global_position.distance_to(nearest_archer.global_position) < MAGE_ARCHER_AVOID_RADIUS


## Line-of-sight/cover check for ranged attacks (Archer/Mage only - see
## blocked_los in _process(); melee range makes the question moot). No
## raycasting/physics layer involved - this project has never used
## physics queries for combat (matches IsoUtils's "geometry math over
## physics engine" approach) - instead a simple point-to-segment distance
## test: any *other* living unit, ally or enemy (cover doesn't care which
## side provides it - a wall of allied Shieldbearers screens its own
## Archers just as much as an enemy body would), within LOS_BLOCK_RADIUS
## of the straight line between attacker and target counts as blocking
## the shot. Added specifically because a purely stat/AI-level fix
## couldn't make Outrider's flank/kite/dive maneuver (see its own doc
## comment) matter: without this, a diving unit is instantly exposed to
## *every* enemy Archer simultaneously the moment it's in range, unlike a
## real flanking maneuver that usually only exposes the diver to whichever
## defenders can actually see it.
const LOS_BLOCK_RADIUS := 34.0

## How many cumulative seconds (see _los_block_time/LOS_BLOCK_DECAY, same
## slower-decay-than-accumulation pattern as THREAT_STRUGGLE_GIVE_UP) a
## ranged unit's shot can stay blocked before it gives up waiting and
## forces a fresh _retarget() - a stationary blocker (a Shieldbearer
## "holding the line" barely moves at all, see LEASH_MULTIPLIER) could
## otherwise sit directly in the way indefinitely with nothing to ever
## clear it. LOS_BLOCKED_PENALTY makes the resulting retarget actually
## likely to land on something different, not just re-pick the same
## blocked target.
const LOS_BLOCK_GIVE_UP := 2.5
const LOS_BLOCK_DECAY := 0.5
## Score penalty _score_target() applies to a candidate currently blocked
## from this unit's line of sight - moderate (smaller than
## TYPE_PREFERENCE's typical 0-100 range) so a much higher-value blocked
## target can still beat a low-value clear one, but enough to usually tip
## the choice toward an unblocked target of similar value.
const LOS_BLOCKED_PENALTY := 50.0

func _has_line_of_sight(target: CombatUnit) -> bool:
	var from := global_position
	var to := target.global_position
	var seg := to - from
	var seg_len_sq := seg.length_squared()
	if seg_len_sq < 0.0001:
		return true
	if is_instance_valid(terrain) and terrain.blocks_line_of_sight(from, to):
		return false
	var blockers: Array = []
	if is_instance_valid(formation):
		blockers.append_array(formation.living_units)
	blockers.append_array(enemies)
	for u in blockers:
		var blocker: CombatUnit = u
		if not is_instance_valid(blocker) or blocker == self or blocker == target or blocker._dead:
			continue
		var t: float = clampf((blocker.global_position - from).dot(seg) / seg_len_sq, 0.0, 1.0)
		# Only a blocker strictly between the two endpoints counts - skips
		# a unit's own tightly-packed neighbors right next to it or the
		# target itself (t near 0 or 1), which would otherwise spuriously
		# block a shot that's aimed past them, not through them.
		if t < 0.05 or t > 0.95:
			continue
		var closest := from + seg * t
		if blocker.global_position.distance_squared_to(closest) < LOS_BLOCK_RADIUS * LOS_BLOCK_RADIUS:
			return false
	return true


func _attack(target: CombatUnit) -> void:
	var mult: float = DAMAGE_MULTIPLIERS[target.unit_type][unit_type]
	var raw: float = STATS[unit_type]["damage"] * _skill_multiplier
	var dmg: float = maxf(MIN_DAMAGE, (raw - float(ARMOR[target.unit_type])) * mult)
	target.take_damage(dmg)
	_punch()
	if STATS[unit_type]["ranged"]:
		_spawn_tracer(target.global_position)
	if unit_type == UnitType.TRAPPER:
		target.apply_slow(SLOW_MULTIPLIER, SLOW_DURATION)
	if unit_type == UnitType.MAGE:
		_splash_damage(target)


## Mage-only AoE follow-up to the primary hit above - see
## MAGE_SPLASH_RADIUS/MAGE_SPLASH_DAMAGE_MULTIPLIER. Splashes off the
## primary target's own position, not this caster's position - a Mage
## standing next to its target shouldn't matter, only how tightly the
## enemy is clustered around wherever the bolt actually landed. Each
## splash victim's damage is computed the same way _attack()'s own
## primary-hit formula is (that victim's own DAMAGE_MULTIPLIERS row against
## Mage, times this caster's skill), just scaled down by
## MAGE_SPLASH_DAMAGE_MULTIPLIER - a Marauder caught in the splash off a
## Shieldbearer target takes Marauder's own (neutral) resistance, not the
## Shieldbearer's (1.7x) one.
func _splash_damage(primary_target: CombatUnit) -> void:
	var origin := primary_target.global_position
	for e in _live_enemies():
		var victim: CombatUnit = e
		if victim == primary_target:
			continue
		if victim.global_position.distance_to(origin) > MAGE_SPLASH_RADIUS:
			continue
		var victim_mult: float = DAMAGE_MULTIPLIERS[victim.unit_type][unit_type]
		var victim_raw: float = STATS[unit_type]["damage"] * _skill_multiplier * MAGE_SPLASH_DAMAGE_MULTIPLIER
		var victim_dmg: float = maxf(MIN_DAMAGE, (victim_raw - float(ARMOR[victim.unit_type])) * victim_mult)
		victim.take_damage(victim_dmg)
	_spawn_aoe_burst(origin)


func take_damage(amount: float) -> void:
	if _dead:
		return
	health = maxf(health - amount, 0.0)
	_update_health_bar()
	_spawn_floating_text("-%d" % int(round(amount)), Color(1.0, 0.35, 0.35))
	if health <= 0.0:
		_die()


## Called by a Trapper's _attack() on whatever it hits - overwrites any
## existing slow rather than stacking (see SLOW_MULTIPLIER/SLOW_DURATION's
## own comment for why). _process() ticks _speed_debuff_timer down and
## resets _speed_multiplier to 1.0 once it expires.
func apply_slow(multiplier: float, duration: float) -> void:
	if _dead:
		return
	_speed_multiplier = multiplier
	_speed_debuff_timer = duration
	_spawn_floating_text("Slowed!", Color(0.55, 0.85, 1.0))


func _die() -> void:
	_dead = true
	_notify_nearby_allies_of_death()
	died.emit(self)
	_fade_and_free()


## Shared by _die() and _escape() - visually identical (both remove the
## unit the same way), only the signal fired and the lack of a damage
## number/death-triggering ally-morale-hit distinguish an escape from a
## death.
func _fade_and_free() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.parallel().tween_property(self, "scale", Vector2(0.6, 0.6), 0.4)
	tween.tween_callback(queue_free)


## See MORALE_ALLY_DEATH_PENALTY/MORALE_ALLY_DEATH_RADIUS. Reads
## formation.living_units directly (same array Formation._living_centroid()
## already iterates) rather than needing a new "allies" reference - every
## unit already holds a formation.
func _notify_nearby_allies_of_death() -> void:
	if not is_instance_valid(formation):
		return
	for u in formation.living_units:
		var ally: CombatUnit = u
		if ally == self or not is_instance_valid(ally) or ally._dead:
			continue
		if global_position.distance_to(ally.global_position) < MORALE_ALLY_DEATH_RADIUS:
			ally._ally_death_shock += MORALE_ALLY_DEATH_PENALTY


## Eases morale toward a target dragged down by this unit's own wounds and
## any recent nearby ally deaths - see ROUT_MORALE_THRESHOLD's own doc
## comment for the full design/reasoning. Runs every frame regardless of
## _routing state (cheap, and keeps _ally_death_shock decaying correctly
## even for a unit that's already routing, though nothing reads morale
## again once routing has begun - see that const's "one-way trip" note).
func _update_morale(delta: float) -> void:
	_ally_death_shock = maxf(_ally_death_shock - delta * MORALE_ALLY_DEATH_DECAY_RATE, 0.0)
	var wound_fraction: float = 1.0 - (health / max_health) if max_health > 0.0 else 0.0
	var target: float = clampf(100.0 - wound_fraction * MORALE_WOUND_WEIGHT - _ally_death_shock, 0.0, 100.0)
	morale = move_toward(morale, target, MORALE_EASE_RATE * delta)
	if not _routing and morale <= ROUT_MORALE_THRESHOLD:
		_begin_routing()


## Entry point for both the individual morale-driven trigger (_update_morale)
## and Formation.force_rout_all()'s mass-rout cascade - guarded so either
## path is safe to call more than once (e.g. a unit whose own morale
## already broke it, then gets swept up in a mass rout a moment later).
func _begin_routing() -> void:
	if _routing or _dead:
		return
	_routing = true
	name_label.text = "%s (Routing)" % name_label.text


## Called externally by Formation.force_rout_all() when enough of this
## unit's team has already broken - see MASS_ROUT_THRESHOLD.
func force_rout() -> void:
	_begin_routing()


## Movement-only branch _process() switches to entirely once _routing is
## true - no targeting, no attacking, just getting off the map (see
## ROUT_ESCAPE_TIME/_escape()). Runs away from the enemy's side of the
## field (Formation.facing already encodes which way that is) blended
## with fleeing whatever enemy is actually nearest, so a routing unit
## doesn't sprint blindly into one that happens to be standing between it
## and the exit.
func _process_routing(delta: float) -> void:
	var stats: Dictionary = STATS[unit_type]
	var effective_speed: float = float(stats["move_speed"]) * _speed_multiplier * _skill_multiplier * _terrain_speed_multiplier()
	nav_agent.max_speed = effective_speed
	_holding_position = false
	_fleeing = false
	_kiting_blocker = false
	_holding_back = false

	var away_from_enemy_side := Vector2(-formation.facing, 0.0) if is_instance_valid(formation) else Vector2(-1.0, 0.0)
	var direction := away_from_enemy_side
	var live := _live_enemies()
	if not live.is_empty():
		var nearest_threat := _nearest(live)
		var away_from_threat: Vector2 = global_position - nearest_threat.global_position
		if away_from_threat.length_squared() > 0.0001:
			direction = away_from_enemy_side.slerp(away_from_threat.normalized(), 0.5)
	var desired_velocity := direction.normalized() * effective_speed
	_face(desired_velocity.normalized())
	nav_agent.set_velocity(desired_velocity)

	_rout_timer += delta
	if _rout_timer >= ROUT_ESCAPE_TIME:
		_escape()


## A routing unit that survives long enough successfully leaves the
## battle - see the escaped signal's own comment for why this is
## deliberately not just another _die() call.
func _escape() -> void:
	if _dead:
		return
	_dead = true
	escaped.emit(self)
	_fade_and_free()


func _punch() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _update_health_bar() -> void:
	var frac := clampf(health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	health_bar_fill.scale.x = frac
	health_bar_fill.color = Color(0.3, 1.0, 0.3).lerp(Color(1.0, 0.2, 0.2), 1.0 - frac)


func _spawn_floating_text(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.modulate = color
	label.z_index = 100
	label.position = global_position + Vector2(-10.0, -110.0)
	get_parent().add_child(label)
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 24.0, 0.6)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)


func _spawn_tracer(target_pos: Vector2) -> void:
	var line := Line2D.new()
	line.add_point(global_position + Vector2(0.0, -50.0))
	line.add_point(target_pos + Vector2(0.0, -50.0))
	line.width = 2.0
	line.default_color = Color(1.0, 1.0, 0.6, 0.9)
	line.z_index = 50
	get_parent().add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)


## Visual-only companion to _splash_damage() - an expanding, fading ring
## drawn at MAGE_SPLASH_RADIUS and centered on the impact point, so the
## player can actually see the AoE that just landed instead of splash
## damage being invisible relative to a normal single-target hit. Same
## "spawn a transient node, tween it out, queue_free" pattern as
## _spawn_tracer/_spawn_floating_text above.
func _spawn_aoe_burst(pos: Vector2) -> void:
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(0.65, 0.4, 1.0, 0.85)
	ring.z_index = 50
	ring.global_position = pos
	var segments := 24
	for i in range(segments + 1):
		var angle := TAU * float(i) / float(segments)
		ring.add_point(Vector2(cos(angle), sin(angle)) * MAGE_SPLASH_RADIUS)
	get_parent().add_child(ring)
	ring.scale = Vector2(0.3, 0.3)
	var tween := ring.create_tween()
	tween.tween_property(ring, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)
