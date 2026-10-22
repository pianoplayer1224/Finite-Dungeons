class_name SaveCodeDialog
extends RefCounted
## The Python's "5 input save code" and "6 obtain save code" in one dialog, and (with
## first_launch) its opening question: "Enter save code (or 0 to start a new game...)".
## Codes stay interchangeable with the Python build. An empty code means a new game (00000).
## Outside the first launch it also offers Reset progress.


static func _confirm_reset() -> bool:
	var p := GameState.profile
	return await App.instance.confirm(
		"Reset all progress? Runs (%d), highest lv. beaten (%d) and achievements go back to zero.\n\nYour current save code is %s: write it down if you might want this progress back."
		% [p.runs, p.highest, GameState.save_code()],
		"Reset", "Keep my progress", "Reset progress")


## Opens the dialog; resolves when it closes.
static func open(first_launch: bool) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	box.add_child(UIKit.label("Welcome" if first_launch else "Save code", "HeaderLabel"))
	if first_launch:
		box.add_child(UIKit.rich("Played Finite Dungeons before? Enter your save code to keep your progress, or start a new game."))
	else:
		var current := HBoxContainer.new()
		current.add_theme_constant_override("separation", 16)
		current.add_child(UIKit.label("Your code:", "SoftLabel", 24))
		current.add_child(UIKit.label(GameState.save_code(), "BoldLabel", 40))
		var copy := Button.new()
		copy.text = "Copy"
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(GameState.save_code())
			App.instance.toast("Save code copied."))
		current.add_child(copy)
		box.add_child(current)
		box.add_child(HSeparator.new())

	box.add_child(UIKit.label("Enter save code (leave it empty for a new game; there is no capital letter i):", "SoftLabel", 22))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var edit := LineEdit.new()
	edit.max_length = 5
	edit.custom_minimum_size = Vector2(260, 0)
	edit.placeholder_text = "00000"
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(edit)
	var load_btn := Button.new()
	load_btn.text = "Load"
	row.add_child(load_btn)
	box.add_child(row)
	var status := UIKit.rich("")
	box.add_child(status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var reset: Button = null
	if not first_launch:
		reset = Button.new()
		reset.text = "Reset progress"
		UIKit.hover_tip(reset, "Start over from a new game (save code %s)" % GameState.NEW_GAME_CODE)
		reset.disabled = GameState.save_code() == GameState.NEW_GAME_CODE
		buttons.add_child(reset)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(spacer)
	var close := Button.new()
	close.text = "Start a new game" if first_launch else "Close"
	close.theme_type_variation = &"AccentButton" if first_launch else &""
	buttons.add_child(close)
	box.add_child(buttons)

	var modal := App.instance.show_modal(panel)
	close.pressed.connect(func() -> void: modal.closed.emit(null))
	# A tap outside closes it, unless a code is being typed: then it only puts the keyboard away
	# (on a phone that tap is how one does), so the code is not lost.
	modal.on_outside = func() -> void:
		if edit.text.strip_edges() == "":
			modal.closed.emit(null)
		else:
			edit.release_focus()
	if reset != null:
		reset.pressed.connect(func() -> void:
			if await _confirm_reset():
				GameState.reset_profile()
				App.instance.toast("Progress reset. New game started.", "good")
				modal.closed.emit(null))
	# Only alphabet characters can be typed.
	edit.text_changed.connect(func(t: String) -> void:
		var clean := ""
		for c in t:
			if SaveCodes.SAVE_ALPHABET.contains(c):
				clean += c
		if clean != t:
			var caret := edit.caret_column
			edit.text = clean
			edit.caret_column = mini(caret, clean.length()))
	var try_load := func() -> void:
		var code := edit.text.strip_edges()
		var new_game := code == ""
		if new_game:
			code = GameState.NEW_GAME_CODE
		var probe := ProfileState.new()
		var res := SaveCodes.load_code(probe, code)
		if not res["ok"]:
			status.text = UIKit.bb_colour(res["message"] + " Please try again.", UIKit.kind_colour("warning", true))
			Sfx.play("clickFail")
			return
		if not first_launch and (GameState.profile.runs > 0 or GameState.profile.highest > 0):
			var ok: bool = await App.instance.confirm(
				"Replace your progress (runs %d, highest lv. beaten %d) with this code (runs %d, highest lv. beaten %d)?"
				% [GameState.profile.runs, GameState.profile.highest, probe.runs, probe.highest],
				"Replace", "Keep mine")
			if not ok:
				return
		GameState.load_code(code)
		App.instance.toast("New game started." if new_game else res["message"].strip_edges(), "good")
		modal.closed.emit(null)
	load_btn.pressed.connect(try_load)
	edit.text_submitted.connect(func(_t: String) -> void: try_load.call())
	edit.grab_focus.call_deferred()
	await modal.closed
