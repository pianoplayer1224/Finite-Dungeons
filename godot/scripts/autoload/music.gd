extends Node
## Music autoload: one looping track at a time, crossfaded when it changes. It lives above the
## screens, so a track plays on across screen changes; App.go_to() picks the track for each
## screen (the fight theme in Battle, the woodland theme everywhere else from the main menu on;
## the title splash is silent). The tracks are made by tools/make_music.py from the masters in
## tools/music/: Ogg Vorbis, which loops without a gap, with "Woodland Fantasy" cut to end with
## its fade-out (the master has 5 s of silence after it).
##
## Music is streamed: decoded as it plays. The Web build would otherwise play it as a "sample",
## decoded whole into memory first (stereo, 32-bit, at the browser's rate: about 120 MB for the
## two tracks), which can get a phone browser's tab reloaded. Sound effects stay samples.

## Track -> [file, level in dB]. The levels bring both to about -25 LUFS (they are mastered at
## -15 and -10 LUFS), under the sound effects. Tune the mix here.
const TRACKS := {
	"woodland": ["res://assets/music/Woodland Fantasy.ogg", -10.0],
	"encounter": ["res://assets/music/The Last Encounter.ogg", -14.5],
}
## Tracks that start from the top each time they come back. The others never stop: faded out,
## they play on silently (the woodland theme through a fight) and fade back in wherever they are.
## (This dates from when the Web build played music as samples, where pausing went wrong: each
## resume landed further on by all the time spent paused.)
const RESTART := ["encounter"]
const FADE := 0.8  # seconds for a crossfade

var current := ""
var _players := {}  # track -> AudioStreamPlayer
var _mix := {}      # track -> 0..1, its share of a crossfade
var _fades := {}    # track -> its running fade Tween


func _ready() -> void:
	for track: String in TRACKS:
		var stream := load(TRACKS[track][0]) as AudioStream
		if "loop" in stream:
			stream.set("loop", true)
		var player := AudioStreamPlayer.new()
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.stream = stream
		add_child(player)
		_players[track] = player
		_mix[track] = 0.0


## Silence the music (GameState.quit_game() does, a moment before quitting).
func stop_all() -> void:
	for track: String in _players:
		if _fades.has(track):
			(_fades[track] as Tween).kill()
		(_players[track] as AudioStreamPlayer).stop()


## Crossfade to a track (a TRACKS key); the one already playing just carries on.
func play(track: String) -> void:
	if track == current:
		return
	if current != "":
		_fade(current, 0.0)
	current = track
	var player: AudioStreamPlayer = _players[track]
	if track in RESTART or not player.playing:
		player.play()
	_fade(track, 1.0)


## Apply settings["music_volume"] (the Options slider changes it live).
func apply_volume() -> void:
	for track: String in _players:
		_set_mix(_mix[track], track)


func _fade(track: String, to: float) -> void:
	if _fades.has(track):
		(_fades[track] as Tween).kill()
	var t := create_tween()
	_fades[track] = t
	t.tween_method(_set_mix.bind(track), _mix[track], to, FADE)
	if to == 0.0 and track in RESTART:
		t.tween_callback((_players[track] as AudioStreamPlayer).stop)


func _set_mix(mix: float, track: String) -> void:
	_mix[track] = mix
	var volume: float = mix * GameState.settings["music_volume"]
	(_players[track] as AudioStreamPlayer).volume_db = linear_to_db(maxf(volume, 0.0001)) + TRACKS[track][1]
