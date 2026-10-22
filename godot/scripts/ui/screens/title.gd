extends Control
## Opening splash over the app's wooden backdrop (darkened): the title, byline, studio and the
## Python's copyright line fade in, hold and fade out on their own, then the main menu (first
## launch: How to play and the save-code question). A click or key skips ahead.

const FADE_IN := 1.2
const HOLD := 2.6
const FADE_OUT := 1.0
const BYLINE := "By Timothy Tang"
const STUDIO := "Developed with Seal Studios"
const SHADE := Color(0.04, 0.025, 0.015, 0.6)   # over App's Backdrop: the wood, darker
const CREAM := Color(0.957, 0.906, 0.788)

var args := {}
var _leaving := false
var _content: Control
var _sequence: Tween


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = SHADE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE   # clicks reach _gui_input (skip)
	add_child(bg)

	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)
	box.add_child(_line("Finite Dungeons", "TitleLabel", 160))
	box.add_child(_line(BYLINE, "", 40))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 70)
	box.add_child(gap)
	var studio := _line(STUDIO, "", 28)
	studio.add_theme_color_override("font_color", Color(CREAM, 0.7))
	box.add_child(studio)

	var copyright := _line(Content.TITLE_LINES[1], "", 20)
	copyright.add_theme_color_override("font_color", Color(CREAM, 0.5))
	copyright.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	copyright.grow_horizontal = Control.GROW_DIRECTION_BOTH
	copyright.grow_vertical = Control.GROW_DIRECTION_BEGIN
	copyright.offset_bottom = -44
	_content.add_child(copyright)

	_content.modulate.a = 0.0
	_sequence = create_tween()
	_sequence.tween_property(_content, "modulate:a", 1.0, FADE_IN).set_trans(Tween.TRANS_SINE)
	_sequence.tween_interval(HOLD)
	_sequence.tween_property(_content, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_SINE)
	_sequence.tween_callback(_continue)


func _line(text: String, variation: String, size: int) -> Label:
	var l := UIKit.label(text, variation, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if variation == "":
		l.add_theme_color_override("font_color", CREAM)
	return l


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_continue()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode != KEY_F11:
		_continue()


## Android's Back (App.back) skips ahead too.
func back() -> void:
	_continue()


func _continue() -> void:
	if _leaving:
		return
	_leaving = true
	if _sequence != null and _sequence.is_valid():
		_sequence.kill()
	if GameState.first_launch:
		App.instance.go_to("how_to_play", {"first": true})
	else:
		App.instance.go_to("main_menu")
