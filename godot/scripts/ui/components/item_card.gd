class_name ItemCard
extends Button
## A selectable card: icon, name, and a small subtitle. Used for relic/artefact picking and the
## library grid. Locked cards show a dark silhouette; secret ones hide the name too.

## The phone layout's cards (UIKit.phone): six to a row in Run setup, so every artefact (and
## every relic) is on screen at once; a smaller icon, and names may take three lines.
const PHONE_SIZE := Vector2(160, 190)
const PHONE_ICON := 64

var key := ""
var locked := false

var _icon: TextureRect
var _name: Label
var _sub: Label


func _init() -> void:
	theme_type_variation = &"CardButton"
	toggle_mode = true
	# Tall enough for a two-line name plus the two-line "(unlocks after beating lv. N)"; both
	# labels are capped at two lines (a phone's name at three) so nothing can spill out.
	custom_minimum_size = PHONE_SIZE if UIKit.phone else Vector2(196, 256)
	focus_mode = Control.FOCUS_ALL
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 8
	box.offset_top = 10
	box.offset_right = -8
	box.offset_bottom = -8
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(0, PHONE_ICON if UIKit.phone else 112)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_icon)
	_name = Label.new()
	_name.theme_type_variation = &"BoldLabel"
	_name.add_theme_font_size_override("font_size", 16 if UIKit.phone else 19)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = 3 if UIKit.phone else 2
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_name)
	_sub = Label.new()
	_sub.theme_type_variation = &"SoftLabel"
	_sub.add_theme_font_size_override("font_size", UIKit.text_size(16))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.max_lines_visible = 2
	_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_sub)


## key "" with no icon makes a "None" card.
func setup(p_key: String, title: String, subtitle := "", p_locked := false, secret := false) -> ItemCard:
	key = p_key
	locked = p_locked
	_icon.texture = UIKit.icon(p_key) if p_key != "" else null
	_name.text = "????????" if secret else title
	_sub.text = subtitle
	_icon.modulate = Color(0.1, 0.07, 0.05, 0.75) if p_locked else Color.WHITE
	if p_key == "":
		_icon.custom_minimum_size = Vector2(0, PHONE_ICON if UIKit.phone else 112)
		var none := Label.new()
		none.text = "—"
		none.add_theme_font_size_override("font_size", 48 if UIKit.phone else 64)
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		none.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		none.mouse_filter = Control.MOUSE_FILTER_IGNORE
		none.add_theme_color_override("font_color", UIKit.INK_SOFT)
		_icon.add_child(none)
	return self


## Smaller icon and name, for dense grids (the library).
func set_compact() -> ItemCard:
	_icon.custom_minimum_size = Vector2(0, 78)
	_name.add_theme_font_size_override("font_size", UIKit.text_size(16))
	return self


func set_subtitle(text: String) -> void:
	_sub.text = text
