class_name App
extends Control
## Boot scene root: swaps one screen at a time into ScreenHost and owns the overlay layers
## (toasts, modal dialogs, story cards, fades). Screens reach it through App.instance.
## Screens never hold run state; they read GameState.

const SCREENS := {
	"title": "res://scenes/screens/title.tscn",
	"main_menu": "res://scenes/screens/main_menu.tscn",
	"how_to_play": "res://scenes/screens/how_to_play.tscn",
	"run_setup": "res://scenes/screens/run_setup.tscn",
	"camp": "res://scenes/screens/camp.tscn",
	"battle": "res://scenes/screens/battle.tscn",
	"run_end": "res://scenes/screens/run_end.tscn",
	"achievements": "res://scenes/screens/achievements.tscn",
	"library": "res://scenes/screens/library.tscn",
	"credits": "res://scenes/screens/credits.tscn",
}
const FADE_SECONDS := 0.18
const TOAST_SECONDS := 3.5
const TOAST_ROOM := 400.0   # height of the toast column; the oldest toasts give way to new ones
const NAV_ACTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]
const INFO_WIDTH := 760.0   # a touch info bubble's longest line; longer text wraps

static var instance: App

var current: Control
var current_name := ""
var _switching := false
var _info_layer: CanvasLayer   # touch info bubbles, over dialogs and under fades
var _base_size: Vector2i       # the project's base size (1920 x 1080)
var _safe_seen := []           # [window size, safe area] last fitted
## How far screens keep their content in from each edge (canvas units, the same on both sides):
## a phone's camera cutout (apply_safe_area). Zero elsewhere.
var safe_inset := Vector2.ZERO

@onready var _host: Control = %ScreenHost
@onready var _toasts: VBoxContainer = %Toasts
@onready var _modal_host: Control = %ModalHost
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	instance = self
	GameState.achievement_unlocked.connect(_on_achievement_unlocked)
	_info_layer = CanvasLayer.new()
	_info_layer.layer = 15
	add_child(_info_layer)
	if UIKit.phone:
		get_window().content_scale_size = UIKit.PHONE_SIZE   # everything 1.5x bigger on a typical phone
	_base_size = get_window().content_scale_size
	if UIKit.touch:
		get_tree().node_added.connect(_touch_node)
	if OS.has_feature("mobile"):
		# The safe area can arrive after the first frame and change with the window, and
		# nothing reports it: look again now and then (it is cheap; unchanged does nothing).
		var poll := Timer.new()
		poll.wait_time = 1.0
		poll.timeout.connect(_fit_safe_area)
		add_child(poll)
		poll.start()
		get_tree().root.size_changed.connect(_fit_safe_area)
		_fit_safe_area.call_deferred()
	go_to("title", {}, false)


## Screens give their default button focus with the ring hidden (grab_focus(true)), and a mouse
## click focuses without one too, so no outline shows until the keyboard is used. The first
## arrow / Tab press then shows the ring where focus already is instead of moving it.
func _input(event: InputEvent) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null or owner.has_focus(true):
		return
	for action in NAV_ACTIONS:
		if event.is_action_pressed(action):
			owner.grab_focus()
			get_viewport().set_input_as_handled()
			return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		GameState.set_setting("fullscreen", not GameState.settings["fullscreen"])
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		back()


## Android's Back button. It closes what is on top: a touch info bubble, then a dialog (which
## gets its cancel answer: No, or simply closed). Otherwise it goes back on the screen: the
## screen's back() if it has one (Title, Run End), else its Esc (back a step, back to the menu,
## Options during a run). On the main menu it asks before quitting.
func back() -> void:
	if _switching:
		return
	if _info_layer.get_children().any(func(n: Node) -> bool: return not n.is_queued_for_deletion()):
		close_info()
		return
	var top := _top_modal()
	if top != null:
		top.dismiss()
	elif current_name == "main_menu":
		if await confirm("Quit Finite Dungeons?", "Quit", "Stay", "", true, true):
			GameState.quit_game()
	elif current.has_method("back"):
		current.call("back")
	else:
		for pressed: bool in [true, false]:
			var esc := InputEventAction.new()
			esc.action = &"ui_cancel"
			esc.pressed = pressed
			Input.parse_input_event(esc)


## Touch mode, for every node entering the tree. In the phone layout anything tapped gets at
## least UIKit.PHONE_TAP of height (a button that much width too). And inside a scrolling list,
## buttons, panels and text pass their touches on to the list too (Godot hands a list only the
## drags that reach it), so a finger that drags anywhere on it scrolls it; the list cancels a
## button's press once the drag passes its dead zone (gui/common/default_scroll_deadzone):
## scrolling the shop never buys anything. Sliders and text fields keep their own drags.
func _touch_node(node: Node) -> void:
	var c := node as Control
	if c == null:
		return
	if UIKit.phone:
		var tap: float = c.get_meta(&"tap_height", UIKit.PHONE_TAP)   # UIKit.tap_height
		if c is CheckBox or c is Slider or c is LineEdit:
			c.custom_minimum_size.y = maxf(c.custom_minimum_size.y, tap)
		elif c is BaseButton:
			c.custom_minimum_size = c.custom_minimum_size.max(Vector2(UIKit.PHONE_TAP, tap))
	if c.mouse_filter != Control.MOUSE_FILTER_STOP or _keeps_drags(c):
		return
	var up := c.get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	if up != null:
		c.mouse_filter = Control.MOUSE_FILTER_PASS


## Controls that use a drag themselves, so they keep it from a list around them.
static func _keeps_drags(c: Control) -> bool:
	return c is Slider or c is ScrollBar or c is SpinBox or c is LineEdit or c is TextEdit \
			or c is ScrollContainer or c is ItemList or c is Tree


# ---------------------------------------------------------------- phone screen edges

## Phones (Android, iOS): keep the screens' content and the toasts clear of a camera cutout,
## while backgrounds (the top bar, a vignette, the battle floor) still reach the screen's edges.
## The inset is the display's safe area, the same on both sides, so the layout stays centred
## whichever way up the phone is turned (the cutout changes sides, and nothing tells the game).
## Each screen applies it to its own content, in keep_clear(inset) (UIKit.keep_clear).
func _fit_safe_area() -> void:
	var window := get_window()
	var safe := Rect2(DisplayServer.get_display_safe_area())
	safe.position -= Vector2(window.position)
	var seen := [window.size, safe]
	if seen != _safe_seen:
		_safe_seen = seen
		apply_safe_area(Vector2(window.size), safe)


## Keep content clear of all but `safe` (in window pixels, of a window `size` pixels big). When
## the inset leaves less than the base size, the base grows to match (everything is drawn a
## little smaller), so a screen's content still gets the room it was laid out for.
func apply_safe_area(size: Vector2, safe: Rect2) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var inset := Vector2(maxf(safe.position.x, size.x - safe.end.x),
			maxf(safe.position.y, size.y - safe.end.y)).max(Vector2.ZERO)
	var base := Vector2(_base_size)
	var fit := minf(_fit(size.x, inset.x, base.x), _fit(size.y, inset.y, base.y))
	var content := _base_size
	if fit < minf(size.x / base.x, size.y / base.y):   # the base size alone would not fit
		content = Vector2i((size / fit).ceil())
	get_window().content_scale_size = content
	var scale := minf(size.x / content.x, size.y / content.y)   # Godot's (stretch aspect "expand")
	var units := (inset / scale).ceil()
	(_toasts.get_parent() as CanvasLayer).offset = Vector2(-units.x, units.y)
	if units != safe_inset:
		safe_inset = units
		if current != null and current.has_method("keep_clear"):
			current.call("keep_clear", safe_inset)


## The part of the screen clear of a camera cutout, in canvas units.
func safe_rect() -> Rect2:
	return Rect2(safe_inset, _host.size - 2.0 * safe_inset)


## Pixels per unit at which `base` units fit in `size` pixels less `inset` at both ends, with
## 2 units to spare for rounding the inset up.
static func _fit(size: float, inset: float, base: float) -> float:
	return size / base if inset <= 0.0 else (size - 2.0 * inset) / (base + 2.0)


# ---------------------------------------------------------------- screens

## Replace the current screen. args is assigned to the screen's `args` var before _ready.
func go_to(screen: String, args: Dictionary = {}, fade := true) -> void:
	if _switching:
		return
	_switching = true
	close_info()
	# Crossfades during the fade. The title splash (and a first launch's tutorial after it) is
	# silent: the music starts at the main menu.
	if screen == "battle":
		Music.play("encounter")
	elif screen == "main_menu" or Music.current != "":
		Music.play("woodland")
	if fade:
		await _tween_fade(1.0)
	close_all_modals()
	if current:
		_host.remove_child(current)
		current.queue_free()
	current = (load(SCREENS[screen]) as PackedScene).instantiate()
	current_name = screen
	if "args" in current:
		current.set("args", args)
	_host.add_child(current)
	if safe_inset != Vector2.ZERO and current.has_method("keep_clear"):
		current.call("keep_clear", safe_inset)
	if fade:
		await _tween_fade(0.0)
	_switching = false


func _tween_fade(alpha: float) -> void:
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var t := create_tween()
	t.tween_property(_fade, "color:a", alpha, FADE_SECONDS)
	await t.finished


# ---------------------------------------------------------------- toasts

func toast(text: String, kind := "normal", icon_key := "") -> void:
	if kind == "warning":  # every refusal shows one
		Sfx.play("clickFail")
	# The same message again (fast repeated clicks) brings that toast back and moves it to the
	# newest place instead of stacking copies of it.
	for shown: Control in _toasts.get_children():
		if not shown.is_queued_for_deletion() and shown.get_meta(&"text", "") == text:
			_toasts.move_child(shown, -1)
			_run_toast(shown)
			return
	var panel := PanelContainer.new()
	panel.set_meta(&"text", text)
	panel.theme_type_variation = &"InsetPanel"
	panel.custom_minimum_size = Vector2(420, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	if icon_key != "" and UIKit.icon(icon_key):
		row.add_child(UIKit.icon_rect(icon_key, 48))
	var body := UIKit.rich(UIKit.bb_colour(text, UIKit.kind_colour(kind, true)))
	body.custom_minimum_size = Vector2(340, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(body)
	_toasts.add_child(panel)
	panel.modulate.a = 0.0
	_run_toast(panel)
	_make_room(panel)


## Instantly dismiss the oldest toasts until the newest fits in TOAST_ROOM, so a new message is
## always shown in full. The column is in age order, so the ones already fading go first.
## Heights are only known once the column has laid the new toast out (its text wraps).
func _make_room(newest: Control) -> void:
	await UIKit.await_layout(get_tree())
	if not is_instance_valid(newest):
		return
	var sep := _toasts.get_theme_constant(&"separation")
	var live: Array[Control] = []
	var used := -float(sep)
	for shown: Control in _toasts.get_children():
		if not shown.is_queued_for_deletion():
			live.append(shown)
			used += shown.size.y + sep
	while used > TOAST_ROOM and live.size() > 1 and live[0] != newest:
		var oldest: Control = live.pop_front()
		used -= oldest.size.y + sep
		oldest.free()


## Fade a toast in (or back in), hold, fade out and free it. Restarts a running one.
func _run_toast(panel: Control) -> void:
	if panel.has_meta(&"_toast_tween"):
		(panel.get_meta(&"_toast_tween") as Tween).kill()
	var t := panel.create_tween()
	panel.set_meta(&"_toast_tween", t)
	t.tween_property(panel, "modulate:a", 1.0, 0.2)
	t.tween_interval(TOAST_SECONDS)
	t.tween_property(panel, "modulate:a", 0.0, 0.4)
	t.tween_callback(panel.queue_free)


func _on_achievement_unlocked(key: String) -> void:
	Sfx.play("unlock")
	for a: Array in Content.ACHIEVEMENT_DISPLAY:
		if a[0] == key:
			toast("Achievement unlocked: %s\n%s" % [a[1], a[2]], "good")


# ---------------------------------------------------------------- modals

class Modal extends Control:
	signal closed(result: Variant)
	## A tap outside this soon after opening is the opening tap's twin (a double tap), not a "no".
	const OUTSIDE_GRACE_MS := 250
	var cancel: Variant = null   # the result when it is dismissed (confirm: false)
	## What dismissing does (Back, or a tap outside): close with `cancel`, unless a dialog sets
	## its own (a story card first finishes typing, like its Continue).
	var on_dismiss := Callable()
	## What a tap outside the dialog does: dismiss, unless a dialog sets its own (the save code
	## dialog keeps a code being typed).
	var on_outside := Callable()
	var _opened_at := Time.get_ticks_msec()

	func dismiss() -> void:
		if on_dismiss.is_valid():
			on_dismiss.call()
		else:
			closed.emit(cancel)

	func outside() -> void:
		if Time.get_ticks_msec() - _opened_at < OUTSIDE_GRACE_MS:
			return
		if on_outside.is_valid():
			on_outside.call()
		else:
			dismiss()


## Show content centred over a dimmed screen. Await `modal.closed` for the result. A tap or
## click on the dimmed screen outside it dismisses it (Modal.outside).
func show_modal(content: Control, dim_alpha := 0.6) -> Modal:
	Sfx.play("popup")
	close_info()
	var modal := Modal.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.03, 0.02, dim_alpha)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			dim.accept_event()
			modal.outside())
	modal.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE   # around the dialog, clicks reach the dim
	modal.add_child(center)
	if UIKit.phone:
		center.add_child(_scrolling(content))
	else:
		center.add_child(content)
	_modal_host.add_child(modal)
	modal.modulate.a = 0.0
	modal.create_tween().tween_property(modal, "modulate:a", 1.0, 0.15)
	# Bound to the modal itself, not a lambda capturing it: close_all_modals frees it at once,
	# and a deferred call on a freed object is dropped quietly (a lambda's capture would error).
	modal.closed.connect(modal.queue_free.unbind(1), CONNECT_DEFERRED)
	return modal


## Phone layout: a dialog taller than the screen (Options) scrolls instead of running off it:
## all but its last row (its buttons: Close, OK, Yes / No), which stays in view under the rest.
## The scroll area keeps the rows' own height up to what the screen leaves, following them as
## they change (the save code's status line, a story card typing out). A dialog that is not a
## panel around one column of rows scrolls whole.
func _scrolling(content: Control) -> Control:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box: VBoxContainer = null
	if content is PanelContainer and content.get_child_count() == 1:
		box = content.get_child(0) as VBoxContainer
	if box == null or box.get_child_count() < 2:
		scroll.add_child(content)
		var fit_whole := func() -> void:
			var want := content.get_combined_minimum_size()
			scroll.custom_minimum_size = Vector2(want.x, minf(want.y, safe_rect().size.y - 24.0))
		content.minimum_size_changed.connect(fit_whole)
		fit_whole.call()
		return scroll
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", box.get_theme_constant("separation"))
	scroll.add_child(rows)
	var last: Control = box.get_child(box.get_child_count() - 1)
	for row in box.get_children():
		if row != last:
			row.reparent(rows)
	box.add_child(scroll)
	box.move_child(scroll, 0)
	var fit := func() -> void:
		var want := rows.get_combined_minimum_size()
		var others := content.get_combined_minimum_size().y - scroll.get_combined_minimum_size().y
		scroll.custom_minimum_size = Vector2(want.x, clampf(want.y, 0.0, safe_rect().size.y - 24.0 - others))
	rows.minimum_size_changed.connect(fit)
	last.minimum_size_changed.connect(fit)
	fit.call()
	return content


## Close every dialog. Each one reports its cancel result (null; a question's No), so code
## awaiting it resumes.
func close_all_modals() -> void:
	for m in _modal_host.get_children():
		if m is Modal and not m.is_queued_for_deletion():
			(m as Modal).closed.emit((m as Modal).cancel)
		m.queue_free()


func _top_modal() -> Modal:
	for i in range(_modal_host.get_child_count() - 1, -1, -1):
		var m := _modal_host.get_child(i)
		if m is Modal and not m.is_queued_for_deletion():
			return m
	return null


func has_modal() -> bool:
	for m in _modal_host.get_children():
		if not m.is_queued_for_deletion():
			return true
	return false


## Touch mode (UIKit.touch, no hover): show what a tooltip would, in a bubble by `source` (below
## it, or above when there is no room). The next tap anywhere only closes it, so it never
## presses what is under it. A screen change or a dialog opening closes it too.
func show_info(source: Control, bbcode: String) -> void:
	close_info()
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			close_info())
	_info_layer.add_child(catcher)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"TooltipPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate.a = 0.0   # until it is placed
	var label := UIKit.tooltip_label(self, bbcode)
	panel.add_child(label)
	catcher.add_child(panel)
	await UIKit.await_layout(get_tree())   # the text's size is known once laid out
	if not is_instance_valid(panel) or panel.is_queued_for_deletion():
		return
	if label.size.x > INFO_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = INFO_WIDTH
		await UIKit.await_layout(get_tree())
		if not is_instance_valid(panel) or panel.is_queued_for_deletion():
			return
		panel.reset_size()   # a control grows to its minimum size by itself, but never shrinks
	var area := safe_rect().grow(-12.0)
	var by := source.get_global_rect() if is_instance_valid(source) else Rect2(area.get_center(), Vector2.ZERO)
	var y := by.end.y + 8.0
	if y + panel.size.y > area.end.y:
		y = by.position.y - 8.0 - panel.size.y
	var x := clampf(by.get_center().x - panel.size.x / 2.0, area.position.x, area.end.x - panel.size.x)
	panel.position = Vector2(x, maxf(y, area.position.y))
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.12)


func close_info() -> void:
	for bubble in _info_layer.get_children():
		bubble.queue_free()


func _dialog_panel(width: int) -> Array:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	return [panel, box]


## A yes/no question; true for Yes. The highlighted (accent) button is Yes, or No when
## highlight_no (No is the safe answer), and it always sits on the right. No has focus either
## way, so Enter never confirms by accident. compact: a small box exactly as wide as its two
## buttons, the text wrapping to fit (short questions such as Leave dungeon's).
func confirm(text: String, yes := "Yes", no := "No", title := "", highlight_no := false, compact := false) -> bool:
	var button_w := 170 if compact else 150
	var parts := _dialog_panel(0 if compact else 760)
	var box: VBoxContainer = parts[1]
	if title != "":
		box.add_child(UIKit.label(title, "HeaderLabel"))
	var body := UIKit.rich(UIKit.bb_escape(text))
	body.custom_minimum_size = Vector2(button_w * 2 + 16 if compact else 700, 0)
	box.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	var no_btn := Button.new()
	no_btn.text = no
	var yes_btn := Button.new()
	yes_btn.text = yes
	var accent := no_btn if highlight_no else yes_btn
	var plain := yes_btn if highlight_no else no_btn
	accent.theme_type_variation = &"AccentButton"
	buttons.add_child(plain)
	buttons.add_child(accent)
	for b: Button in [plain, accent]:
		b.custom_minimum_size = Vector2(button_w, 0)
		if compact:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var modal := show_modal(parts[0])
	modal.cancel = false
	no_btn.pressed.connect(func() -> void: modal.closed.emit(false))
	yes_btn.pressed.connect(func() -> void: modal.closed.emit(true))
	no_btn.grab_focus.call_deferred(true)
	return await modal.closed


## A story scene: typewriter text on a parchment card; Continue (or Back, or a tap outside)
## finishes the typing, then dismisses it.
func story(text: String, title := "", kind := "story") -> void:
	var parts := _dialog_panel(1000)
	var box: VBoxContainer = parts[1]
	if title != "":
		box.add_child(UIKit.label(title, "HeaderLabel"))
	var body := UIKit.rich(UIKit.bb_colour(text.strip_edges(), UIKit.kind_colour(kind, GameState.settings["colours"])))
	body.custom_minimum_size = Vector2(940, 0)
	body.add_theme_font_size_override("normal_font_size", 25)
	body.visible_ratio = 0.0
	box.add_child(body)
	var cont := Button.new()
	cont.text = "Continue"
	cont.theme_type_variation = &"AccentButton"
	cont.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(cont)
	var modal := show_modal(parts[0])
	var chars := maxi(text.length(), 1)
	var typing := body.create_tween()
	typing.tween_property(body, "visible_ratio", 1.0, chars / 90.0)
	var advance := func() -> void:   # the first press finishes the typing, the next one closes
		if body.visible_ratio < 1.0:
			typing.kill()
			body.visible_ratio = 1.0
		else:
			modal.closed.emit(null)
	cont.pressed.connect(advance)
	modal.on_dismiss = advance   # Back and a tap outside too
	cont.grab_focus.call_deferred(true)
	await modal.closed


## A plain message with an OK button.
func message(text: String, title := "", ok := "OK") -> void:
	var parts := _dialog_panel(760)
	var box: VBoxContainer = parts[1]
	if title != "":
		box.add_child(UIKit.label(title, "HeaderLabel"))
	var body := UIKit.rich(UIKit.bb_escape(text))
	body.custom_minimum_size = Vector2(700, 0)
	box.add_child(body)
	var ok_btn := Button.new()
	ok_btn.text = ok
	ok_btn.theme_type_variation = &"AccentButton"
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(ok_btn)
	var modal := show_modal(parts[0])
	ok_btn.pressed.connect(func() -> void: modal.closed.emit(null))
	ok_btn.grab_focus.call_deferred(true)
	await modal.closed
