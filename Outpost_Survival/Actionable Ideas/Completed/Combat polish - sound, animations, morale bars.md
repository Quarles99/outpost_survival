## Completion write-up (2026-07-22)

Requested directly in chat: "Combat in the base is missing some key features, lets implement sound effects, routing animations, and morale bars under health bars." The "routing" ambiguity flagged below was resolved directly by the user before starting: it means the flee-the-battle mechanic (`_routing`), not pathfinding.

**Sound (`scripts/combat/combat_unit.gd`):** three new `AudioStreamPlayer2D` nodes per unit - `AttackSound`/`VoiceSound` (Master bus, always-audible deliberate cues, same treatment `Character.select_sound` gets) and `ImpactSound` (World bus, fades with camera zoom - fires once per landed hit, which in a large fight would otherwise compete with the two Master-bus cues). New sound pool consts: `SWORD_ATTACK_SOUNDS`/`BOW_ATTACK_SOUNDS`/`SPELL_ATTACK_SOUNDS` reuse the exact same files `character.gd`'s `SWORD_DRILL_SOUNDS`/etc. already use for TrainingGround drill flavor (so training already sounds like the real thing), dispatched by `SKILL_ID[unit_type]` via a new `_attack_pool()` helper - played in `_attack()`. `IMPACT_SOUNDS` (new, FilmCow `punch flesh 1-6.wav`) plays on the *receiving* unit inside `take_damage()` rather than picked by attacker weapon type - a landed hit sounds the same regardless of what dealt it, and Free Fantasy's own "Hits and Blocks" folders turned out to be swing/parry/block sounds, not a generic hit-landing grunt. `VOICE_SOUNDS` (new, FilmCow `scream 1-6.wav`) plays on both `_die()` and `_begin_routing()` - a death scream and a panic scream are the same kind of sound, and the two never fire back-to-back closely enough to read as repetitive. New `_play_combat_sound(player, pool, base_volume_db)` helper mirrors `Character._play_gather_sound`'s "random pick through a shared player" shape, generalized to an explicit player since this class has three; every play routes through the existing `SfxVariation.randomize()` (from the earlier "every SFX gets pitch/volume variation" pass) so repeated attacks/hits/screams don't sound identical.

**Rout animation:** `_sprite_frames_for()` now also builds a `"rout"` animation - the *same* 4 frames as `"walk"`, just played back at `ROUT_ANIM_SPEED_MULTIPLIER` (2.0x) speed. No dedicated fleeing pose exists anywhere in the sprite sheet, so this reuses the project's established "juice via tween/speed, not new art" approach (`_punch()`/`_fade_and_free()` already do the same) rather than needing new frames. `_begin_routing()` calls `sprite.play("rout")` - one-way, since `_routing` never reverts to false (a routing unit either `_escape()`s or `_die()`s, both remove it, so nothing ever plays `"walk"` again afterward).

**Morale bar:** the `morale` mechanic was already fully implemented and tuned (`_update_morale()`, `ROUT_MORALE_THRESHOLD`, `_begin_routing()`) - only the UI was missing, confirming the research below. New `MoraleBarBg`/`MoraleBarFill` `ColorRect` pair directly below the existing health bar (`_update_morale_bar()` mirrors `_update_health_bar()`'s `scale.x`-as-fraction shape exactly), called once in `setup()` and every frame from inside `_update_morale()`. Deliberately a blue→grey gradient rather than reusing health's green→red, so the two bars read as different stats at a glance instead of looking like a second health bar.

**Scenes:** `CombatUnit.tscn` and `OrcRaider.tscn` are separate (not inherited) scenes with identical node trees - the same 5 new nodes were added to both by hand rather than restructuring scene inheritance (out of scope for a sound/animation/UI pass); a `diff` after editing confirms the two scene files are still structurally identical (only script path/root name/`NameLabel` text differ), so the sound/morale work applies identically to real village-raid orcs with zero `orc_raider.gd` changes needed - it only overrides patrol/alert state, never `_attack`/`take_damage`/`_die`/`_begin_routing`.

**Verification:** `flatpak run org.godotengine.Godot --headless --path . scenes/combat/CombatTest.tscn --quit-after 60` - the sandbox's own `_ready()` spawns and `setup()`s every unit on both teams immediately, exercising every new `@onready var $NodeName` lookup (a missing/misnamed node fails loudly at that point) and the new sprite-frames/morale-bar code, over 60 frames of real combat (attacks, hits, at this unit count likely no deaths/routs in 60 frames, but the code paths were read-verified) - zero errors. `--headless --editor --quit` also clean (only the pre-existing, unrelated xray-shader headless warning).

**Known gap:** the 60-frame verification run is short enough that death/rout weren't necessarily exercised live in that specific run - `_die()`/`_begin_routing()`'s sound/animation wiring were verified by code review, not confirmed by ear/eye in a live session. Worth a quick manual playtest (`Simulate Attack` from the HUD, or a real village raid) to confirm they sound/read right, and to sanity-check `ROUT_ANIM_SPEED_MULTIPLIER`/volume levels aren't too subtle or too jarring - none of this was tuned via actual playtesting.

---

Original research (kept for reference):

Not started yet - research done, findings below so a future session doesn't have to re-derive them.

## Sound effects

`CombatUnit` (`scripts/combat/combat_unit.gd`) has zero `AudioStreamPlayer`/`AudioStreamPlayer2D` anywhere - combat is entirely silent today, both in the sandbox and real village raids (`OrcRaider extends CombatUnit`, adds nothing). `scenes/combat/CombatUnit.tscn` and `OrcRaider.tscn` are separate (not inherited) scenes with identical node trees - sound nodes need adding to both, or `OrcRaider.tscn` converted to inherit `CombatUnit.tscn` first.

Relevant unused assets already in the repo:
- `sound/Free Fantasy SFX Pack By TomMusic/OGG Files/SFX/Attacks/Sword Attacks Hits and Blocks/` - only `Sword Attack 1-3.ogg` (the swing) is used today (training-ground drill flavor, `character.gd`'s `SWORD_DRILL_SOUNDS`). `Sword Impact Hit 1-3.ogg`, `Sword Blocked 1-3.ogg`, `Sword Parry 1-3.ogg` are sitting unused - exactly what an actual on-hit moment (`target.take_damage()` in `_attack()`) wants.
- Same pattern for `Bow Attacks Hits and Blocks/` (`Bow Impact Hit 1-3.ogg`, `Bow Blocked 1-3.ogg` unused) and `Spells/` (a whole themed library - Fireball/Ice/Rock/Water variants - beyond the generic `Spell Impact 1-3.ogg` already used).
- `FilmCow Recorded SFX/` (nearly 4000 files, currently unreferenced anywhere) has generic, theme-neutral impact/death sounds: `punch 1-12.wav`/`punch flesh 1-20.wav`, `stab 1-7.wav`, `scream 1-22.wav` (candidate death/rout-break sting), `body fall 1-13.wav` (candidate for the death fade).
- `sound/Free Fantasy SFX Pack By TomMusic/.../Footsteps/{Dirt,Stone,Water,Wood}/` entirely unused by anything - not obviously in scope for "combat" specifically but worth knowing about.

Reuse `SfxVariation.randomize()` (`scripts/sfx_variation.gd`) and the existing `_play_gather_sound(pool)`-style "random pick from an `Array[AudioStream]` pool through one shared player" pattern from `character.gd` rather than reinventing pitch/volume jitter or pool-picking.

## Morale bars

**The `morale` mechanic already exists in full** (`CombatUnit.morale`, `_update_morale()`, `ROUT_MORALE_THRESHOLD`, `_begin_routing()`) - it's tuned and shipped, just never rendered. This is UI-only work: the health bar is two `ColorRect`s (`HealthBarBg`/`HealthBarFill`, driven by `_update_health_bar()`, `combat_unit.gd` ~2135) with `scale.x` as the fill fraction - a morale bar is a third `ColorRect` pair directly below it, driven by an analogous `_update_morale_bar()` reading `morale`/a max-morale constant. Confirmed `morale` is CombatUnit-only, not on `CharacterData` - villagers don't have it, only deployed/raid combat units do.

## Animations ("routing animations" - needs disambiguation before starting)

Only one animation state exists at all: `_sprite_frames_for()` builds a single `"walk"` loop, played once in `setup()` and never changed again - a unit visibly walk-cycles identically whether standing still fighting, attacking, fleeing, or actually moving. No idle/attack/hurt/die/rout animation exists; the only other visual feedback is `_punch()` (hit-taken scale bounce) and `_fade_and_free()` (death/escape fade).

The word "routing" is ambiguous here because this codebase already uses "routing" as an established term for the morale-break-and-flee mechanic (`_routing`/`_process_routing()`/`force_rout()`) - completely separate from pathfinding/navigation. Two real, different-scope readings:
- **(a) Movement/pathing animation** - distinguish idle vs. walking (a unit currently always walk-cycles even while `_holding_position` and not actually moving).
- **(b) Routing/morale-flee animation** - a distinct visual once `_routing == true` (panicked/faster sprint), tying into the morale-bar work above.

Ask which one (or both) before implementing - don't guess.

## Where to look when picking this up

`scripts/combat/combat_unit.gd` (the whole class), `scenes/combat/CombatUnit.tscn` + `OrcRaider.tscn` (node trees, need new `AudioStreamPlayer2D`/`ColorRect` nodes), `scripts/sfx_variation.gd` (reuse), `Outpost_Survival/Game Systems/Combat System.md` + `Combat Units.md` (update once built - neither currently mentions sound/animation/morale-UI at all, this is genuinely new doc surface, not reconciling an existing TODO).
