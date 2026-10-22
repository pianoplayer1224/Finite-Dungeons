class_name DroneTrackCard
extends PanelContainer
## One RAY-24 upgrade track (ShopMenu.drone_rows): name, a 4-pip stage bar, all four stage
## texts greyed by the Python's rule (stages beyond the next one are muted), and an Upgrade
## button. The pip bar sits outside the button: it reports state, it is not an action.

signal upgrade_pressed(track: int)

const LEFT_WIDTH := 290
const TICK_WIDTH := 20

static var _stage_re := RegEx.create_from_string("^(Stage \\d+)(.*)$")

var track := 0
var upgrade: Button
var _pips: Array[Panel] = []


func setup(t: Dictionary, show_number: bool) -> DroneTrackCard:
	track = t["track"]
	theme_type_variation = &"InsetPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	add_child(row)

	# Fixed width (the title wraps) so every card's stage column starts at the same x.
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	var title_label := UIKit.label(t["name"], "SectionLabel", 22)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(title_label)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	for i in Values.DRONE_STAGES:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(48, 16)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.16, 0.11, 0.07)
		sb.bg_color = Color(0.87, 0.66, 0.17) if i < t["stage"] else Color(0.3, 0.24, 0.17)
		pip.add_theme_stylebox_override("panel", sb)
		pips.add_child(pip)
		_pips.append(pip)
	left.add_child(pips)
	left.add_child(UIKit.label("Stage %d / %d" % [t["stage"], Values.DRONE_STAGES], "SoftLabel", 18))

	var stages := VBoxContainer.new()
	stages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stages.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stages.add_theme_constant_override("separation", 3)
	row.add_child(stages)
	for st: Dictionary in t["stages"]:
		# A fixed tick column plus a wrapping label, so long stage texts wrap under themselves.
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		var tick := UIKit.label("✓" if st["stage"] <= t["stage"] else "", "BoldLabel", 16)
		tick.custom_minimum_size = Vector2(TICK_WIDTH, 0)
		tick.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tick.add_theme_color_override("font_color", UIKit.kind_colour("good", true))
		line.add_child(tick)
		var text := UIKit.rich(_stage_bbcode(st["text"], st["stage"] == t["stage"] + 1, st["greyed"]))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("normal_font_size", UIKit.text_size(16))
		text.add_theme_font_size_override("bold_font_size", UIKit.text_size(16))
		text.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(text)
		stages.add_child(line)

	upgrade = Button.new()
	upgrade.custom_minimum_size = Vector2(150, 0)
	upgrade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if t["next_cost"] < 0:
		upgrade.text = "Maxed"
	else:
		upgrade.text = "Upgrade\n💰 %d" % t["next_cost"]
	if show_number:
		UIKit.corner_number(upgrade, str(track + 1))
	upgrade.pressed.connect(func() -> void: upgrade_pressed.emit(track))
	row.add_child(upgrade)
	return self


## "Stage N" in bold on every line; the stage you can buy next is bold throughout, stages
## beyond it are muted (the Python's greying rule).
static func _stage_bbcode(line: String, is_next: bool, greyed: bool) -> String:
	var m := _stage_re.search(line)
	var head := m.get_string(1) if m else ""
	var rest := m.get_string(2) if m else line
	var body := ("[b]%s[/b]" % UIKit.bb_escape(head) if head != "" else "") \
			+ (("[b]%s[/b]" if is_next else "%s") % UIKit.bb_escape(rest))
	if greyed:
		body = "[color=#%s]%s[/color]" % [UIKit.kind_colour("muted", true).to_html(false), body]
	return body


## Flash the pips that just filled (free track-4 upgrades included).
func flash_new_stages(old_stage: int, new_stage: int) -> void:
	for i in range(old_stage, mini(new_stage, _pips.size())):
		UIKit.pulse(_pips[i], 1.35)
