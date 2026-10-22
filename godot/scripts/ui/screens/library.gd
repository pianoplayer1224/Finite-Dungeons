extends Control
## Library: the Python's print_library() as a two-page book - an icon grid on the left page,
## the chosen entry (name, unlock label, text, muted flavour line) on the right. Locked
## entries still show their unlock level; the diamond card stays secret until unlocked.

const GRID_COLUMNS := 4
const PAGE_MARGIN := 64   # extra side margin on the entry page, inside the panel's own padding
## The phone layout (UIKit.phone) uses the full width: a wider grid page (five to a row), the
## entry page beside it with a smaller picture.
const PHONE_GRID_COLUMNS := 5
const PHONE_GRID_SHARE := 1.8   # the grid page's width, against the entry page's 1
const PHONE_PAGE_MARGIN := 24

var args := {}
var _icon: TextureRect
var _name: Label
var _unlock: Label
var _body: RichTextLabel
var _flavour: Label
var _row: HBoxContainer


func _ready() -> void:
	var row := HBoxContainer.new()
	_row = row
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var side := 24 if UIKit.phone else 90
	var ends := 24 if UIKit.phone else 50
	row.offset_left = side
	row.offset_top = ends
	row.offset_right = -side
	row.offset_bottom = -ends
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	# Left page: the grid.
	var left := PanelContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if UIKit.phone:
		left.size_flags_stretch_ratio = PHONE_GRID_SHARE
	row.add_child(left)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 12)
	left.add_child(lbox)
	lbox.add_child(UIKit.label("Library", "HeaderLabel"))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lbox.add_child(scroll)
	var sections := VBoxContainer.new()
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 10)
	scroll.add_child(sections)
	var group := ButtonGroup.new()
	var first: ItemCard = null
	for kind: String in ["relic", "artefact"]:
		# Heading + grid as one block centred on the page, so the heading lines up with the tiles.
		var block := VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		block.add_theme_constant_override("separation", 10)
		sections.add_child(block)
		block.add_child(UIKit.label("Relics" if kind == "relic" else "Artefacts", "SectionLabel"))
		var grid := GridContainer.new()
		grid.columns = PHONE_GRID_COLUMNS if UIKit.phone else GRID_COLUMNS
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		block.add_child(grid)
		for entry: Dictionary in Content.LIBRARY:
			if entry["kind"] != kind:
				continue
			var shown := Content.library_entry(entry, GameState.profile.highest)
			var locked: bool = GameState.profile.highest < Content.UNLOCK_LEVEL[entry["key"]]
			var card := ItemCard.new().setup(entry["key"], shown["name"], "", locked, shown.get("secret", false)).set_compact()
			card.custom_minimum_size = Vector2(160, 168)
			card.button_group = group
			card.pressed.connect(_show.bind(entry))  # on click only, not on hover
			grid.add_child(card)
			if first == null:
				first = card
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(200, 0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func() -> void: App.instance.go_to("main_menu"))
	lbox.add_child(back)

	# Right page: the entry.
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PHONE_PAGE_MARGIN if UIKit.phone else PAGE_MARGIN)
	margin.add_theme_constant_override("margin_right", PHONE_PAGE_MARGIN if UIKit.phone else PAGE_MARGIN)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	right.add_child(margin)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", 14)
	margin.add_child(rbox)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(0, 160 if UIKit.phone else 256)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rbox.add_child(_icon)
	_name = UIKit.label("", "HeaderLabel", 44)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rbox.add_child(_name)
	_unlock = UIKit.label("", "", 21)
	_unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock.add_theme_color_override("font_color", UIKit.kind_colour("muted", true))
	rbox.add_child(_unlock)
	rbox.add_child(HSeparator.new())
	_body = UIKit.rich("")
	_body.add_theme_font_size_override("normal_font_size", 26)
	rbox.add_child(_body)
	_flavour = UIKit.label("", "", 22)
	_flavour.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavour.add_theme_color_override("font_color", UIKit.kind_colour("muted", true))
	rbox.add_child(_flavour)

	if first != null:
		first.set_pressed_no_signal(true)
		first.grab_focus.call_deferred(true)
		_show(Content.LIBRARY[0])


func _show(entry: Dictionary) -> void:
	var shown := Content.library_entry(entry, GameState.profile.highest)
	var locked: bool = GameState.profile.highest < Content.UNLOCK_LEVEL[entry["key"]]
	_icon.texture = UIKit.icon(entry["key"])
	_icon.modulate = Color(0.1, 0.07, 0.05, 0.75) if shown.get("secret", false) else Color.WHITE
	_name.text = shown["name"]
	_unlock.text = (Content.unlock_label(entry["key"]) + ("" if locked else "  ✓")) if shown["labelled"] else ""
	_body.text = UIKit.bb_escape(shown["body"])
	_flavour.text = shown["flavour"]


## Content clear of a phone's camera cutout (App.safe_inset; see UIKit.keep_clear).
func keep_clear(inset: Vector2) -> void:
	UIKit.keep_clear(_row, inset)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		App.instance.go_to("main_menu")
