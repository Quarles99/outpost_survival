extends RefCounted
class_name SfxVariation

## Shared pitch/volume randomization applied immediately before every one-
## shot SFX play() call (UiSoundManager's click, Character's select/gather/
## level-up sounds) - an explicit request that every sound effect except
## music get a small per-play variation so repeated triggers of the same
## sample don't read as an identical loop of themselves. Deliberately not
## wired into anything music-related (no music system exists yet either).
## Ranges are small enough to stay "the same sound" rather than an obviously
## different pitch/volume each time.
const PITCH_RANGE := 0.06
const VOLUME_RANGE_DB := 1.5


## base_pitch/base_volume_db are the player's own authored baseline (e.g.
## UiSoundManager's deliberately-lowered PITCH_SCALE, or LevelUpSound's
## halved volume_db) - this offsets around that baseline rather than
## replacing it, and must be called with the same base every time (not the
## player's current, already-offset pitch_scale/volume_db) or the variation
## would drift further from baseline on every successive play.
static func randomize(player: Node, base_pitch: float, base_volume_db: float) -> void:
	player.pitch_scale = base_pitch + randf_range(-PITCH_RANGE, PITCH_RANGE)
	player.volume_db = base_volume_db + randf_range(-VOLUME_RANGE_DB, VOLUME_RANGE_DB)
