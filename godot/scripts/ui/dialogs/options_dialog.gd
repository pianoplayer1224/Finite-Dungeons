class_name OptionsDialog
extends RefCounted
## The Python's Options menu (show normal attacks, describe my relic and artefact, show save
## code, colours) plus Godot-only settings. Settings persist (the Python's were per session).

const SPEEDS := [1.0, 2.0, 4.0]


## In the phone layout (UIKit.phone) it all fits on the screen without scrolling: the settings
## and (during a run) the relic and artefact text side by side, two check boxes to a row, both
## volume sliders on one row.
static func open() -> void:
	var phone := UIKit.phone
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0 if phone else 900, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UIKit.label("Options", "HeaderLabel"))
	var settings: Container = box   # where the settings go
	var info: Container = box       # where the run's relic and artefact text goes
	var checks_box: Container = box
	if phone:
		var cols := HBoxContainer.new()
		cols.add_theme_constant_override("separation", 32)
		box.add_child(cols)
		settings = VBoxContainer.new()
		settings.add_theme_constant_override("separation", 10)
		cols.add_child(settings)
		info = VBoxContainer.new()
		info.add_theme_constant_override("separation", 10)
		info.visible = GameState.in_run()
		cols.add_child(info)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 0)
		settings.add_child(grid)
		checks_box = grid

	var checks: Array[Array] = [
			["show_hits", "Show normal attacks in fights"],
			["colours", "Coloured text"],
			["show_numbers", "Show the original menu numbers" if phone else "Show the original menu numbers on shop items and actions"]]
	if not OS.has_feature("mobile"):   # the phone app is always full screen
		checks.append(["fullscreen", "Fullscreen" if UIKit.touch else "Fullscreen (F11)"])
	for item: Array in checks:
		var check := CheckBox.new()
		check.text = item[1]
		check.button_pressed = GameState.settings[item[0]]
		var key: String = item[0]
		check.toggled.connect(func(on: bool) -> void: GameState.set_setting(key, on))
		checks_box.add_child(check)

	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 10)
	speed_row.add_child(UIKit.label("Battle speed", "", 22))
	var group := ButtonGroup.new()
	for s: float in SPEEDS:
		var b := Button.new()
		b.text = "%dx" % int(s)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = is_equal_approx(GameState.settings["battle_speed"], s)
		b.pressed.connect(func() -> void: GameState.set_setting("battle_speed", s))
		UIKit.tap_height(b, UIKit.PHONE_TAP_SMALL)   # phone: shorter than the other buttons
		speed_row.add_child(b)
	settings.add_child(speed_row)

	var volumes := GridContainer.new()
	volumes.columns = 4 if phone else 2
	volumes.add_theme_constant_override("h_separation", 14)
	volumes.add_theme_constant_override("v_separation", 10)
	for item: Array in [["sfx_volume", "Sound effects"], ["music_volume", "Music"]]:
		var key: String = item[0]
		volumes.add_child(UIKit.label(item[1], "", 22))
		var volume := HSlider.new()
		volume.max_value = 1.0
		volume.step = 0.05
		volume.value = GameState.settings[key]
		volume.custom_minimum_size = Vector2(170 if phone else 320, 0)
		volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Applied live and saved on close: set_setting() on every step would rebuild Camp each time.
		volume.value_changed.connect(func(v: float) -> void:
			GameState.settings[key] = v
			Music.apply_volume())
		if key == "sfx_volume":
			volume.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("clickSuccess"))  # a sample
		volumes.add_child(volume)
	settings.add_child(volumes)

	if GameState.in_run():
		if not phone:
			box.add_child(HSeparator.new())
		info.add_child(UIKit.label("Your relic and artefact", "SectionLabel"))
		var text := PackedStringArray()
		var p := GameState.player
		var relics: Array = p.relics if not p.relics.is_empty() else ([p.relic] if p.relic != "" else [])
		if relics.is_empty():
			text.append("You have no relic.")
		for r: String in relics:
			var line := UIKit.desc_bbcode(Content.RELIC_DESCRIPTIONS.get(r, "No description."))
			if relics.size() > 1 and r == p.relic:
				line += "  (active)"
			text.append(line)
		if p.artefact != "":
			text.append(UIKit.desc_bbcode(Content.ARTEFACT_DESCRIPTIONS.get(p.artefact, "No description.")))
		else:
			text.append("You have no artefact.")
		var desc := UIKit.rich("\n".join(text))
		desc.custom_minimum_size = Vector2(560 if phone else 840, 0)
		if phone:
			desc.add_theme_font_size_override("normal_font_size", 19)
			desc.add_theme_font_size_override("bold_font_size", 19)
		info.add_child(desc)
		info.add_child(UIKit.label("Save code: %s" % GameState.save_code(), "BoldLabel", 24))

	var close := Button.new()
	close.text = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	box.add_child(close)
	var modal := App.instance.show_modal(panel)
	close.pressed.connect(func() -> void: modal.closed.emit(null))
	close.grab_focus.call_deferred(true)
	await modal.closed
	GameState.save_profile()
