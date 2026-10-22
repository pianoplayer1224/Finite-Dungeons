extends Control
## Battle: plays back the fight GameState.start_fight() already resolved. Every event is one
## "beat"; bars, numbers and labels are driven by each event's own payload (live state is
## already final). Speed and Skip only change the pacing, never the outcome.
## Pre-fight events (Vitality, Coinpot) play first, then the fight, then the post-fight
## summary built from snapshot diffs (the Python's post_fight() rewards print nothing).

const BEAT := {
	"player_hit": 0.55, "monster_hit": 0.55, "drone_shot": 0.85, "smirk": 1.1,
	"drone_overkill": 0.9, "vitality_drain": 0.9, "ink_kill": 2.6,
	"vitality_penalty": 0.9, "coinpot_payout": 0.9,
}
const QUICK_HIT := 0.12  # ordinary hits when "show normal attacks" is off
const SPEEDS := [1.0, 2.0, 4.0]
## Screen pixels per sprite pixel, the same for both fighters so their pixels match (the hero's
## 36-pixel cells are 360 tall: the holders' height).
const FIGHTER_SCALE := 10
## The phone layout's (UIKit.phone) scale, so the plates and the log fit the shorter screen.
const PHONE_FIGHTER_SCALE := 6
const DRONE_AHEAD := 160.0  # the yd drone's left edge, this far ahead of the hero's head
const DRONE_BOB := 10.0
const DRONE_SIZE := 120
const PHONE_DRONE_SIZE := 72
const DRONE_GAP := 16.0  # the least room between the drone, at the top of its bob, and the top bar
const HERO_IDLE_FPS := 5.0  # 16 frames: a 3.2 s breathing loop
## The hero's swing grows with its total ATK (as on its stat line): [from ATK, animation], highest
## first. A level-L monster has L DEF, so ATK roughly follows the level reached.
const HERO_SWINGS := [[30, "attack4"], [20, "attack3"], [10, "attack2"], [0, "attack1"]]

var args := {}
var _fighter_scale := PHONE_FIGHTER_SCALE if UIKit.phone else FIGHTER_SCALE
var _floor_fill: ColorRect   # the floor's colour on down under the bottom row, to the screen's foot
var _k := float(_fighter_scale) / FIGHTER_SCALE   # for distances that follow the sprites' size
var _fight := {}
var _top: TopBar
var _log: EventLog
var _hero: SpriteAnim
var _monster: SpriteAnim
var _drone: TextureRect
var _skip := false
var _level := 1
var _row := 0
var _swing := "attack1"

# What the screen currently shows (from event payloads).
var _hp := 0
var _max_hp := 1
var _money := 0.0
var _m_hp := 0
var _m_max := 1
var _m_df := 0


func _ready() -> void:
	if GameState.last_fight.is_empty() or GameState.phase != GameState.Phase.FIGHTING:
		App.instance.go_to.call_deferred("main_menu")
		return
	_fight = GameState.last_fight
	_level = _fight["level"]
	var before: Dictionary = _fight["before"]
	var m: Entity = _fight["monster"]
	_hp = before["hp"]
	_max_hp = before["max_hp"]
	_money = before["money"]
	_m_hp = m.hp
	_m_max = m.max_hp
	_m_df = m.df
	_row = SpriteAnim.slime_row(_level)
	if UIKit.phone:
		_phone_layout()
	_extend_floor()

	_top = TopBar.new()
	%Layout.add_child(_top)
	%Layout.move_child(_top, 0)
	_top.show_player(GameState.player, _level)
	_top.set_money(_money)
	_top.options_pressed.connect(func() -> void: OptionsDialog.open())
	_log = EventLog.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	%LogSlot.add_child(_log)

	var group := ButtonGroup.new()
	for s: float in SPEEDS:
		var b := Button.new()
		b.text = "%dx" % int(s)
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE
		b.button_pressed = is_equal_approx(GameState.settings["battle_speed"], s)
		b.pressed.connect(func() -> void: GameState.set_setting("battle_speed", s))
		UIKit.tap_height(b, UIKit.PHONE_TAP_SMALL)   # phone: shorter than the other buttons
		%SpeedRow.add_child(b)
	%Skip.pressed.connect(func() -> void: _skip = true)
	%Continue.pressed.connect(_continue)
	_hold_bottom_size()

	_hero = SpriteAnim.new()
	_hero.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hero.pixel_scale = _fighter_scale
	_hero.pivot = SpriteAnim.HERO_PIVOT
	_hero_idle()
	%HeroHolder.add_child(_hero)
	_monster = SpriteAnim.new()
	_monster.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_monster.flip_h = true
	_monster.pixel_scale = _fighter_scale
	_monster.pivot = SpriteAnim.SLIME_PIVOT
	_monster.self_modulate = SpriteAnim.slime_tint(_level)
	_monster_idle()
	%MonsterHolder.add_child(_monster)
	if GameState.player.relic == "yd":
		_drone = UIKit.icon_rect("yd", PHONE_DRONE_SIZE if UIKit.phone else DRONE_SIZE)
		%HeroHolder.add_child(_drone)
		_hover_drone()

	%MonsterName.text = ("The level %d boss" % _level) if _level == Values.FINAL_LEVEL else ("Level %d monster" % _level)
	_refresh_fighters(before["total_atk"], before["total_df"], before["total_spd"])
	_swing = hero_swing(before["total_atk"])
	_play()


## The phone layout (UIKit.phone: a canvas of at least 1440 x 720): smaller fighters,
## narrower plates, a shorter log, so the whole stage fits under the top bar.
func _phone_layout() -> void:
	for holder: Control in [%HeroHolder, %MonsterHolder]:
		holder.custom_minimum_size.y = SpriteAnim.HERO_CELL.y * PHONE_FIGHTER_SCALE
	for column: Control in [$Layout/Stage/Fighters/HeroCol, $Layout/Stage/Fighters/MonsterCol]:
		column.custom_minimum_size.x = 360
		column.add_theme_constant_override("separation", 6)   # leaves the drone room above
	for fighter_name: Label in [$Layout/Stage/Fighters/HeroCol/HeroName, %MonsterName]:
		fighter_name.add_theme_font_size_override("font_size", 26)
	$Layout/Bottom/Row/Controls.custom_minimum_size.x = 330
	$Layout/Bottom.custom_minimum_size.y = 0   # set by _hold_bottom_size, from the phone's buttons
	%Continue.custom_minimum_size.y = 76
	%Banner.add_theme_font_size_override("font_size", 56)
	$Layout/Stage/Fighters.offset_bottom = -6   # the fighters lower, so the drone has room over them


## The stage's dark floor carries on under the bottom row (log, speed, Skip) to the foot of the
## screen, across its whole width: a ColorRect behind the layout, from the stage's bottom down.
func _extend_floor() -> void:
	_floor_fill = ColorRect.new()
	_floor_fill.color = ($Layout/Stage/Floor as ColorRect).color
	_floor_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floor_fill)
	move_child(_floor_fill, 0)
	var fit := func() -> void:
		var top: float = (%Stage as Control).get_global_rect().end.y - get_global_rect().position.y
		_floor_fill.position = Vector2(0.0, top)
		_floor_fill.size = Vector2(size.x, maxf(size.y - top, 0.0))
	(%Stage as Control).resized.connect(fit)
	resized.connect(fit)
	fit.call_deferred()


## The bottom row keeps one size through the fight's end, when Skip goes and Continue comes
## 0.8 s later. Sized by its contents it moved the log, the speed buttons and the stage: in the
## phone layout (its height set by the buttons, UIKit.PHONE_TAP tall) it shrank and grew back,
## and on both layouts "Continue to level 10" and up is wider than the column. So it is held at
## its largest from the start: the speed buttons over the taller of the two, as wide as
## "Continue to level 30" (the PC layout's fixed 270 px height already has room). In the phone
## layout Continue replaces the speed buttons as well as Skip, so it is a big button there.
func _hold_bottom_size() -> void:
	var controls: Control = $Layout/Bottom/Row/Controls
	var text: String = %Continue.text
	%Continue.text = "Continue to level %d" % Values.FINAL_LEVEL
	var widest := maxf(%Skip.get_combined_minimum_size().x, %Continue.get_combined_minimum_size().x)
	var tallest := maxf(%Skip.get_combined_minimum_size().y, %Continue.get_combined_minimum_size().y)
	%Continue.text = text
	controls.custom_minimum_size.x = maxf(controls.custom_minimum_size.x, widest)
	var during: float = %SpeedRow.get_combined_minimum_size().y + controls.get_theme_constant("separation") \
			+ %Skip.get_combined_minimum_size().y
	if UIKit.phone:   # Continue takes the speed buttons' place too: as tall as both rows together
		%Continue.custom_minimum_size.y = during
		tallest = during - %SpeedRow.get_combined_minimum_size().y - controls.get_theme_constant("separation")
	var bottom: Control = $Layout/Bottom
	bottom.custom_minimum_size.y = maxf(bottom.custom_minimum_size.y, %SpeedRow.get_combined_minimum_size().y
			+ controls.get_theme_constant("separation") + tallest + bottom.get_theme_constant("margin_bottom"))


## Content clear of a phone's camera cutout (App.safe_inset; see UIKit.keep_clear): the top
## bar's contents, the fighters and the bottom row move in; the bar and the floor still span it.
func keep_clear(inset: Vector2) -> void:
	if _top == null:   # no fight to show: on its way back to the menu
		return
	_top.keep_clear(inset)
	UIKit.keep_clear($Layout/Stage/Fighters, Vector2(inset.x, 0.0))
	UIKit.keep_clear($Layout/Bottom, Vector2(inset.x, 0.0))


func _unhandled_input(event: InputEvent) -> void:
	if App.instance.has_modal():
		return
	if event.is_action_pressed("ui_cancel"):
		OptionsDialog.open()
		get_viewport().set_input_as_handled()


func _speed() -> float:
	return maxf(float(GameState.settings["battle_speed"]), 0.25)


func _wait(seconds: float) -> void:
	if _skip:
		return
	await get_tree().create_timer(seconds / _speed()).timeout


func _refresh_fighters(atk: int = -1, df: int = -1, spd: int = -1) -> void:
	%HeroBar.max_value = maxi(_max_hp, 1)
	%HeroBar.value = clampi(_hp, 0, maxi(_max_hp, 1))
	%HeroHP.text = "%d / %d" % [_hp, _max_hp]
	%MonsterBar.max_value = maxi(_m_max, 1)
	%MonsterBar.value = clampi(_m_hp, 0, _m_max)
	%MonsterHP.text = "%d / %d" % [_m_hp, _m_max]
	var m: Entity = _fight["monster"]
	(%MonsterStats as StatRow).set_stats(m.atk, _m_df, m.spd)
	if atk >= 0:
		(%HeroStats as StatRow).set_stats(atk, df, spd)
	_top.set_money(_money)


# ---------------------------------------------------------------- playback

func _play() -> void:
	var result: Dictionary = _fight["result"]
	_log.add_heading("--- Level %d ---" % _level)
	var muted := UIKit.kind_colour("muted", GameState.settings["colours"])
	for line in EventText.forecast_lines(_fight["forecast"]):
		_log.add_line(line.strip_edges(), muted)
	await _banner("Level %d" % _level, 0.9)
	for ev: Dictionary in result["pre"]:
		await _beat(ev)
	for ev: Dictionary in result["fight"]:
		await _beat(ev)
	await _finish()


func _beat(ev: Dictionary) -> void:
	_log.add_event(ev)
	var t: String = ev["type"]
	match t:
		"vitality_penalty":
			_money -= ev["amount"]
			_refresh_fighters()
			_float_at(_top.money_label(), "-" + UIKit.fmt_money(ev["amount"]), "bad", Vector2(0, 30))
			await _wait(BEAT[t])
		"coinpot_payout":
			_money += ev["amount"]
			_refresh_fighters()
			_float_at(_top.money_label(), "+" + UIKit.fmt_money(ev["amount"]), "money", Vector2(0, 30))
			await _wait(BEAT[t])
		"smirk":
			if not _skip:
				_bubble(%HeroHolder, "'雑魚(pointless peasant)'")
			await _wait(BEAT[t])
		"drone_shot":
			await _drone_shot(ev)
		"drone_overkill":
			if not _skip:
				_bubble(%MonsterHolder, UIKit.event_lines(ev)[0])
			await _wait(BEAT[t])
		"vitality_drain":
			_hp = ev["player_hp"]
			_refresh_fighters()
			if not _skip:
				_flash(_hero)
				_float_at(%HeroHolder, "-%d" % ev["amount"], "bad")
			await _wait(BEAT[t])
		"ink_kill":
			await _ink_kill(ev)
		"player_hit":
			await _hit(true, ev)
		"monster_hit":
			await _hit(false, ev)
		"revive":
			_hp = Values.REVIVE_HP
			_max_hp = maxi(_max_hp, Values.REVIVE_HP)
			_refresh_fighters()
			if not _skip:
				await App.instance.story("\n".join(UIKit.event_lines(ev)), "", "story")
				_glow(_hero)
		"pic_kill":
			if not _skip:
				await App.instance.story("\n".join(UIKit.event_lines(ev)), "", "story")


func _hit(player_attacks: bool, ev: Dictionary) -> void:
	var quick: bool = not GameState.settings["show_hits"]
	var seconds: float = QUICK_HIT if quick else BEAT[ev["type"]]
	if player_attacks:
		_m_hp = ev["monster_hp"]
	else:
		_hp = ev["player_hp"]
	if not _skip:
		var attacker := _hero if player_attacks else _monster
		var target := _monster if player_attacks else _hero
		Sfx.play("playerAttack" if player_attacks else "monsterAttack")
		_lunge(attacker, (70.0 if player_attacks else -70.0) * _k, seconds)
		if player_attacks:
			# A swing starts from idle, timed to finish inside the beat. One still playing (quick
			# hits, fast speeds) is left to finish rather than restarted, so its blade still shows.
			if _hero.looping:
				var frames: int = SpriteAnim.HERO_ANIMS[_swing][1]
				_hero.play_hero(_swing, clampf(frames * _speed() / (seconds * 0.8), 8.0, 30.0), false, _hero_idle)
			_monster.play(SpriteAnim.SLIME_HIT, SpriteAnim.SLIME_CELL, 10.0, false, _row, SpriteAnim.SLIME_CROP, 0, _monster_idle)
		_flash(target)
		if not quick:
			if player_attacks:
				_float_at(%MonsterHolder, "-%d" % ev["dmg"], "good")
			else:
				_float_at(%HeroHolder, "-%d" % ev["dmg"], "bad")
	_refresh_fighters()
	await _wait(seconds)


func _drone_shot(ev: Dictionary) -> void:
	_m_hp = ev["monster_hp"]
	if ev["shreds_df"]:
		_m_df = ev["monster_df"]
	if not _skip and _drone != null:
		var from := UIKit.centre_in(_drone, %FX)
		var to := UIKit.centre_in(%MonsterHolder, %FX)
		var missile := ColorRect.new()
		missile.color = Color(1.0, 0.62, 0.15)
		missile.size = Vector2(34, 10)
		missile.pivot_offset = missile.size / 2.0
		missile.position = from - missile.size / 2.0
		missile.rotation = (to - from).angle()
		%FX.add_child(missile)
		Sfx.play("droneMissile")
		var t := missile.create_tween()
		t.tween_property(missile, "position", to - missile.size / 2.0, 0.35 / _speed()).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await t.finished
		missile.queue_free()
		UIKit.float_text(%FX, "💥", Color.WHITE, to - Vector2(0, 40), 72, 20.0, 0.5)
		_flash(_monster)
		_float_at(%MonsterHolder, "-%d" % ev["dmg"], "good")
		if ev["shreds_df"]:
			_float_at(%MonsterHolder, "-%d DEF" % ev["df_loss"], "muted", Vector2(0, 50))
	_refresh_fighters()
	await _wait(BEAT["drone_shot"])


func _ink_kill(ev: Dictionary) -> void:
	_m_hp = 0
	if not _skip:
		var card := PanelContainer.new()
		card.theme_type_variation = &"InsetPanel"
		var text := UIKit.label(UIKit.event_lines(ev)[0], "HeaderLabel", 40)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.custom_minimum_size = Vector2(1200, 0)
		text.visible_ratio = 0.0
		card.add_child(text)
		%FX.add_child(card)
		card.position = Vector2((size.x - 1240) / 2.0, 240)
		var t := card.create_tween()
		t.tween_property(text, "visible_ratio", 1.0, 1.2 / _speed())
		_flash(_monster)
		_refresh_fighters()
		await _wait(BEAT["ink_kill"])
		var out := card.create_tween()
		out.tween_property(card, "modulate:a", 0.0, 0.3)
		out.tween_callback(card.queue_free)
	_refresh_fighters()


func _finish() -> void:
	_skip = false
	var result: Dictionary = _fight["result"]
	var after: Dictionary = _fight["after"]
	for ev: Dictionary in result["post"]:
		_log.add_event(ev)
	%Skip.visible = false
	Sfx.play("win" if result["won"] else "lose")
	if result["won"]:
		# Gone once the death has played (playing it drops a hit's pending return to idle).
		_monster.play(SpriteAnim.SLIME_DIE, SpriteAnim.SLIME_CELL, 16.0, false, _row, SpriteAnim.SLIME_CROP, 0, _monster.hide)
		_banner("You win!" if result["game_won"] else "Level %d cleared!" % _level, -1.0)
	else:
		_hero.play_hero("death", 10.0, false)
		%Banner.add_theme_color_override("font_color", Color(0.93, 0.35, 0.3))
		_banner("You died!", -1.0)
	await get_tree().create_timer(0.8).timeout
	GameState.release_achievements()
	if result["won"] and not result["run_over"]:
		_show_summary(after)
		%Continue.text = "Continue to level %d" % (_level + 1)
	else:
		%Continue.text = "Continue"
	_hp = after["hp"]
	_max_hp = after["max_hp"]
	_money = after["money"]
	_refresh_fighters(after["total_atk"], after["total_df"], after["total_spd"])
	if UIKit.phone:   # the fight is over: Continue fills the corner (_hold_bottom_size)
		%SpeedRow.visible = false
	%Continue.visible = true
	%Continue.grab_focus(true)


func _show_summary(after: Dictionary) -> void:
	var lines: Array[String] = []
	var dm: float = after["money"] - _money
	if dm > 0.0:
		lines.append("+%s money" % UIKit.fmt_money(dm))
	var dmax: int = after["max_hp"] - _max_hp
	if dmax != 0:
		lines.append("%+d max HP" % dmax)
	var dhp: int = after["hp"] - _hp
	if dhp > 0:
		lines.append("+%d HP healed" % dhp)
	var dspd: int = after["extra_spd"] - _fight["before"]["extra_spd"]
	if dspd != 0:
		lines.append("%+d extra SPD (the elixir is wearing off)" % dspd)
	for ev: Dictionary in _fight["result"]["post"]:
		lines.append_array(UIKit.event_lines(ev))
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(UIKit.label("Rewards", "SectionLabel", 26))
	for l in lines:
		var lab := UIKit.label(l, "", UIKit.PHONE_INFO_TEXT if UIKit.phone else 22)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(420, 0)
		box.add_child(lab)
	%Middle.add_child(panel)
	panel.position = Vector2(maxf((%Middle.size.x - 470) / 2.0, 0.0), 60)
	panel.modulate.a = 0.0
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)


func _continue() -> void:
	GameState.continue_after_fight()
	if GameState.phase == GameState.Phase.RUN_OVER:
		App.instance.go_to("run_end")
	else:
		App.instance.go_to("camp")


# ---------------------------------------------------------------- effects

## The hero's attack animation for a total ATK (HERO_SWINGS).
static func hero_swing(total_atk: int) -> String:
	for tier: Array in HERO_SWINGS:
		if total_atk >= tier[0]:
			return tier[1]
	return "attack1"


func _hero_idle() -> void:
	_hero.play_hero("idle", HERO_IDLE_FPS)


## The yd drone bobs ahead of the hero's head, wholly above its cell (no frame reaches higher, so
## even attack4's blade passes under it). Placed once the holder has been laid out. It never
## rises closer than DRONE_GAP to the stage's top (the top bar): where the stage is too short
## for that, it sits lower instead (the phone layout leaves enough room).
func _hover_drone() -> void:
	await UIKit.await_layout(get_tree())
	var low := _hero.sprite_rect().position.y - _drone.size.y  # bottom edge on the cell's top
	var stage_top: float = ((%HeroHolder as Control).get_global_transform().affine_inverse() * (%Stage as Control).global_position).y
	low = maxf(low, stage_top + DRONE_GAP + 2.0 * DRONE_BOB * _k)
	_drone.position = Vector2(_hero.size.x / 2.0 + DRONE_AHEAD * _k, low - 2.0 * DRONE_BOB * _k)
	var bob := _drone.create_tween().set_loops()
	bob.tween_property(_drone, "position:y", low, 1.2).set_trans(Tween.TRANS_SINE)
	bob.tween_property(_drone, "position:y", low - 2.0 * DRONE_BOB * _k, 1.2).set_trans(Tween.TRANS_SINE)


func _monster_idle() -> void:
	_monster.play(SpriteAnim.SLIME_IDLE, SpriteAnim.SLIME_CELL, 7.0, true, _row, SpriteAnim.SLIME_CROP)


func _lunge(node: Control, dx: float, seconds: float) -> void:
	var t := node.create_tween()
	t.tween_property(node, "position:x", dx, seconds * 0.25 / _speed()).set_trans(Tween.TRANS_QUAD)
	t.tween_property(node, "position:x", 0.0, seconds * 0.35 / _speed()).set_trans(Tween.TRANS_QUAD)


func _flash(node: CanvasItem) -> void:
	var t := node.create_tween()
	t.tween_property(node, "modulate", Color(1.6, 0.5, 0.5), 0.06)
	t.tween_property(node, "modulate", Color.WHITE, 0.18)


func _glow(node: CanvasItem) -> void:
	var t := node.create_tween()
	t.tween_property(node, "modulate", Color(1.5, 1.4, 0.8), 0.3)
	t.tween_property(node, "modulate", Color.WHITE, 0.6)


## Numbers float up from a little above the node's centre; over the hero, from just above its
## cell (no frame reaches higher), straight over its head, wherever the fighter scale and pivot
## put it.
func _float_at(node: Control, text: String, kind: String, offset := Vector2.ZERO) -> void:
	var colour := UIKit.GOLD if kind == "money" else UIKit.kind_colour(kind, true)
	if kind == "good":
		colour = Color(0.98, 0.93, 0.6)
	elif kind == "bad":
		colour = Color(1.0, 0.45, 0.4)
	var at: Vector2 = _over_hero(10.0) if node == %HeroHolder else UIKit.centre_in(node, %FX) - Vector2(0, 60)
	UIKit.float_text(%FX, text, colour, at + offset, 40)


## A point in %FX, `gap` above the top of the hero's cell, over its pivot (drawn at its centre x).
func _over_hero(gap: float) -> Vector2:
	var at := Vector2(_hero.size.x / 2.0, _hero.sprite_rect().position.y - gap)
	return (%FX as Control).get_global_transform().affine_inverse() * (_hero.get_global_transform() * at)


func _bubble(over: Control, text: String) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"InsetPanel"
	var l := UIKit.label(text, "BoldLabel", 22)
	panel.add_child(l)
	%FX.add_child(panel)
	var at := UIKit.centre_in(over, %FX)
	panel.position = at - Vector2(panel.get_minimum_size().x / 2.0, 220 * _k)
	var t := panel.create_tween()
	t.tween_interval(1.2 / _speed())
	t.tween_property(panel, "modulate:a", 0.0, 0.3)
	t.tween_callback(panel.queue_free)


## Show the banner; with a positive duration it fades out again afterwards.
func _banner(text: String, seconds: float) -> void:
	%Banner.text = text
	%Banner.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(%Banner, "modulate:a", 1.0, 0.25)
	if seconds > 0.0:
		t.tween_interval(seconds / _speed())
		t.tween_property(%Banner, "modulate:a", 0.0, 0.3)
		await t.finished
