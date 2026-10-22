extends Control
## Achievements: the Python's print_achievements() - unlocked first, then locked, in
## ACHIEVEMENT_DISPLAY order; secret hints stay "?????????" while locked.

var args := {}
var _panel: PanelContainer


func _ready() -> void:
	var panel := PanelContainer.new()
	_panel = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The phone layout (UIKit.phone) uses the full width: longer lines, less scrolling.
	var side := 32 if UIKit.phone else 240
	var ends := 24 if UIKit.phone else 60
	panel.offset_left = side
	panel.offset_top = ends
	panel.offset_right = -side
	panel.offset_bottom = -ends
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UIKit.label("Achievements   %d / %d" % [GameState.achievement_count(), Content.ACH_BIT_ORDER.size()], "HeaderLabel"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	var ac: Dictionary = GameState.profile.ac
	for unlocked: bool in [true, false]:
		list.add_child(UIKit.label("Unlocked" if unlocked else "Locked", "SectionLabel"))
		var any := false
		for a: Array in Content.ACHIEVEMENT_DISPLAY:
			if ac[a[0]] != unlocked:
				continue
			any = true
			var card := PanelContainer.new()
			card.theme_type_variation = &"InsetPanel"
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 16)
			card.add_child(row)
			var mark := UIKit.label("⭐" if unlocked else "🔒", "", 34)
			mark.custom_minimum_size = Vector2(50, 0)
			row.add_child(mark)
			var text := VBoxContainer.new()
			text.add_child(UIKit.label(a[1], "BoldLabel", 26))
			var hint: String = "?????????" if (not unlocked and a[0] in Content.ACHIEVEMENT_SECRET_HINTS) else a[2]
			var h := UIKit.label(hint, "", 21)
			h.add_theme_color_override("font_color", UIKit.kind_colour("muted", true) if not unlocked else UIKit.INK_SOFT)
			text.add_child(h)
			row.add_child(text)
			if not unlocked:
				card.modulate.a = 0.75
			list.add_child(card)
		if not any:
			list.add_child(UIKit.label("None yet." if unlocked else "Nothing left to unlock!", "SoftLabel", 21))

	var back := Button.new()
	back.text = "Back"
	back.theme_type_variation = &"AccentButton"
	back.custom_minimum_size = Vector2(220, 0)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.pressed.connect(func() -> void: App.instance.go_to("main_menu"))
	box.add_child(back)
	back.grab_focus.call_deferred(true)


## Content clear of a phone's camera cutout (App.safe_inset; see UIKit.keep_clear).
func keep_clear(inset: Vector2) -> void:
	UIKit.keep_clear(_panel, inset)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		App.instance.go_to("main_menu")
