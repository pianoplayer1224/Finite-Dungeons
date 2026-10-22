class_name StatTiles
extends HBoxContainer
## A row of equal stat tiles (name, big value, optional small line under it) that spans its
## container's width, so it lines up with a full-width HP bar above it. Camp's You and Next
## Monster panels.

const GAP := 10


func _init() -> void:
	add_theme_constant_override("separation", GAP)


## One tile per call, left to right.
func add_tile(stat_name: String, value: String, sub := "", value_size := 30) -> StatTiles:
	var tile := PanelContainer.new()
	tile.theme_type_variation = &"InsetPanel"
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	tile.add_child(box)
	var n := UIKit.label(stat_name, "BoldLabel", 15)
	n.add_theme_color_override("font_color", UIKit.INK_SOFT)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(n)
	var v := UIKit.label(value, "BoldLabel", value_size)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(v)
	if sub != "":
		var s := UIKit.label(sub, "SoftLabel", 16)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
	add_child(tile)
	return self


## A player stat as the Python's stat_line() shows it: the total, and "base + bonus" under it
## when something adds to it (the RAY-24 drone, Meowton's lawsuit).
func add_stat(stat_name: String, base: int, total: int) -> StatTiles:
	var extra := total - base
	if extra > 0:
		return add_tile(stat_name, str(total), "%d + %d" % [base, extra])
	return add_tile(stat_name, str(base))
