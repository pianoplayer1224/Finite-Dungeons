extends Control
## Run End: how the run finished, in the Python's own words (run_died, hard_mode,
## run_finished, run_quit, game_won, few_runs_win), plus what it earned and the save code.

const END_TYPES := ["shop_death", "run_died", "hard_mode", "run_finished", "run_quit", "game_won", "few_runs_win"]
const UNLOCK_DELAY := 0.8  # the unlock sound comes in after the run-end one

var args := {}


func _ready() -> void:
	var info: Dictionary = GameState.run_end
	if info.is_empty():
		App.instance.go_to.call_deferred("main_menu")
		return
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var titles := {"died": "You died!", "shop_death": "You died in the shop!", "quit": "You left the dungeon", "won": "You win!"}
	var title := UIKit.label(titles.get(info["kind"], "Run over"), "HeaderLabel", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var text := PackedStringArray()
	for ev: Dictionary in info["events"]:
		if ev["type"] in END_TYPES or (ev["type"] == "ink_kill" and ev["final_boss"]):
			var colour := UIKit.kind_colour(EventText.colour_of(ev), GameState.settings["colours"])
			for line in UIKit.event_lines(ev):
				text.append(UIKit.bb_colour(line, colour))
	var body := UIKit.rich("[center]%s[/center]" % "\n".join(text))
	body.add_theme_font_size_override("normal_font_size", 26)
	box.add_child(body)

	if not info["new_achievements"].is_empty():
		box.add_child(HSeparator.new())
		box.add_child(UIKit.label("New achievements", "SectionLabel"))
		for a: Array in Content.ACHIEVEMENT_DISPLAY:
			if a[0] in info["new_achievements"]:
				box.add_child(UIKit.label("⭐  %s — %s" % [a[1], a[2]], "", 22))

	if not info["newly_unlocked"].is_empty():
		box.add_child(HSeparator.new())
		box.add_child(UIKit.label("Newly unlocked", "SectionLabel"))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 18)
		for key: String in info["newly_unlocked"]:
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 8)
			item.add_child(UIKit.icon_rect(key, 64))
			item.add_child(UIKit.label(UIKit.item_name(key), "BoldLabel", 20))
			flow.add_child(item)
		box.add_child(flow)

	box.add_child(HSeparator.new())
	var code_row := HBoxContainer.new()
	code_row.alignment = BoxContainer.ALIGNMENT_CENTER
	code_row.add_theme_constant_override("separation", 16)
	code_row.add_child(UIKit.label("Save code:", "SoftLabel", 26))
	code_row.add_child(UIKit.label(info["code"], "BoldLabel", 44))
	var copy := Button.new()
	copy.text = "Copy"
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(info["code"])
		App.instance.toast("Save code copied."))
	code_row.add_child(copy)
	box.add_child(code_row)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	var menu := Button.new()
	menu.text = "Main menu"
	menu.custom_minimum_size = Vector2(240, 64)
	menu.pressed.connect(back)
	buttons.add_child(menu)
	var again := Button.new()
	again.text = "New run"
	again.theme_type_variation = &"AccentButton"
	again.custom_minimum_size = Vector2(300, 64)
	again.pressed.connect(func() -> void:
		GameState.back_to_menu()
		App.instance.go_to("run_setup"))
	buttons.add_child(again)
	box.add_child(buttons)
	again.grab_focus.call_deferred(true)
	Sfx.play("runEnd")
	if not info["newly_unlocked"].is_empty():
		get_tree().create_timer(UNLOCK_DELAY).timeout.connect(_play_unlock)


## Main menu; also Android's Back (App.back).
func back() -> void:
	GameState.back_to_menu()
	App.instance.go_to("main_menu")


func _play_unlock() -> void:
	Sfx.play("unlock")
