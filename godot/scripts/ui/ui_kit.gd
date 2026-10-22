class_name UIKit
extends RefCounted
## Shared UI helpers: icons, palette, money formatting, log-line BBCode, small node builders.

const ICON_DIR := "res://assets/itemIcons/"
const RICH_TOOLTIP := preload("res://scripts/ui/components/rich_tooltip.gd")

## Relic / artefact / shop-item key -> icon file (PORT_PLAN.md §6).
const ICON_FILES := {
	"family": "PictureFamily", "blessed": "BlessedEmblem", "forbidden": "ForbiddenBook",
	"e-sword": "ESword", "bk": "KFCBronze", "sk": "KFCSilver", "yd": "RAY24", "gk": "KFCGold",
	"meowton": "MewtonSuit", "dk": "KFCDiamond",
	"devotion": "DamnedProof", "socks": "CursedSock", "ar": "AbyssalOath",
	"coinpot": "AlchemistCoinpot", "carrier": "CarrierLegend", "vitality": "HeartExcessive",
	"sword": "Sword", "shield": "Shield", "boots": "Boots", "chicken": "Chicken",
	"book_atk": "BookAttack", "book_def": "BookDefence", "book_spd": "BookSpeed",
	"book_hp": "BookMaxhp", "book_heal": "BookHeal", "elixir": "Elixir", "ink": "Ink",
	"yds": "RAY24", "battery": "Battery", "book": "Book",
}

# UI chrome colours (log text uses Values.TEXT_COLOURS instead).
const INK := Color(0.169, 0.129, 0.094)
const INK_SOFT := Color(0.42, 0.341, 0.255)
const PARCHMENT := Color(0.953, 0.906, 0.788)
const PARCHMENT_LIGHT := Color(0.984, 0.961, 0.902)
const ACCENT := Color(0.478, 0.18, 0.102)
const GOLD := Color(0.65, 0.49, 0.0)
const HP_RED := Color(0.729, 0.208, 0.18)
const CREAM := Color(0.957, 0.906, 0.788)

static var _icons := {}


static func icon(key: String) -> Texture2D:
	if not ICON_FILES.has(key):
		return null
	if not _icons.has(key):
		_icons[key] = load(ICON_DIR + ICON_FILES[key] + ".png")
	return _icons[key]


## Display name of a relic or artefact key.
static func item_name(key: String) -> String:
	if Content.RELIC_NAMES.has(key):
		return Content.RELIC_NAMES[key]
	for entry: Dictionary in Content.LIBRARY:
		if entry["key"] == key:
			return entry["name"]
	return key


static func is_relic(key: String) -> bool:
	return Content.RELIC_NAMES.has(key)


## Money for the GUI: whole numbers as "4", decimals only when fractional (owner decision).
static func fmt_money(m: float) -> String:
	if is_equal_approx(m, roundf(m)):
		return "%d" % roundi(m)
	return "%.2f" % m


## Colour of a text kind ("good", "bad", ...), honouring the coloured-text setting.
## "muted" stays grey either way, like the Python's GREY.
static func kind_colour(kind: String, colours_on: bool) -> Color:
	if kind == "muted" or (colours_on and Values.TEXT_COLOURS.has(kind)):
		var rgb: Array = Values.TEXT_COLOURS.get(kind, [43, 33, 24])
		return Color8(rgb[0], rgb[1], rgb[2])
	return INK


static func bb_escape(text: String) -> String:
	return text.replace("[", "[lb]")


static func bb_colour(text: String, colour: Color) -> String:
	return "[color=#%s]%s[/color]" % [colour.to_html(false), bb_escape(text)]


## A relic or artefact description (Content.*_DESCRIPTIONS: "Name - text") as BBCode: the name
## in bold, the rest plain. The text itself is unchanged.
static func desc_bbcode(desc: String) -> String:
	var at := desc.find(" - ")  # the first one ends the name ("RAY-24 Drone - ...")
	if at <= 0:
		return bb_escape(desc)
	return "[b]%s[/b]%s" % [bb_escape(desc.left(at)), bb_escape(desc.substr(at))]


## Touch mode: a phone or tablet (Android, or a phone or tablet browser), or `-- --touch` on the
## command line to try it on a PC. A touch screen has no hover, so tapping a rich_tooltip()
## control shows its text in a bubble (App.show_info), plain hover tips are left off and keyboard
## hints are hidden. Everything else is the same game.
static var touch := _touch_device()
## How far a finger may move and still tap; further is a scroll. The same as the project's
## gui/common/default_scroll_deadzone, past which a list's drag cancels a button's press.
const TAP_SLOP := 16.0

## Phone layout: touch mode on a screen whose short side is under 600 dp (Android's own line
## between phones and tablets), or `-- --phone` on a PC (which implies --touch). The canvas is
## PHONE_SIZE instead of 1920 x 1080, so on a typical phone everything is drawn 1.5x bigger,
## the screens switch to their compact layouts and no text is smaller than PHONE_MIN_TEXT
## (secondary text, the forecast and the logs, is drawn smaller there so less of it scrolls).
## Tablets and PCs keep the normal layout. A phone layout must fit PHONE_SIZE; on the usual
## 19.5:9 to 20:9 phones the canvas is wider (1560-1600 x 720), and the spare width is what a
## camera cutout's inset (App.apply_safe_area) takes, so the scale stays 1.5x there.
static var phone := _phone_device()
const PHONE_SIZE := Vector2i(1440, 720)
const PHONE_MIN_TEXT := 16
## Phone layout: the size of running info text (the Next fight forecast, the player's notes, the
## fight logs, a fight's rewards), smaller than the rest so less of it needs scrolling.
const PHONE_INFO_TEXT := 16
## Phone layout: the least height of anything tapped (buttons, check boxes, sliders, text
## fields) and the least width of a button: about 7 mm on a phone, near Apple's 44 pt and
## Material's 48 dp minimum touch targets. App._touch_node applies it to every control.
const PHONE_TAP := 72.0
## A shorter tap height for small, side-by-side choices (battle speed, the shop's tabs, the main
## menu's buttons); set it with tap_height().
const PHONE_TAP_SMALL := 60.0


static func _touch_device() -> bool:
	if "--touch" in OS.get_cmdline_user_args() or "--phone" in OS.get_cmdline_user_args():
		return true
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return OS.has_feature("web_macos") and DisplayServer.is_touchscreen_available()  # an iPad's browser says it is a Mac


static func _phone_device() -> bool:
	if "--phone" in OS.get_cmdline_user_args():
		return true
	if not touch:
		return false
	var short_side := 0.0   # in dp (Android), points (iOS) or CSS pixels (a browser)
	if OS.has_feature("web"):
		var css: Variant = JavaScriptBridge.eval("Math.min(screen.width, screen.height)", true)
		short_side = float(css) if css != null else 0.0
	else:
		var size := DisplayServer.screen_get_size()
		short_side = mini(size.x, size.y) / DisplayServer.screen_get_scale()
	return short_side > 0.0 and short_side < 600.0


## A font size for text: in the phone layout, never under PHONE_MIN_TEXT.
static func text_size(size: int) -> int:
	return maxi(size, PHONE_MIN_TEXT) if phone else size


## Keep a screen's content clear of a phone's camera cutout: move it in from the screen's edges
## by `inset` (App.safe_inset, the same on both sides), while the screen's backgrounds still
## reach the edges. A MarginContainer gets that much more margin; any other control moves in on
## each side it is anchored to (stretched: both sides in; pinned to one edge: shifted off it;
## centred: left alone). Its own margins or offsets are kept in meta, so this can run again when
## the inset changes. Screens call it from their keep_clear(inset), which App calls.
static func keep_clear(c: Control, inset: Vector2) -> void:
	var m := c as MarginContainer
	if m != null:
		var sides := ["margin_left", "margin_top", "margin_right", "margin_bottom"]
		var base: Array = c.get_meta(&"_clear_base", sides.map(func(n: String) -> int: return m.get_theme_constant(n)))
		c.set_meta(&"_clear_base", base)
		var add := [inset.x, inset.y, inset.x, inset.y]
		for i in 4:
			m.add_theme_constant_override(sides[i], base[i] + ceili(add[i]))
		return
	var base: Array = c.get_meta(&"_clear_base", [c.offset_left, c.offset_top, c.offset_right, c.offset_bottom])
	c.set_meta(&"_clear_base", base)
	var dx := _clear_shift(c.anchor_left, c.anchor_right, inset.x)
	var dy := _clear_shift(c.anchor_top, c.anchor_bottom, inset.y)
	c.offset_left = base[0] + dx.x
	c.offset_right = base[2] + dx.y
	c.offset_top = base[1] + dy.x
	c.offset_bottom = base[3] + dy.y


## How far keep_clear moves a control's two offsets along one axis: (start side, end side).
static func _clear_shift(anchor_from: float, anchor_to: float, inset: float) -> Vector2:
	if not is_equal_approx(anchor_from, anchor_to):
		return Vector2(inset, -inset)   # stretched: in from both edges
	if anchor_from < 0.5:
		return Vector2(inset, inset)    # pinned to the start edge
	if anchor_from > 0.5:
		return Vector2(-inset, -inset)  # pinned to the end edge
	return Vector2.ZERO                 # centred


## Give a control a BBCode tooltip (Godot's own tooltips are plain text); in touch mode a tap
## shows it instead. The control must not have a script of its own: this puts one on it.
static func rich_tooltip(control: Control, bbcode: String) -> void:
	control.set_script(RICH_TOOLTIP)
	control.tooltip_text = bbcode


## In the phone layout, give a control its own tap height in place of PHONE_TAP (it keeps
## PHONE_TAP as its least width). Works before or after it enters the tree.
static func tap_height(c: Control, height: float) -> void:
	if not phone:
		return
	c.set_meta(&"tap_height", height)
	c.custom_minimum_size.y = height


## A plain tooltip for mouse users. It is left off in touch mode, where it could only pop up
## under a finger resting after a scroll.
static func hover_tip(control: Control, text: String) -> void:
	control.tooltip_text = "" if touch else text


## A BBCode tooltip's text, laid out like Godot's own tooltip label (one line per text line, the
## TooltipLabel font, size and colour, taken from `themed`'s theme).
static func tooltip_label(themed: Control, bbcode: String) -> RichTextLabel:
	var size := themed.get_theme_font_size("font_size", "TooltipLabel")
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", themed.get_theme_font("font", "TooltipLabel"))
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_font_size_override("bold_font_size", size)
	label.add_theme_color_override("default_color", themed.get_theme_color("font_color", "TooltipLabel"))
	label.text = bbcode
	return label


## Event lines ready for a log: the Python's leading/trailing blank lines trimmed.
static func event_lines(ev: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for text in EventText.format_event(ev):
		var t: String = text.strip_edges(true, true)
		if t != "":
			out.append(t)
	return out


static func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


static func icon_rect(key: String, size: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(key)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func label(text: String, variation: String = "", size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", text_size(size))
	return l


static func rich(bbcode: String = "", fit := true) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = fit
	r.scroll_active = not fit
	r.text = bbcode
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


## A label that drifts up and fades out (damage numbers, "+1 ATK"). parent must not be a
## container, since the label is positioned freely; at is in parent coordinates.
static func float_text(parent: Control, text: String, colour: Color, at: Vector2, size := 30, rise := 80.0, seconds := 1.1) -> void:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"BoldLabel"
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.03, 0.85))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 50
	parent.add_child(l)
	l.position = at - Vector2(l.get_minimum_size().x / 2.0, 0)
	var t := l.create_tween().set_parallel()
	t.tween_property(l, "position:y", l.position.y - rise, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, seconds * 0.6).set_delay(seconds * 0.4)
	t.chain().tween_callback(l.queue_free)


## Where a control's centre is, in another control's coordinates.
static func centre_in(node: Control, space: Control) -> Vector2:
	return space.get_global_transform().affine_inverse() * (node.global_position + node.size / 2.0)


## Wait until containers have laid out nodes added this frame. One process_frame is not enough:
## a click is handled before the frame's process_frame signal but the deferred container sort
## runs after it, so without a physics tick in between (high-refresh displays) a rebuilt card is
## still at (0, 0) when a single await resumes.
static func await_layout(tree: SceneTree) -> void:
	await tree.process_frame
	await tree.process_frame


## Wiggle a control sideways ("no"). Safe to call again mid-shake (fast clicks): the running
## shake is cut and the control put back at its resting x first, and a container child is
## re-laid out afterwards, so it can never drift onto a neighbour.
static func shake(node: Control, strength := 10.0) -> void:
	var running: Tween = node.get_meta(&"_shake_tween") if node.has_meta(&"_shake_tween") else null
	if running != null and running.is_valid():
		running.kill()
		node.position.x = node.get_meta(&"_shake_x")
	var x := node.position.x
	node.set_meta(&"_shake_x", x)
	var t := node.create_tween()
	node.set_meta(&"_shake_tween", t)
	for i in 4:
		t.tween_property(node, "position:x", x + (strength if i % 2 == 0 else -strength), 0.04)
	t.tween_property(node, "position:x", x, 0.04)
	t.tween_callback(func() -> void:
		var parent := node.get_parent()
		if parent is Container:
			(parent as Container).queue_sort())


## A quick grow-and-settle ("yes"). Restarts cleanly if called again mid-pulse.
static func pulse(node: Control, scale_to := 1.08) -> void:
	if node.has_meta(&"_pulse_tween"):
		(node.get_meta(&"_pulse_tween") as Tween).kill()
	node.pivot_offset = node.size / 2.0
	node.scale = Vector2.ONE
	var t := node.create_tween()
	node.set_meta(&"_pulse_tween", t)
	t.tween_property(node, "scale", Vector2(scale_to, scale_to), 0.08)
	t.tween_property(node, "scale", Vector2.ONE, 0.14)


## The Python's menu number, small in a button's upper-left corner (shown when the
## "original menu numbers" option is on). The button must not be a container.
static func corner_number(button: Control, text: String) -> Label:
	var l := label(text, "BoldLabel", 16)
	l.position = Vector2(6, 2)
	l.add_theme_color_override("font_color", ACCENT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(l)
	return l


## A full-width HP bar with its numbers written inside ("HP  10 / 10" with a prefix).
static func hp_bar(hp: int, max_hp: int, prefix := "", height := 36, font_size := 22) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.theme_type_variation = &"HPBar"
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.max_value = maxi(max_hp, 1)
	bar.value = clampi(hp, 0, maxi(max_hp, 1))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(("%s  " % prefix if prefix != "" else "") + "%d / %d" % [hp, max_hp], "TopBarLabel", font_size)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 5)
	bar.add_child(l)
	return bar


static var _greyed: ShaderMaterial


## Grey a control out (greyscale and faded), e.g. a locked relic icon.
static func greyed(node: CanvasItem) -> void:
	if _greyed == null:
		_greyed = ShaderMaterial.new()
		_greyed.shader = load("res://assets/ui/greyscale.gdshader")
	node.material = _greyed


## Make every descendant ignore the mouse so clicks reach the owning button.
static func mouse_through(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		mouse_through(child)
