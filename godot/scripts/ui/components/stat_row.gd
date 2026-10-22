class_name StatRow
extends HBoxContainer
## Battle: ATK / DEF / SPD in three equal columns, so the line spans the HP bar above it.
## Light text for the dark stage.

const NAMES := ["ATK", "DEF", "SPD"]

var _values: Array[Label] = []


func _init() -> void:
	add_theme_constant_override("separation", 0)
	for i in NAMES.size():
		if i > 0:
			var sep := VSeparator.new()
			var line := StyleBoxLine.new()
			line.vertical = true
			line.thickness = 2
			line.color = Color(0.48, 0.39, 0.27)
			sep.add_theme_stylebox_override("separator", line)
			add_child(sep)
		var col := HBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 8)
		var n := UIKit.label(NAMES[i], "TopBarLabel", 17)
		n.add_theme_color_override("font_color", Color(0.8, 0.73, 0.58))
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		col.add_child(n)
		var v := UIKit.label("", "TopBarLabel", 26)
		col.add_child(v)
		_values.append(v)
		add_child(col)


func set_stats(atk: int, df: int, spd: int) -> void:
	_values[0].text = str(atk)
	_values[1].text = str(df)
	_values[2].text = str(spd)
