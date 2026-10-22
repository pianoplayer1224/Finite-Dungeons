extends Control
## Credits: the Python's print_credits() text as a centred film-style roll over the wooden
## backdrop (no panel). It scrolls up by itself and loops; the mouse wheel nudges it, and a
## finger (or the mouse) drags it, with a flick's momentum after; it fades in and out at the
## top and bottom edges. Text is verbatim from Content.

const SPEED := 55.0          # px per second
const WHEEL_STEP := 90.0
const FLING_DECAY := 1600.0  # px per second, per second: how fast a flick slows to the roll's own pace
const WIDTH := 1100.0
const EDGE_FADE := 170.0     # height of the top/bottom fades
const SHADE := Color(0.04, 0.025, 0.015, 0.45)
const CREAM := Color(0.957, 0.906, 0.788)
const GOLD := Color(0.99, 0.84, 0.43)

var args := {}
var _roll: VBoxContainer
var _y := 0.0
var _back: Button
var _dragging := false
var _fling := 0.0   # px per second left over from a flick


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = SHADE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var clip := Control.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	_roll = VBoxContainer.new()
	_roll.custom_minimum_size = Vector2(WIDTH, 0)
	_roll.add_theme_constant_override("separation", 30)
	_roll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_roll)
	_build()

	for top: bool in [true, false]:
		add_child(_edge_fade(top))

	var back := Button.new()
	_back = back
	back.text = "Back"
	back.custom_minimum_size = Vector2(220, 60)
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	back.grow_vertical = Control.GROW_DIRECTION_BEGIN
	back.offset_right = -40
	back.offset_bottom = -36
	back.pressed.connect(_on_back)
	add_child(back)
	back.grab_focus.call_deferred(true)

	_y = size.y if size.y > 0.0 else 1080.0  # start just below the screen


func _build() -> void:
	# CREDITS_HEADING is "CREDITS\n\n<thanks line>": the first line becomes the big title.
	var heading := Content.CREDITS_HEADING.split("\n", false)
	_roll.add_child(_line(heading[0].capitalize(), "TitleLabel", 110, CREAM))
	for i in range(1, heading.size()):
		_roll.add_child(_line(heading[i], "", 28, CREAM))
	_roll.add_child(_spacer(40))
	for entry: String in Content.CREDITS:
		var text := entry.strip_edges()
		if text.begins_with("---") and text.ends_with("---"):
			_roll.add_child(_spacer(30))
			_roll.add_child(_line(text.trim_prefix("---").trim_suffix("---").to_upper(), "BoldLabel", 30, GOLD))
		else:
			_roll.add_child(_line(text, "", 26, CREAM))


func _line(text: String, variation: String, size: int, colour: Color) -> Label:
	var l := UIKit.label(text, variation, size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH, 0)
	if variation != "TitleLabel":
		l.add_theme_color_override("font_color", colour)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _spacer(height: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## A strip that fades the roll out against the backdrop at the top or bottom edge.
func _edge_fade(top: bool) -> TextureRect:
	var g := Gradient.new()
	var dark := Color(0.05, 0.03, 0.02, 0.85)
	g.set_color(0, dark if top else Color(dark, 0.0))
	g.set_color(1, Color(dark, 0.0) if top else dark)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 64
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		r.offset_bottom = EDGE_FADE
	else:
		r.offset_top = -EDGE_FADE
	return r


func _process(delta: float) -> void:
	if not _dragging:   # a finger holding the roll stops it
		_y -= SPEED * delta
		_y += _fling * delta
		_fling = move_toward(_fling, 0.0, FLING_DECAY * delta)
	_place()


func _place() -> void:
	var h := _roll.get_combined_minimum_size().y
	if _y < -h:            # fully off the top: start again from the bottom
		_y = size.y
	elif _y > size.y:      # wheeled back past the start
		_y = size.y
	_roll.position = Vector2((size.x - WIDTH) / 2.0, _y)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton   # a touch arrives as an emulated mouse click
	if click != null:
		if click.button_index == MOUSE_BUTTON_LEFT:
			_dragging = click.pressed
			if click.pressed:
				_fling = 0.0
		elif click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_UP:
			_y += WHEEL_STEP
		elif click.pressed and click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_y -= WHEEL_STEP
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_y += motion.relative.y
		_fling = motion.velocity.y   # what is left of it when the finger lets go
		accept_event()


## The Back button clear of a phone's camera cutout (App.safe_inset; see UIKit.keep_clear); the
## shade and the edge fades still span the screen, and the roll is centred.
func keep_clear(inset: Vector2) -> void:
	UIKit.keep_clear(_back, inset)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


func _on_back() -> void:
	App.instance.go_to("main_menu")
