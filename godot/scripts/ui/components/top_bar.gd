class_name TopBar
extends PanelContainer
## The run's top bar on Camp and Battle: level and money on the left, the rotating splash
## text centred on the screen, relic/artefact icons (hover, or tap in touch mode, for descriptions)
## and options on the right.
## HP and ATK/DEF/SPD live with the fighter they belong to (Camp's You panel, Battle's plates).
## Camp shows live money; Battle drives it from event payloads.

signal options_pressed

var _level: Label
var _money: Label
var _icons: HBoxContainer
var _left: Control         # level + money
var _right: Control        # icons + options
var _left_slot: HBoxContainer
var _right_slot: HBoxContainer
var _clear: MarginContainer   # keeps the contents clear of a phone's camera cutout (keep_clear)


func _init() -> void:
	theme_type_variation = &"TopBar"
	custom_minimum_size = Vector2(0, 74)
	_clear = MarginContainer.new()
	add_child(_clear)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	_clear.add_child(row)

	# The splash text is centred on the screen, not just in the gap between the two sides: both
	# side slots are kept as wide as the wider side (_balance), the left side's content flush left
	# and the right side's flush right.
	_left_slot = HBoxContainer.new()
	row.add_child(_left_slot)
	var inset := MarginContainer.new()
	inset.add_theme_constant_override("margin_left", 8)
	_left_slot.add_child(inset)
	# Level and money sit close together; the fixed widths ("Level 30 / 30", a few digits of
	# money) keep the bar from shifting as they change.
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 18)
	inset.add_child(left)
	_level = UIKit.label("", "TopBarLabel", 28)
	_level.custom_minimum_size = Vector2(172, 0)
	left.add_child(_level)
	_money = UIKit.label("", "TopBarLabel", 28)
	_money.add_theme_color_override("font_color", Color(0.99, 0.84, 0.43))
	_money.custom_minimum_size = Vector2(170, 0)
	left.add_child(_money)
	_left = inset

	row.add_child(SplashText.new())

	_right_slot = HBoxContainer.new()
	_right_slot.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(_right_slot)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 30)
	_right_slot.add_child(right)
	_right = right

	_icons = HBoxContainer.new()
	_icons.add_theme_constant_override("separation", 6)
	right.add_child(_icons)

	var options := Button.new()
	options.text = "⚙"
	UIKit.hover_tip(options, "Options (Esc)")
	options.custom_minimum_size = Vector2(58, 0)
	options.add_theme_font_size_override("font_size", 28)
	options.focus_mode = Control.FOCUS_NONE
	options.pressed.connect(func() -> void: options_pressed.emit())
	right.add_child(options)

	_left.minimum_size_changed.connect(_balance)
	_right.minimum_size_changed.connect(_balance)


## Move the contents in from the screen's edges by a camera cutout's inset (App.safe_inset); the
## bar itself still spans the screen.
func keep_clear(inset: Vector2) -> void:
	UIKit.keep_clear(_clear, inset)


## Give both side slots the wider side's width, so the splash text between them stays centred
## whatever the relics/artefact take up.
func _balance() -> void:
	var w := maxf(_left.get_combined_minimum_size().x, _right.get_combined_minimum_size().x)
	_left_slot.custom_minimum_size.x = w
	_right_slot.custom_minimum_size.x = w


func show_player(player: PlayerState, level: int) -> void:
	set_level(level)
	set_money(player.money)
	_show_icons(player)


func set_level(level: int) -> void:
	_level.text = "Level %d / %d" % [level, Values.FINAL_LEVEL]


func set_money(m: float) -> void:
	_money.text = "💰 " + UIKit.fmt_money(m)


func money_label() -> Control:
	return _money


func _show_icons(player: PlayerState) -> void:
	UIKit.clear_children(_icons)
	var relics: Array = player.relics if not player.relics.is_empty() else ([player.relic] if player.relic != "" else [])
	for r: String in relics:
		var icon := UIKit.icon_rect(r, 54)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		var active := r == player.relic
		UIKit.rich_tooltip(icon, UIKit.desc_bbcode(Content.RELIC_DESCRIPTIONS.get(r, "")) + ("" if active or relics.size() == 1 else "\n(packed in the Carrier of Legend)"))
		if not active:
			icon.modulate = Color(1, 1, 1, 0.35)
		_icons.add_child(icon)
	if player.artefact != "":
		var sep := VSeparator.new()
		sep.custom_minimum_size = Vector2(0, 34)
		sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icons.add_child(sep)
		var art := UIKit.icon_rect(player.artefact, 54)
		art.mouse_filter = Control.MOUSE_FILTER_PASS
		UIKit.rich_tooltip(art, UIKit.desc_bbcode(Content.ARTEFACT_DESCRIPTIONS.get(player.artefact, "")))
		_icons.add_child(art)
