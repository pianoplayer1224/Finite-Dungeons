class_name SplashText
extends Label
## The top bar's rotating splash line: a random message from SOURCE, crossfaded to another
## every HOLD seconds, never the same one twice in a row. Edit the text file to change the
## messages (one per line; blank lines and lines starting with # are skipped).

const SOURCE := "res://assets/text/splash.txt"
const HOLD := 6.0
const FADE := 0.4
const SLANT := 0.2   # synthetic italic (the font subsets have no italic face)

static var _messages: Array[String] = []
static var _italic: FontVariation

var _index := -1


static func messages() -> Array[String]:
	if _messages.is_empty():
		for line in FileAccess.get_file_as_string(SOURCE).split("\n"):
			var t := line.strip_edges()
			if t != "" and not t.begins_with("#"):
				_messages.append(t)
		if _messages.is_empty():
			_messages.append("")
	return _messages


func _init() -> void:
	theme_type_variation = &"TopBarLabel"
	if _italic == null:
		_italic = FontVariation.new()
		_italic.base_font = load("res://assets/ui/font_body.tres")
		_italic.variation_transform = Transform2D(Vector2(1.0, SLANT), Vector2(0.0, 1.0), Vector2.ZERO)
	add_theme_font_override("font", _italic)
	add_theme_font_size_override("font_size", 24)
	add_theme_color_override("font_color", Color(0.957, 0.906, 0.788, 0.82))
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_text = true
	text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_pick()
	var timer := Timer.new()
	timer.wait_time = HOLD
	timer.autostart = true
	timer.timeout.connect(_swap)
	add_child(timer)


func _swap() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, FADE)
	t.tween_callback(_pick)
	t.tween_property(self, "modulate:a", 1.0, FADE)


func _pick() -> void:
	var all := messages()
	var i := randi() % all.size()
	if all.size() > 1 and i == _index:
		i = (i + 1 + randi() % (all.size() - 1)) % all.size()
	_index = i
	text = all[i]
