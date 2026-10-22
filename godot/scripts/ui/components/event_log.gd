class_name EventLog
extends PanelContainer
## The scrolling log: every line the Python would print for an event, coloured by its kind
## (Values.TEXT_COLOURS via EventText.EVENT_COLOUR). Ordinary hits are skipped when the
## "show normal attacks" option is off, like the Python's render_events().

const MAX_LINES := 400

## Touch mode: a tap on the log (a press and release that did not move to scroll it).
signal tapped

var _text: RichTextLabel
var _count := 0
var _hint: Label
var _press_at := Vector2.INF


func _init() -> void:
	theme_type_variation = &"InsetPanel"
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_following = true
	_text.selection_enabled = true
	var size := UIKit.PHONE_INFO_TEXT if UIKit.phone else 20
	_text.add_theme_font_size_override("normal_font_size", size)
	_text.add_theme_font_size_override("bold_font_size", size)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_text)
	if UIKit.touch:
		_text.gui_input.connect(_on_text_input)


## A small mark in the log's top-right corner, e.g. "▲" for "tap to see more" ("" hides it).
func set_hint(text: String) -> void:
	if _hint == null:
		_hint = UIKit.label("", "BoldLabel", 18)
		_hint.add_theme_color_override("font_color", UIKit.INK_SOFT)
		_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_hint.offset_right = -18   # clear of the scroll bar
		_text.add_child(_hint)
	_hint.text = text


func _on_text_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton   # a touch arrives as an emulated mouse click
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_press_at = click.global_position
	elif _press_at.distance_to(click.global_position) <= UIKit.TAP_SLOP:
		_press_at = Vector2.INF
		tapped.emit()


func add_events(events: Array) -> void:
	for ev: Dictionary in events:
		add_event(ev)


func add_event(ev: Dictionary) -> void:
	if not GameState.settings["show_hits"] and ev["type"] in ["player_hit", "monster_hit"]:
		return
	var colour := UIKit.kind_colour(EventText.colour_of(ev), GameState.settings["colours"])
	for line in UIKit.event_lines(ev):
		add_line(line, colour)


func add_line(text: String, colour: Color = UIKit.INK, bold := false) -> void:
	var bb := UIKit.bb_colour(text, colour)
	if bold:
		bb = "[b]" + bb + "[/b]"
	if _count > 0:
		_text.append_text("\n")
	_text.append_text(bb)
	_count += 1
	if _count > MAX_LINES:
		_text.remove_paragraph(0)
		_count -= 1


func add_heading(text: String) -> void:
	add_line(text, UIKit.INK_SOFT, true)
