extends Control
## Camp: the Python's pre_fight() menu and shop() on one screen. Stats ("2 Stats") are always
## visible, Options ("3") is the gear button / Esc, Quit ("4") is Leave dungeon, "0 Start
## fight" is the big button. The RAY-24 menu (shop slot 1 with the drone) is a tab.
## Artefact actions (235 / 777 / 888) are buttons shown only with their artefact.
## Digits typed on the keyboard pick rows by the Python's menu numbers.
## Layout rule: nothing in the camp may need more than the 1920x1080 base size, or the whole
## screen overflows and re-centres (a visible jump). The shop grid, drone tracks, gear and
## forecast all sit in ScrollContainers for that reason.

const TYPE_DELAY := 0.7
const PHONE_START_HEIGHT := 112.0   # Start fight in the phone layout (other buttons: UIKit.PHONE_TAP)
## The phone layout's log: two lines under the shop, or (a tap on it) tall enough to read back.
const PHONE_LOG_SHORT := 72.0
## The phone layout's relic-switch button: the list above it already marks the active relic and
## the next one, so it skips the shop line's "(currently active: ...)".
const PHONE_SWITCH_TEXT := "Switch relic"
const PHONE_LOG_TALL := 300.0

var args := {}
var _top: TopBar
var _log: EventLog
var _tab := "items"
var _typed := ""
var _type_left := 0.0
var _busy := false
var _cards := {}          # item -> ShopCard
var _track_cards := {}    # track -> DroneTrackCard
var _fight_num: Label     # Start fight's "0" (the Python's "0 Start fight")
var _gear_actions: VBoxContainer   # phone: the artefact's section of the gear list, for its buttons
var _relic_actions: VBoxContainer  # phone: under the Relics heading, for the relic switch
var _log_open := false    # phone: the log shown tall


func _ready() -> void:
	if GameState.player == null or GameState.phase != GameState.Phase.CAMP:
		App.instance.go_to.call_deferred("main_menu")
		return
	if UIKit.phone:
		_phone_layout()
	_top = TopBar.new()
	%Layout.add_child(_top)
	%Layout.move_child(_top, 0)
	_top.options_pressed.connect(_open_options)
	_log = EventLog.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	%LogSlot.add_child(_log)
	if UIKit.phone:
		_log.tapped.connect(_toggle_log)
		_log.set_hint("▲")
	%ItemsTab.pressed.connect(_set_tab.bind("items"))
	%DroneTab.pressed.connect(_set_tab.bind("drone"))
	%StartFight.pressed.connect(_start_fight)
	%Leave.pressed.connect(_leave)
	_fight_num = UIKit.corner_number(%StartFight, "0")
	_fight_num.add_theme_color_override("font_color", %StartFight.get_theme_color("font_color"))  # not red on red
	%Hint.visible = not UIKit.touch   # the keyboard shortcuts
	GameState.settings_changed.connect(_refresh)

	_log.add_heading("--- Level %d ---" % GameState.level)
	# Built once: it depends only on the level, and rebuilding it on every shop action would
	# restart the slime's animation.
	_build_monster(GameState.level)
	_refresh()
	%StartFight.grab_focus.call_deferred(true)
	var pending: Array = GameState.pending_events
	GameState.pending_events = []
	if not pending.is_empty():
		_present.call_deferred(pending, {}, null)


## The phone layout (UIKit.phone: a canvas of at least 1440 x 720). The bottom row would leave
## the columns too short, so its log moves under the shop and its buttons under the forecast:
## all three columns get the full height. The side columns are narrower, the shop three cards
## wide, the player's notes go into the scrolling gear list (_build_gear), Start fight is big
## and Leave dungeon sits under the gear list, and the monster panel is compact (no slime) so
## the Next fight forecast fits without scrolling.
func _phone_layout() -> void:
	var body: MarginContainer = $Layout/Body
	for side in ["left", "top", "right", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 12)
	$Layout/Body/Columns.add_theme_constant_override("separation", 12)
	for column: Control in [$Layout/Body/Columns/Left, $Layout/Body/Columns/Right]:
		column.custom_minimum_size.x = 300   # the shop's 3 cards (ShopCard) need the rest at 1440
		column.add_theme_constant_override("separation", 6)
	%LogSlot.reparent($Layout/Body/Columns/Center)
	%LogSlot.custom_minimum_size.y = PHONE_LOG_SHORT
	var buttons: Control = $Layout/Bottom/BottomRow/Buttons
	buttons.reparent($Layout/Body/Columns/Right)
	buttons.custom_minimum_size.x = 0
	# Start fight is the big one, bottom right under the thumb; the rarely used, run-ending
	# Leave dungeon goes to the foot of the left column, which leaves Start fight the room.
	%StartFight.custom_minimum_size.y = PHONE_START_HEIGHT
	%StartFight.add_theme_font_size_override("font_size", 36)
	%Leave.reparent($Layout/Body/Columns/Left)
	$Layout/Body/Columns/Right/MonsterPanel/Monster.add_theme_constant_override("separation", 4)
	%Forecast.add_theme_constant_override("separation", 2)
	$Layout/Bottom.visible = false
	%Actions.visible = false   # the artefact's buttons go under it in the gear list (_build_gear)
	for tab: Control in [%ItemsTab, %DroneTab]:
		UIKit.tap_height(tab, UIKit.PHONE_TAP_SMALL)
	%ItemGrid.columns = 3


## Room above a button's text for its corner number: a phone's artefact buttons wrap their
## text right up to the corner.
static func _clear_corner(b: Button) -> void:
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := b.get_theme_stylebox(style).duplicate() as StyleBox
		box.content_margin_top = maxf(box.get_margin(SIDE_TOP), 0.0) + 16.0
		b.add_theme_stylebox_override(style, box)


## Phone layout: a tap on the log shows it tall, to read back; another makes it small again.
func _toggle_log() -> void:
	_log_open = not _log_open
	%LogSlot.custom_minimum_size.y = PHONE_LOG_TALL if _log_open else PHONE_LOG_SHORT
	_log.set_hint("▼" if _log_open else "▲")


## Content clear of a phone's camera cutout (App.safe_inset; see UIKit.keep_clear): the top
## bar's contents and the columns move in, the bar itself still spans the screen.
func keep_clear(inset: Vector2) -> void:
	if _top == null:   # not in a run: on its way back to the menu
		return
	_top.keep_clear(inset)
	UIKit.keep_clear($Layout/Body, Vector2(inset.x, 0.0))
	UIKit.keep_clear($Layout/Bottom, Vector2(inset.x, 0.0))


func _process(delta: float) -> void:
	if _typed != "":
		_type_left -= delta
		if _type_left <= 0.0:
			_resolve_typed()


func _unhandled_input(event: InputEvent) -> void:
	if App.instance.has_modal() or _busy:
		return
	if event.is_action_pressed("ui_cancel"):
		_open_options()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		var digit := -1
		if k >= KEY_0 and k <= KEY_9:
			digit = k - KEY_0
		elif k >= KEY_KP_0 and k <= KEY_KP_9:
			digit = k - KEY_KP_0
		if digit >= 0:
			_typed += str(digit)
			_type_left = TYPE_DELAY
			get_viewport().set_input_as_handled()
		elif (k == KEY_ENTER or k == KEY_KP_ENTER) and _typed != "":
			_resolve_typed()
			get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- building

func _refresh() -> void:
	var p := GameState.player
	if p == null:
		return
	var level := GameState.level
	_top.show_player(p, level)
	_build_you(p)
	_build_gear(p)
	_build_shop(p, level)
	_build_forecast()
	var can_act := GameState.phase == GameState.Phase.CAMP
	_fight_num.visible = GameState.settings["show_numbers"]
	%StartFight.disabled = not can_act
	%Leave.disabled = not can_act


## HP bar and the ATK/DEF/SPD tiles share the panel's full width.
func _build_you(p: PlayerState) -> void:
	UIKit.clear_children(%You)
	%You.add_child(UIKit.label("Player", "SectionLabel", 28))
	%You.add_child(UIKit.hp_bar(p.hp, p.max_hp, "HP"))
	%You.add_child(StatTiles.new().add_stat("ATK", p.atk, p.total_atk()) \
			.add_stat("DEF", p.df, p.total_df()).add_stat("SPD", p.spd, p.total_spd()))
	if not UIKit.phone:   # there they head the gear list, which scrolls
		_add_notes(%You, p)


## The player's running notes (revives, drone ATK, what the artefact will do...), under a line.
func _add_notes(into: Control, p: PlayerState) -> void:
	var notes: Array[String] = []
	if p.relic == "family" and not p.revive_used:
		notes.append("Revives: 1")
	if p.counters > 0:
		notes.append("Counters: %d" % p.counters)
	if p.forbidden_ink > 0:
		notes.append("Forbidden Ink in your pocket: %d" % p.forbidden_ink)
	if p.relic == "yd":
		notes.append("RAY-24 drone ATK: %d (part of your ATK)" % p.drone.atk)
	if p.relic == "meowton":
		notes.append("Meowton's lawsuit: your SPD is extra ATK")
	if p.pending_hp_multiplier > 1:
		notes.append("Max HP x%d after your next fight" % p.pending_hp_multiplier)
	if p.socks_sealed:
		notes.append("Max HP sealed by the Cursed Socks")
	if not p.elixir_timers.is_empty():
		notes.append("Elixir: -%d extra SPD after each of the next %d fight(s)" % [Values.ELIXIR_SPD_DECAY * p.elixir_timers.size(), p.elixir_timers.max()])
	if p.artefact == "coinpot":
		var bonus := floorf(p.money / Values.COINPOT_STEP) * Values.COINPOT_PAY if p.money >= Values.COINPOT_STEP else 0.0
		notes.append("Coinpot pays %s before the fight" % UIKit.fmt_money(bonus * (Values.DRONE_INCOME_MULTIPLIER if p.drone.stages[3] == 4 else 1)))
	if p.artefact == "vitality":
		notes.append("Before the fight: -%d%% money, then HP - %s" % [Content.VITALITY_PERCENT, Content.VITALITY_DRAIN_TEXT])
	if not notes.is_empty():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		into.add_child(HSeparator.new())
		into.add_child(box)
		for n in notes:
			var l := UIKit.label(n, "SoftLabel", UIKit.PHONE_INFO_TEXT if UIKit.phone else 19)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(l)


## Relics, then the artefact. In the phone layout the shop's artefact buttons come here instead
## (_build_shop): the relic switch under the Relics heading, Cursed Socks and the water sample
## under the artefact; the player's notes come last.
func _build_gear(p: PlayerState) -> void:
	UIKit.clear_children(%Gear)
	_gear_actions = null
	_relic_actions = null
	_add_relics(p)
	_add_artefact(p)
	if UIKit.phone:
		_add_notes(%Gear, p)


func _add_relics(p: PlayerState) -> void:
	var relics: Array = p.relics if not p.relics.is_empty() else ([p.relic] if p.relic != "" else [])
	%Gear.add_child(UIKit.label("Relics" if relics.size() > 1 else "Relic", "SectionLabel", 22))
	if UIKit.phone:
		_relic_actions = VBoxContainer.new()
		_relic_actions.visible = false   # until a button goes in
		%Gear.add_child(_relic_actions)
	if relics.is_empty():
		%Gear.add_child(UIKit.label("You have no relic.", "SoftLabel", 19))
	for i in relics.size():
		var r: String = relics[i]
		var tag := ""
		if relics.size() > 1:
			tag = "  (active)" if i == p.active_relic_index else ("  (next)" if i == p.active_relic_index + 1 else "")
		var row := _gear_row(r, UIKit.item_name(r) + tag, Content.RELIC_DESCRIPTIONS.get(r, ""))
		if relics.size() > 1 and i != p.active_relic_index:
			row.modulate.a = 0.5
		%Gear.add_child(row)
	if p.artefact == "carrier":
		%Gear.add_child(UIKit.label("Switches left: %d" % (Values.CARRIER_RELICS - 1 - p.switches), "SoftLabel", 18))


func _add_artefact(p: PlayerState) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", %Gear.get_theme_constant("separation"))
	%Gear.add_child(box)
	box.add_child(UIKit.label("Artefact", "SectionLabel", 22))
	if p.artefact == "":
		box.add_child(UIKit.label("You have no artefact.", "SoftLabel", 19))
	else:
		box.add_child(_gear_row(p.artefact, UIKit.item_name(p.artefact), Content.ARTEFACT_DESCRIPTIONS.get(p.artefact, "")))
	_gear_actions = box


func _gear_row(key: String, title: String, desc: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	if desc != "":
		UIKit.rich_tooltip(row, UIKit.desc_bbcode(desc))
	row.add_child(UIKit.icon_rect(key, 56))
	var l := UIKit.label(title, "BoldLabel", 19)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return row


func _build_shop(p: PlayerState, level: int) -> void:
	var shop := ShopMenu.shop_rows(p, level)
	var show_numbers: bool = GameState.settings["show_numbers"]
	%ShopMoney.text = "💰 " + UIKit.fmt_money(p.money)
	var has_drone := p.relic == "yd"
	%DroneTab.visible = has_drone
	if not has_drone and _tab == "drone":
		_tab = "items"
	%ItemsTab.set_pressed_no_signal(_tab == "items")
	%DroneTab.set_pressed_no_signal(_tab == "drone")
	%ItemsTab.visible = has_drone
	%ItemsView.visible = _tab == "items"
	%DroneView.visible = _tab == "drone"

	UIKit.clear_children(%ItemGrid)
	_cards.clear()
	for row: Dictionary in shop["rows"]:
		var card := ShopCard.new().setup(row, show_numbers)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_on_row.bind(row))
		%ItemGrid.add_child(card)
		_cards[row["item"]] = card

	UIKit.clear_children(%Actions)
	var phone_actions := UIKit.phone and _gear_actions != null
	for sp: Dictionary in shop["specials"]:
		var b := Button.new()
		b.text = sp["text"]
		if show_numbers:
			UIKit.corner_number(b, str(sp["num"]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 54)
		b.pressed.connect(_on_special.bind(sp["action"]))
		if phone_actions:   # in the gear list, a narrow column: the long ones wrap
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if show_numbers:
				_clear_corner(b)
			if sp["action"] == "switch_relic" and _relic_actions != null:
				b.text = PHONE_SWITCH_TEXT
				_relic_actions.add_child(b)
				_relic_actions.visible = true
			else:
				_gear_actions.add_child(b)
		else:
			%Actions.add_child(b)
	%Actions.visible = not shop["specials"].is_empty() and not phone_actions

	UIKit.clear_children(%DroneTracks)
	_track_cards.clear()
	if has_drone:
		var drone := ShopMenu.drone_rows(p)
		%DroneHead.text = "Drone ATK %d    ·    Upgrade slots used %d / %d" % [drone["atk"], drone["slots_used"], Values.DRONE_SLOTS]
		for t: Dictionary in drone["tracks"]:
			var card := DroneTrackCard.new().setup(t, show_numbers)
			card.upgrade_pressed.connect(_on_drone)
			%DroneTracks.add_child(card)
			_track_cards[t["track"]] = card


func _build_monster(level: int) -> void:
	UIKit.clear_children(%Monster)
	var m := Entity.create_monster(level)
	%Monster.add_child(UIKit.label("Next Monster - Level %d" % level, "SectionLabel", 18 if UIKit.phone else 24))
	if not UIKit.phone:   # the phone layout leaves the slime out: the room goes to the forecast
		var slime := SpriteAnim.new()
		slime.custom_minimum_size = Vector2(0, 130)
		slime.flip_h = true
		slime.self_modulate = SpriteAnim.slime_tint(level)
		slime.play(SpriteAnim.SLIME_IDLE, SpriteAnim.SLIME_CELL, 7.0, true, SpriteAnim.slime_row(level), SpriteAnim.SLIME_CROP)
		%Monster.add_child(slime)
	%Monster.add_child(StatTiles.new().add_tile("HP", str(m.hp)).add_tile("ATK", str(m.atk)) \
			.add_tile("DEF", str(m.df)).add_tile("SPD", str(m.spd)))
	if level == Values.FINAL_LEVEL:
		%Monster.add_child(UIKit.label("The level %d boss." % Values.FINAL_LEVEL, "BoldLabel", 20))


func _build_forecast() -> void:
	UIKit.clear_children(%Forecast)
	%Forecast.add_child(UIKit.label("Next fight", "SectionLabel", 18 if UIKit.phone else 24))
	for line in EventText.forecast_lines(GameState.forecast()):
		var l := UIKit.label(line.strip_edges(), "", UIKit.PHONE_INFO_TEXT if UIKit.phone else 20)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_color_override("font_color", UIKit.INK_SOFT)
		if UIKit.phone:   # set close, so the whole forecast fits its short panel
			l.add_theme_constant_override("line_spacing", 0)
		%Forecast.add_child(l)


func _set_tab(tab: String) -> void:
	_tab = tab
	_refresh()


# ---------------------------------------------------------------- actions

func _on_row(row: Dictionary) -> void:
	if _busy:
		return
	if row["item"] == "yds":
		_set_tab("drone")
		return
	if not row["buyable"]:
		App.instance.toast(row["text"], "warning", row["item"])
		UIKit.shake(_cards[row["item"]])
		return
	var before := GameState.snapshot()
	var events := GameState.buy(row["item"])
	_present(events, before, _cards.get(row["item"]), -1, "buy")


func _on_drone(track: int) -> void:
	if _busy:
		return
	var before := GameState.snapshot()
	var events := GameState.drone_upgrade(track)
	_present(events, before, null, track, "buy")


func _on_special(action: String) -> void:
	if _busy:
		return
	var before := GameState.snapshot()
	var events: Array = []
	match action:
		"water_sample":
			events = GameState.take_water_sample()
		"socks":
			events = GameState.activate_socks()
		"switch_relic":
			events = GameState.switch_relic()
	_present(events, before, null, -1, "itemUse")


const BLOCKED := ["buy_blocked", "drone_blocked", "socks_blocked", "water_sample_blocked", "relic_switch_blocked"]
const STORY := ["revive", "water_sample", "blessed_fumble", "shop_death", "pic_kill"]


## Show the result of a camp action: log lines, feedback, story cards, then refresh. `sound`
## plays when the action went through (a refusal plays its own, with its warning toast).
func _present(events: Array, before: Dictionary, card: Control, track := -1, sound := "") -> void:
	_busy = true
	_log.add_events(events)
	var after := GameState.snapshot()
	var refused := false
	for ev: Dictionary in events:
		if ev["type"] in BLOCKED:
			refused = true
			var lines := UIKit.event_lines(ev)
			if not lines.is_empty():
				App.instance.toast(lines[0], "warning")
	if events.any(func(ev: Dictionary) -> bool: return ev["type"] == "shop_death"):
		Sfx.play("lose")
	elif sound != "" and not refused and not events.is_empty():
		Sfx.play(sound)
	var old_stages: Array = before.get("drone_stages", [])
	var item: String = (card as ShopCard).row["item"] if card is ShopCard else ""
	_refresh()
	# Feedback on the rebuilt cards, once their containers have laid them out.
	await UIKit.await_layout(get_tree())
	var target: Control = _cards.get(item) if item != "" else null
	if target != null:
		if refused:
			UIKit.shake(target)
		else:
			UIKit.pulse(target)
	if track >= 0 and not old_stages.is_empty():
		for t: int in _track_cards:
			(_track_cards[t] as DroneTrackCard).flash_new_stages(old_stages[t], GameState.player.drone.stages[t])
		if refused and _track_cards.has(track):
			UIKit.shake((_track_cards[track] as DroneTrackCard).upgrade)
	if not before.is_empty() and not after.is_empty():
		_float_diffs(before, after)
	for ev: Dictionary in events:
		if ev["type"] == "relic_switched":
			App.instance.toast("Active relic: %s" % Content.RELIC_NAMES[ev["relic"]], "normal", ev["relic"])
		if ev["type"] in ["meowton_equipped", "esword_equipped", "esword_start"]:
			App.instance.toast(UIKit.event_lines(ev)[0], "normal")
		if ev["type"] in STORY:
			var text := "\n".join(UIKit.event_lines(ev))
			await App.instance.story(text, "", EventText.colour_of(ev))
	_busy = false
	if GameState.phase == GameState.Phase.RUN_OVER:
		App.instance.go_to("run_end")


func _float_diffs(before: Dictionary, after: Dictionary) -> void:
	var stats_at := UIKit.centre_in(%YouPanel, %FX) - Vector2(0, 40)
	var money_at := UIKit.centre_in(_top.money_label(), %FX) + Vector2(0, 30)
	var good := UIKit.kind_colour("good", true)
	var bad := UIKit.kind_colour("bad", true)
	var y := 0.0
	for pair: Array in [["hp", "HP"], ["max_hp", "max HP"], ["total_atk", "ATK"], ["total_df", "DEF"],
			["total_spd", "SPD"], ["counters", "counters"], ["ink", "ink"], ["drone_atk", "drone ATK"]]:
		var d: int = after[pair[0]] - before[pair[0]]
		if d != 0:
			UIKit.float_text(%FX, "%+d %s" % [d, pair[1]], good if d > 0 else bad, stats_at + Vector2(0, y))
			y += 38.0
	var dm: float = after["money"] - before["money"]
	if not is_zero_approx(dm):
		UIKit.float_text(%FX, ("+" if dm > 0 else "-") + UIKit.fmt_money(absf(dm)), UIKit.GOLD if dm > 0 else bad, money_at, 28)


func _resolve_typed() -> void:
	var code := _typed
	_typed = ""
	if _tab == "drone":
		if code == "0":
			_set_tab("items")
		elif code in ["1", "2", "3", "4"]:
			_on_drone(int(code) - 1)
		else:
			App.instance.toast("Invalid input, please try again", "warning")
		return
	if code == "0":
		_start_fight()
		return
	var shop := ShopMenu.shop_rows(GameState.player, GameState.level)
	for row: Dictionary in shop["rows"]:
		if str(row["num"]) == code:
			_on_row(row)
			return
	for sp: Dictionary in shop["specials"]:
		if str(sp["num"]) == code:
			_on_special(sp["action"])
			return
	App.instance.toast("Invalid input, please try again", "warning")


func _open_options() -> void:
	if not App.instance.has_modal():
		await OptionsDialog.open()
		_refresh()


func _start_fight() -> void:
	if _busy or GameState.phase != GameState.Phase.CAMP:
		return
	_busy = true
	GameState.start_fight()
	App.instance.go_to("battle")


func _leave() -> void:
	if _busy:
		return
	var ok := await App.instance.confirm("Quit the game? Levels beaten this run still count.",
			"Yes", "No", "", true, true)
	if ok and GameState.phase == GameState.Phase.CAMP:
		GameState.leave_dungeon()
		App.instance.go_to("run_end")
