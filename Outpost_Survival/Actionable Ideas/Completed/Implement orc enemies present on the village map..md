	- Soldiers at military buildings will patrol the village in small groups
	- Orcs may sometimes choose to attack villagers
	- The player can select orcs and select an attack option to have all of the town military units group up before moving out to attack
	- Implements combat system on the base map
	- Slows down expansion and gives use to defending military units
	-

## Completion write-up (2026-07-21)

Built as a first pass, MVP-scoped per explicit decisions made before implementation - see [[Village Raids]] (new `Game Systems/` doc) for the full technical design and changelog going forward. Confirmed with the user up front:
- Combat happens **live, on Base's own map** - not a scene-swap to the existing `CombatTest.tscn` sandbox (that flow, `_on_attack_pressed`/`BattleState`, is completely untouched).
- Raids are **tied to the day/night cycle**, no raid the first night, difficulty scaling per raid night (added mid-implementation per an explicit follow-up request - "start off weak but scale up in difficulty each night").
- Command scope is a **one-click Rally** (gather every citizen on `TrainingGround` duty into one squad and send them to fight in place) - not full multi-select/box-select, which doesn't exist anywhere in this codebase and was explicitly scoped out.

**Key files:** `scripts/combat/orc_raider.gd` (new `OrcRaider extends CombatUnit`, patrol/alert/engaged mode machine), `scripts/combat/raid_controller.gd` (new `RaidController`, mirrors `CombatTestManager`'s battle bookkeeping for a single asymmetric town-vs-raiders fight), `scenes/combat/OrcRaider.tscn` (new scene, same layout as `CombatUnit.tscn`). `scripts/base.gd` gained the spawn/selection/Rally/resolution wiring; `scripts/character.gd` gained `flee_home_from_raid()` (no citizen-HP system - an attacked villager's work is interrupted and they walk home until the next dawn recalls them); `scripts/hud.gd`/`HUD.tscn` gained a `RallyButton`; `autoload/world_grid.gd` gained `find_random_edge_cell()`.

**Villager-under-attack mechanic:** deliberately not a wound/HP system (`Character` has none today) - purely economic consequence (lost production, an idle citizen standing around), not lethal. See [[Village Raids]] for why this was judged sufficient for a first pass.

**Verification done:** full-project headless boot (`flatpak run org.godotengine.Godot --headless --path . res://scenes/base/Base.tscn --quit`) confirmed zero script/parse errors after every change. A standalone headless smoke test (temporary `-s` script, deleted after) directly exercised `OrcRaider.roster_for_night`/`skill_level_for_night` scaling across several nights, orc patrol movement (spawn, wander toward a picked target, no crash across repeated ticks), and a full `RaidController` engagement end-to-end (begin_engagement → mass-rout trigger → resolved outcome → teardown) - all worked correctly. The villager-notice/flee interaction and the actual in-editor Rally flow were reviewed by hand but **not GUI-playtested** (no display available in this environment) - flagging this as the one real verification gap; the user should playtest a full night's raid (patrol → a citizen fleeing → Rally → resolution → dawn recall/withdrawal) before considering this fully done.

**Known gaps / deferred (see [[Village Raids]] for the full list):** multi-select/box-select, orc patrol formations, a real citizen-HP/wound system, loot-on-attack, orc camps as a persistent map feature, orc-specific art, mid-raid save/load restoration (a load always cleanly discards an in-progress raid rather than resuming it). Raid scaling numbers are explicitly first-pass and will need playtesting/tuning - see `Balance.md`'s new "Village Raids" section.