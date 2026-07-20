extends Node

## Cross-scene handoff for Base <-> CombatTest deployment, following the
## same "stash on an autoload before change_scene_to_file, consume-and-clear
## on the other side" pattern SaveManager.should_load_on_start already
## established for Base's own load-on-start flow - see Base._ready() and
## SaveManager.gd. No other autoload (GameState/SaveManager/WorldGrid) owns
## anything about individual citizens or a single in-progress battle, so
## this is a new, narrowly-scoped autoload rather than bolting onto one of
## those.

## True from the moment Base triggers a deployment until CombatTestManager
## writes `result` and hands control back - lets CombatTestManager tell a
## real citizen-squad deployment apart from someone just opening the
## standalone sandbox (F6 / main menu's "Battle Test" button), which must
## keep working completely unchanged (MATCHUPS cycling, mock skill levels,
## Esc-to-main-menu).
var active := false

## One entry per deploying citizen: {"citizen_id": String, "citizen_name":
## String, "unit_type": CombatUnit.UnitType, "skill_level": int}. Built by
## Base from every
## citizen whose assigned_post is a TrainingGround right before deployment -
## see Base._on_attack_pressed. Positionally unordered (CombatTestManager
## reads the whole array, not by index).
var pending_squad: Array = []

## Base's own _serialize_state() Dictionary, captured in memory (never
## written to SaveManager/disk) immediately before deploying - see that
## function's doc comment for why disk/SaveManager.active_slot would risk
## clobbering the player's real save. Restored via Base._apply_state() the
## moment the battle scene hands control back, so the town is exactly as
## the player left it regardless of what happened on the battlefield.
var town_blob: Dictionary = {}

## Written by CombatTestManager once a deployment battle is fully resolved
## (see _declare_result/_on_unit_died's citizen_id-tagged accumulation) -
## {"outcome": "win"/"lose"/"draw", "casualty_ids": Array[String]}. Read and
## cleared by Base right after restoring town_blob.
var result := {}


## Called by Base right after applying town_blob + result, and by
## CombatTestManager if a deployment is ever abandoned mid-setup - leaves no
## stale data behind for the next battle (whether a real deployment or a
## later free-play sandbox visit) to accidentally pick up.
func clear() -> void:
	active = false
	pending_squad = []
	town_blob = {}
	result = {}
