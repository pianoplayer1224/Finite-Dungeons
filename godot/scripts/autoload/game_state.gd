extends Node
## GameState autoload: the live profile, run and settings, and the ONLY path from UI to
## GameEngine. Every action is guarded by the run phase (no shopping during a fight, after a
## shop death, or after a run ended), autosaves, and reports new achievements.
##
## Screens call the action methods, read the returned events, and refresh from `player`.

signal profile_changed
signal run_changed
signal settings_changed
signal achievement_unlocked(key: String)

enum Phase { MENU, CAMP, FIGHTING, RUN_OVER }

const SAVE_PATH := "user://profile.cfg"
const NEW_GAME_CODE := "00000"   # runs 0, highest 0, no achievements

var profile := ProfileState.new()
var player: PlayerState = null
var level := 1
var phase := Phase.MENU
var first_launch := false

## Start-of-run events, shown by Camp when it opens.
var pending_events: Array = []
## The resolved fight for the Battle screen: {level, result, before, after, monster, forecast}.
var last_fight := {}
## Run summary for the Run End screen: {kind, events, code, newly_unlocked, new_achievements, level}.
var run_end := {}

## Session settings (the Python's UI dict) plus Godot-only ones; persisted.
var settings := {
	"show_hits": true,
	"colours": Values.COLOURS_ON,
	"battle_speed": 1.0,
	"show_numbers": true,
	"fullscreen": false,
	"sfx_volume": 1.0,
	"music_volume": 1.0,
}

var _known_ac := {}
var _hold_achievements := false
var _held: Array[String] = []
var _run_start_highest := 0
var _run_start_ac := {}


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)   # Android's Back goes back (App.back); the main menu asks to quit
	get_window().min_size = Vector2i(1280, 720)
	load_profile()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	# Android can kill a paused (backgrounded) app without a close request, so save what closing
	# would (this run's levels beaten count) while the run itself carries on.
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		var highest := profile.highest
		if in_run() and run_end.is_empty():
			GameEngine.quit_run(profile, level)
		save_profile()
		profile.highest = highest


## Save and exit. Closing mid-run is the Python's "Quit game": levels beaten still count.
func quit_game() -> void:
	if in_run() and run_end.is_empty():
		GameEngine.quit_run(profile, level)
	save_profile()
	# Godot's audio thread lets go of a stopped stream on its next mix; quitting while one plays
	# reports it as a resource still in use at exit.
	Sfx.stop_all()
	Music.stop_all()
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()


# ---------------------------------------------------------------- profile

func save_code() -> String:
	return SaveCodes.save_code(profile)


## Wipe all progress: the same as loading the fresh-profile code.
func reset_profile() -> void:
	load_code(NEW_GAME_CODE)


## Load a save code into the profile. Returns {"ok", "message"} from SaveCodes.load_code.
func load_code(code: String) -> Dictionary:
	var prof := ProfileState.new()
	var res := SaveCodes.load_code(prof, code)
	if res["ok"]:
		profile = prof
		_known_ac = profile.ac.duplicate()
		save_profile()
		profile_changed.emit()
	return res


func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "code", save_code())
	for key: String in settings:
		cfg.set_value("settings", key, settings[key])
	cfg.save(SAVE_PATH)


func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		first_launch = true
	else:
		SaveCodes.load_code(profile, cfg.get_value("profile", "code", "00000"))
		for key: String in settings:
			settings[key] = cfg.get_value("settings", key, settings[key])
	_known_ac = profile.ac.duplicate()
	_apply_settings()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	_apply_settings()
	save_profile()
	settings_changed.emit()


func _apply_settings() -> void:
	# A phone app is always full screen: on Android that is immersive mode (from the export
	# preset), and "windowed" would bring the status and navigation bars back.
	if not is_inside_tree() or OS.has_feature("mobile"):
		return
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	if settings["fullscreen"] and not fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not settings["fullscreen"] and fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func achievement_count() -> int:
	var n := 0
	for key: String in profile.ac:
		if profile.ac[key]:
			n += 1
	return n


# ---------------------------------------------------------------- run lifecycle

func in_run() -> bool:
	return phase == Phase.CAMP or phase == Phase.FIGHTING


func start_run(artefact: String, relic_choice: Variant) -> Array:
	_run_start_highest = profile.highest
	_run_start_ac = profile.ac.duplicate()
	var res := GameEngine.start_run(profile, artefact, relic_choice)
	player = res["player"]
	level = 1
	GameEngine.begin_level(player)
	phase = Phase.CAMP
	pending_events = res["events"]
	last_fight = {}
	run_end = {}
	save_profile()
	run_changed.emit()
	return res["events"]


## A snapshot of everything the UI animates, for before/after diffs.
func snapshot() -> Dictionary:
	if player == null:
		return {}
	return {
		"hp": player.hp, "max_hp": player.max_hp, "money": player.money,
		"atk": player.atk, "df": player.df, "spd": player.spd,
		"total_atk": player.total_atk(), "total_df": player.total_df(), "total_spd": player.total_spd(),
		"counters": player.counters, "ink": player.forbidden_ink, "relic": player.relic,
		"drone_atk": player.drone.atk, "drone_stages": player.drone.stages.duplicate(),
		"drone_slots": player.drone.slots_used, "elixirs": player.elixir_timers.size(),
		"extra_spd": player.extra_spd, "socks_sealed": player.socks_sealed,
	}


# ---------------------------------------------------------------- camp actions
# Each returns the engine's events (empty when the action is not allowed right now).

func buy(item: String) -> Array:
	if phase != Phase.CAMP:
		return []
	var res := GameEngine.try_buy(player, item, profile.ac)
	return _after_shop_action(res["events"], res["died"])


func drone_upgrade(track: int) -> Array:
	if phase != Phase.CAMP:
		return []
	return _after_shop_action(GameEngine.buy_drone_upgrade(player, track), false)


func activate_socks() -> Array:
	if phase != Phase.CAMP or player.artefact != "socks":
		return []
	return _after_shop_action(GameEngine.activate_socks(player), false)


func take_water_sample() -> Array:
	if phase != Phase.CAMP or player.artefact != "ar":
		return []
	var res := GameEngine.take_water_sample(player, level, profile.ac)
	return _after_shop_action(res["events"], res["died"])


func switch_relic() -> Array:
	if phase != Phase.CAMP or player.artefact != "carrier":
		return []
	return _after_shop_action(GameEngine.switch_relic(player), false)


func _after_shop_action(events: Array, died: bool) -> Array:
	var out := events.duplicate()
	if died:
		var end_events := GameEngine.shop_death_end(profile, level)
		out.append_array(end_events)
		_end_run("shop_death", out)
	_check_achievements()
	run_changed.emit()
	return out


func forecast() -> Dictionary:
	return GameEngine.fight_forecast(player, level)


## Commit to the fight: resolve it completely now; the Battle screen plays it back.
func start_fight() -> Dictionary:
	if phase != Phase.CAMP:
		return {}
	var fought_level := level
	var before := snapshot()
	GameEngine.leave_for_fight(player)
	var fc := GameEngine.fight_forecast(player, level)
	var result := GameEngine.resolve_level(player, level, profile)
	phase = Phase.FIGHTING
	if result["run_over"]:
		_end_run("won" if result["game_won"] else "died", result["pre"] + result["fight"] + result["post"])
		phase = Phase.FIGHTING  # stays until playback finishes; continue_after_fight() moves on
	elif result["won"]:
		level += 1
		GameEngine.begin_level(player)  # the next pre_fight() starts
	last_fight = {"level": fought_level, "result": result, "before": before, "after": snapshot(),
			"monster": Entity.create_monster(fought_level), "forecast": fc}
	# Achievements won in this fight are announced when playback reaches the end, not before.
	_hold_achievements = true
	_check_achievements()
	save_profile()
	run_changed.emit()
	return last_fight


## Announce the achievements held back during battle playback.
func release_achievements() -> void:
	_hold_achievements = false
	for key in _held:
		achievement_unlocked.emit(key)
	_held.clear()


## Battle playback finished: back to camp, or on to the run summary.
func continue_after_fight() -> void:
	release_achievements()
	if phase != Phase.FIGHTING:
		return
	phase = Phase.RUN_OVER if not run_end.is_empty() else Phase.CAMP
	run_changed.emit()


func leave_dungeon() -> Array:
	if phase != Phase.CAMP:
		return []
	var events := GameEngine.quit_run(profile, level)
	_end_run("quit", events)
	run_changed.emit()
	return events


func _end_run(kind: String, events: Array) -> void:
	phase = Phase.RUN_OVER
	var newly := []
	for key in GameEngine.unlocked_relics(profile.highest) + GameEngine.unlocked_artefacts(profile.highest):
		if key not in GameEngine.unlocked_relics(_run_start_highest) and key not in GameEngine.unlocked_artefacts(_run_start_highest):
			newly.append(key)
	var new_ach := []
	for key: String in profile.ac:
		if profile.ac[key] and not _run_start_ac.get(key, false):
			new_ach.append(key)
	run_end = {"kind": kind, "events": events, "code": save_code(), "level": level,
			"newly_unlocked": newly, "new_achievements": new_ach, "runs": profile.runs,
			"highest": profile.highest}
	save_profile()


func back_to_menu() -> void:
	phase = Phase.MENU
	player = null
	run_changed.emit()


func _check_achievements() -> void:
	for key: String in profile.ac:
		if profile.ac[key] and not _known_ac.get(key, false):
			_known_ac[key] = true
			if _hold_achievements:
				_held.append(key)
			else:
				achievement_unlocked.emit(key)
