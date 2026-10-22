extends Control
## Main menu: the Python's MAIN MENU (start run, achievements, library, credits, save codes,
## colours) plus a progress summary. Buttons are grouped play / collection / help / system on
## the left; Save code opens the one dialog for the Python's input/obtain code (and Reset
## progress). Colours moved into Options.

const ICON_SIZE := 64   # ten relics on one line inside the 760 px progress panel
const PHONE_ICON_SIZE := 52   # the same in the phone layout's 640 px panel

var args := {}

@onready var _body: VBoxContainer = %Body


func _ready() -> void:
	%StartRun.pressed.connect(func() -> void: App.instance.go_to("run_setup"))
	%Achievements.pressed.connect(func() -> void: App.instance.go_to("achievements"))
	%Library.pressed.connect(func() -> void: App.instance.go_to("library"))
	%Credits.pressed.connect(func() -> void: App.instance.go_to("credits"))
	%HowToPlay.pressed.connect(func() -> void: App.instance.go_to("how_to_play"))
	%SaveCode.pressed.connect(func() -> void: SaveCodeDialog.open(false))
	%Options.pressed.connect(func() -> void: OptionsDialog.open())
	%Quit.pressed.connect(GameState.quit_game)
	GameState.profile_changed.connect(_refresh)
	if UIKit.phone:
		_phone_layout()
	_refresh()
	%StartRun.grab_focus.call_deferred(true)


## The phone layout (UIKit.phone: a canvas of at least 1440 x 720): small margins, so title,
## menu and progress fit the height; a narrower menu of shorter buttons (they stretch to the
## progress panel's height) and a smaller progress panel (_refresh).
func _phone_layout() -> void:
	for side in ["left", "right"]:
		$Margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		$Margin.add_theme_constant_override("margin_" + side, 12)
	$Margin/Center/Column/Name.add_theme_font_size_override("font_size", 110)
	$Margin/Center/Column/Block.add_theme_constant_override("separation", 32)
	var menu: Control = $Margin/Center/Column/Block/Menu
	menu.custom_minimum_size.x = 480
	menu.add_theme_constant_override("separation", 10)
	for row in menu.get_children():
		if row is HBoxContainer:
			row.add_theme_constant_override("separation", 10)
	for b: Button in menu.find_children("*", "Button", true, false):
		var start := b == %StartRun
		UIKit.tap_height(b, UIKit.PHONE_TAP if start else UIKit.PHONE_TAP_SMALL)
		b.add_theme_font_size_override("font_size", 32 if start else 22)
	$Margin/Center/Column/Block/Profile.custom_minimum_size.x = 640
	_body.add_theme_constant_override("separation", 10)


## Content clear of a phone's camera cutout (App.safe_inset; see UIKit.keep_clear).
func keep_clear(inset: Vector2) -> void:
	UIKit.keep_clear($Margin, inset)


func _refresh() -> void:
	UIKit.clear_children(_body)
	var p := GameState.profile
	var phone := UIKit.phone
	_body.add_child(UIKit.label("Your progress", "HeaderLabel", 36 if phone else 0))

	var value_size := 24 if phone else 30
	_body.add_child(StatTiles.new().add_tile("Runs", str(p.runs), "", value_size) \
			.add_tile("Highest lv. beaten", "%d / %d" % [p.highest, Values.FINAL_LEVEL], "", value_size) \
			.add_tile("Achievements", "%d / %d" % [GameState.achievement_count(), Content.ACH_BIT_ORDER.size()], "", value_size))
	_body.add_child(_item_row("Relics", Values.RELIC_UNLOCKS, p.highest))
	_body.add_child(_item_row("Artefacts", Values.ARTEFACT_UNLOCKS, p.highest))



## Every relic (or artefact) on one line, in unlock order; locked ones greyed out with their
## unlock level in the tooltip. As in Run setup, the withheld E-Sword is not shown at all and
## the diamond card stays a dark "????????" silhouette until it is unlocked.
func _item_row(title: String, unlocks: Array, highest: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(UIKit.label(title, "SectionLabel", 22 if UIKit.phone else 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	for pair: Array in unlocks:
		var key: String = pair[0]
		var locked: bool = highest < pair[1]
		if locked and pair[1] > Values.FINAL_LEVEL:
			continue
		var icon := UIKit.icon_rect(key, PHONE_ICON_SIZE if UIKit.phone else ICON_SIZE)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		var tip := UIKit.item_name(key)
		if locked and key == "dk":
			icon.modulate = Color(0.1, 0.07, 0.05, 0.75)
			tip = "????????\n" + Content.unlock_label(key)
		elif locked:
			UIKit.greyed(icon)
			tip += "\n" + Content.unlock_label(key)
		UIKit.rich_tooltip(icon, UIKit.bb_escape(tip))   # a tap shows it in touch mode
		row.add_child(icon)
	return box
