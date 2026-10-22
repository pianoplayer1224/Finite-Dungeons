extends Node
## Sfx autoload: the game's sounds. Each category is a folder of variants in res://assets/sfx/;
## play() picks one at random, never the one it played last, so a sound heard over and over
## still varies. Dropping files into a folder adds variants: no code change. (Godot skips
## folders whose names start with ".", such as `.ignore/`.)
##
## Buttons need no code: every button plays clickSuccess when pressed (hovering is silent).
## Screens play only what is specific to an action, and any sound started in the same frame as
## a click replaces the click (a purchase, a refusal, a dialog opening, choosing an artefact),
## so one press never makes two sounds.

const DIR := "res://assets/sfx/"
## Category (folder name) -> when it plays.
const CATEGORIES := {
	"clickSuccess": "a button is pressed",
	"clickFail": "an action is refused (every warning toast, a bad save code)",
	"select": "an artefact or relic is chosen in run setup",
	"popup": "a dialog or story card opens",
	"buy": "a purchase or drone upgrade",
	"itemUse": "an artefact action: water sample, Cursed Socks, relic switch",
	"playerAttack": "the hero hits the monster",
	"monsterAttack": "the monster hits the hero",
	"droneMissile": "the yd drone fires",
	"win": "a fight is won",
	"lose": "the hero dies, in a fight or in the shop",
	"runEnd": "the Run End screen opens",
	"unlock": "an achievement, or Run End's newly unlocked relics and artefacts",
}
## Per-category level in dB on top of the volume setting (0: as recorded). Tune the mix here.
const LEVEL_DB := {}
const VOICES := 4  # players per category: how many of its sounds can ring at once

var _streams := {}   # category -> its variants
var _players := {}   # category -> its AudioStreamPlayers
var _next := {}      # category -> the player to use next (round robin)
var _last := {}      # category -> the variant played last
var _started := {}   # category -> the frame it last started in
var _played_frame := -1   # the last frame play() was called in
var _click_queued := false
var _click_frame := -1


func _ready() -> void:
	for category: String in CATEGORIES:
		var streams: Array[AudioStream] = []
		for file in ResourceLoader.list_directory(DIR + category):
			if not file.ends_with("/"):
				var stream := load(DIR + category + "/" + file) as AudioStream
				if stream != null:
					streams.append(stream)
		_streams[category] = streams
		var players: Array[AudioStreamPlayer] = []
		for i in VOICES:
			var player := AudioStreamPlayer.new()
			add_child(player)
			players.append(player)
		_players[category] = players
	get_tree().node_added.connect(_on_node_added)


## Silence every sound (GameState.quit_game() does, a moment before quitting).
func stop_all() -> void:
	for players: Array in _players.values():
		for player: AudioStreamPlayer in players:
			player.stop()


## Play a random variant of a category (a CATEGORIES key).
func play(category: String) -> void:
	_played_frame = Engine.get_process_frames()
	_start(category)


func _start(category: String) -> void:
	var streams: Array = _streams.get(category, [])
	var volume: float = GameState.settings["sfx_volume"]
	var now := Engine.get_process_frames()
	# The same sound twice in one frame (two toasts at once) plays once, not twice as loud.
	if streams.is_empty() or volume <= 0.0 or _started.get(category, -1) == now:
		return
	_started[category] = now
	var n := streams.size()
	var i := randi() % n
	var last: int = _last.get(category, -1)
	if n > 1 and i == last:
		i = (i + 1 + randi() % (n - 1)) % n
	_last[category] = i
	var players: Array = _players[category]
	var at: int = _next.get(category, 0)
	_next[category] = (at + 1) % players.size()
	var player: AudioStreamPlayer = players[at]
	player.stream = streams[i]
	player.volume_db = linear_to_db(volume) + LEVEL_DB.get(category, 0.0)
	player.play()


# ---------------------------------------------------------------- buttons

func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(_on_pressed):  # a node can enter the tree again
		button.pressed.connect(_on_pressed)


## A click waits for the end of its frame, and a play() in the same frame replaces it.
func _on_pressed() -> void:
	_click_frame = Engine.get_process_frames()
	if not _click_queued:
		_click_queued = true
		_flush_click.call_deferred()


func _flush_click() -> void:
	_click_queued = false
	if _played_frame != _click_frame:
		_start("clickSuccess")
