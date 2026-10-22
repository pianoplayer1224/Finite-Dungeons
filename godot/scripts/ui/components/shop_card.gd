class_name ShopCard
extends Button
## One shop row (ShopMenu.shop_rows) as a card: icon, name, effect, cost, stock. Greyed like
## the Python's shop_line(), but still clickable so the refusal text can be enjoyed. The
## tooltip (for the mouse; not in touch mode) is the Python's full shop line.

const BASE_HEIGHT := 142.0
const PAD := 8.0           # content inset on every side

var row := {}

var _box: HBoxContainer
var _icon: TextureRect
var _name: Label
var _effect: Label
var _cost: Label
var _left: Label
var _num: Label


func _init() -> void:
	theme_type_variation = &"CardButton"
	# 4 of these (plus ItemMargin, the room the pulse/shake feedback needs inside the clipping
	# scroll area) must fit the shop panel at the 1920 px base width; any wider and the camp
	# layout overflows and re-centres, shifting the whole screen when the Items tab shows.
	# The phone layout has 3, in a canvas as narrow as 1440 (UIKit.PHONE_SIZE).
	custom_minimum_size = Vector2(230 if UIKit.phone else 240, BASE_HEIGHT)
	focus_mode = Control.FOCUS_ALL
	var row_box := HBoxContainer.new()
	row_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row_box.offset_left = 10
	row_box.offset_top = PAD
	row_box.offset_right = -10
	row_box.offset_bottom = -PAD
	row_box.add_theme_constant_override("separation", 10)
	add_child(row_box)
	_box = row_box
	# The content is anchored, not laid out by a container, so the button cannot grow by itself:
	# when names/effects wrap to more lines, raise the card's height to fit (its grid row follows).
	row_box.minimum_size_changed.connect(_fit_height)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(84, 84)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row_box.add_child(_icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	row_box.add_child(text)
	_name = UIKit.label("", "BoldLabel", 20)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_name)
	_effect = UIKit.label("", "SoftLabel", 16)
	_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_child(_effect)
	var foot := HBoxContainer.new()
	text.add_child(foot)
	_cost = UIKit.label("", "BoldLabel", 20)
	_cost.add_theme_color_override("font_color", UIKit.GOLD)
	_cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_cost)
	_left = UIKit.label("", "SoftLabel", 17)
	foot.add_child(_left)
	_num = UIKit.corner_number(self, "")
	UIKit.mouse_through(self)


func _fit_height() -> void:
	var need := maxf(BASE_HEIGHT, _box.get_combined_minimum_size().y + 2.0 * PAD)
	if not is_equal_approx(need, custom_minimum_size.y):
		custom_minimum_size.y = need


func setup(p_row: Dictionary, show_number: bool) -> ShopCard:
	row = p_row
	_icon.texture = UIKit.icon(row["item"])
	_name.text = row["name"]
	_effect.text = row["effect"]
	if row["item"] == "yds":
		_cost.text = "Open ▶"
		_left.text = ""
	else:
		_cost.text = "💰 %d" % row["cost"]
		_left.text = "sealed" if not row["buyable"] else ("∞" if row["left"] < 0 else "%d left" % row["left"])
	_num.text = str(row["num"]) if show_number else ""
	UIKit.hover_tip(self, "%d %s" % [row["num"], row["text"]])  # the card already shows it all
	modulate = Color(1, 1, 1, 0.5) if row["greyed"] else Color.WHITE
	return self
