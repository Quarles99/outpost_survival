extends Node

## Generic "every UI button gets a click sound" system - an explicit request
## for "something subtle but weighty," not tied to any specific panel. An
## autoload (like TooltipManager) rather than something each of the ~11
## panel scripts wires up individually, specifically so it also covers
## every button any of them builds dynamically at runtime (BuildMenu's
## catalog buttons, RecruitPanel/CitizensPanel's per-citizen rows, etc.)
## without touching a single existing pressed.connect() call site.
##
## Works by listening to SceneTree.node_added, which fires once for every
## node that enters the tree regardless of whether it was placed in a
## .tscn or add_child()'d from code - so a button built at panel-open time
## is caught the same way a button already sitting in Base.tscn is. Every
## panel in this project frees its buttons on close (queue_free, not
## reparenting/hiding - see each panel's own doc comment), so a node only
## ever enters the tree once and re-connecting the same BaseButton twice
## isn't a real risk; the is_connected() guard below is defensive only.

const CLICK_SOUND := preload("res://sound/ui_click.wav")
## Pitched down slightly (BaseButton default pitch_scale is 1.0) - a lower
## pitch reads as heavier/more substantial than the raw sample, which on
## its own is a very short, thin, high transient. Quiet (-10.0, vs -6.0
## for every other one-shot SFX in this project) since this fires on every
## single UI click and shouldn't compete with actual gameplay sounds.
const VOLUME_DB := -10.0
const PITCH_SCALE := 0.85

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.stream = CLICK_SOUND
	_player.volume_db = VOLUME_DB
	_player.pitch_scale = PITCH_SCALE
	add_child(_player)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.pressed.is_connected(_play_click):
		node.pressed.connect(_play_click)


func _play_click() -> void:
	_player.play()
