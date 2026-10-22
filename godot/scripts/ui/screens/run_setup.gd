extends Control
## Run setup: the Python's choose_artefact() then choose_relic() (or choose_carrier_relics()
## when the artefact is Carrier of Legend). Locked items are shown greyed with their unlock
## level; the E-Sword (withheld) is hidden and the diamond card stays secret until unlocked.
## The detail panel replaces the Python's "505 show descriptions": it follows the hovered or
## focused card. A touch screen has no hover, so there a tap shows a card's details; it also
## chooses (Next / Start run confirms) or packs a Carrier relic (a tap on its slot takes it out).

const PHONE_DETAIL_WIDTH := 320.0   # the phone layout's details column, beside the cards
const PHONE_MARGIN := Vector2(16, 24)   # the phone layout's panel margins, across and down
## The phone layout's Carrier step has the slots over the cards: its cards are a little shorter
## (all are unlocked there, with no unlock line) so both rows still fit.
const PHONE_CARRIER_CARD_HEIGHT := 165.0

var args := {}
var _step := 1
var _artefact := ""
var _relic := ""
var _carrier: Array[String] = []
var _cards: Array[ItemCard] = []
var _slots: Container   # the Carrier slots (%Slots, a row over the cards)


func _ready() -> void:
	_slots = %Slots
	if UIKit.phone:
		_phone_layout()
	%Back.pressed.connect(_on_back)
	%Next.pressed.connect(_on_next)
	_show_step(1)


## The phone layout (UIKit.phone: a canvas of at least 1440 x 720): the details sit in a narrow
## column beside the cards instead of under them (icon above the text; long text scrolls), the
## Carrier's chosen relics in a row over them, and the cards are small (ItemCard.PHONE_SIZE),
## six to a row: every step's cards fit without scrolling.
func _phone_layout() -> void:
	var panel: Control = $Panel
	panel.offset_left = PHONE_MARGIN.x
	panel.offset_right = -PHONE_MARGIN.x
	panel.offset_top = PHONE_MARGIN.y
	panel.offset_bottom = -PHONE_MARGIN.y
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	var box: Control = $Panel/Box
	var cards: Control = $Panel/Box/CardScroll
	var detail: Control = $Panel/Box/Detail
	box.add_child(row)
	box.move_child(row, cards.get_index())
	cards.reparent(row)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.reparent(row)
	detail.custom_minimum_size = Vector2(PHONE_DETAIL_WIDTH, 0)
	%Icon.reparent(detail.get_node("Row/Text"))   # above the name, not beside it
	%Icon.get_parent().move_child(%Icon, 0)
	var text_scroll := ScrollContainer.new()   # a long description scrolls
	text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var detail_row: Control = detail.get_node("Row")
	detail.add_child(text_scroll)
	detail_row.reparent(text_scroll)   # (remove_child + add_child would lose the %Icon / %Desc names)
	detail_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	%Icon.custom_minimum_size = Vector2(80, 80)
	%Icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	%Name.add_theme_font_size_override("font_size", 26)
	%Desc.add_theme_font_size_override("normal_font_size", 20)
	%Cards.add_theme_constant_override("h_separation", 10)
	%Cards.add_theme_constant_override("v_separation", 10)
	%Banner.add_theme_font_size_override("font_size", 18)   # one line, Carrier step included
	%Slots.add_theme_constant_override("separation", 14)


## Content clear of a phone's camera cutout (App.safe_inset; see UIKit.keep_clear).
func keep_clear(inset: Vector2) -> void:
	UIKit.keep_clear($Panel, inset)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not App.instance.has_modal():
		_on_back()


func _highest() -> int:
	return GameState.profile.highest


func _is_unlocked(key: String) -> bool:
	return _highest() >= Content.UNLOCK_LEVEL[key]


## Withheld items (unlock level beyond the game) are not shown at all.
func _is_hidden(key: String) -> bool:
	return Content.UNLOCK_LEVEL[key] > Values.FINAL_LEVEL and not _is_unlocked(key)


func _show_step(step: int) -> void:
	_step = step
	UIKit.clear_children(%Cards)
	UIKit.clear_children(_slots)
	_cards.clear()
	_slots.visible = false
	var group := ButtonGroup.new()

	if step == 1:
		%Title.text = "Choose, with all your brain power, one artefact:"
		%Step.text = "Step 1 / 2"
		var any_unlocked := not GameEngine.unlocked_artefacts(_highest()).is_empty()
		%Banner.text = "No artefacts unlocked yet! You must continue without one."
		%Banner.visible = not any_unlocked
		_add_card("", "No artefact", "", false, group)
		for pair: Array in Values.ARTEFACT_UNLOCKS:
			_add_card(pair[0], UIKit.item_name(pair[0]), "", true, group)
		_select(_artefact)
		%Next.text = "Next"
	else:
		%Title.text = "Choose, very carefully, your relic:"
		%Step.text = "Step 2 / 2"
		if _artefact == "carrier":
			%Banner.text = "You chose the Carrier of Legend! Pick %d relics in order (only the first one is active at start)." % Values.CARRIER_RELICS
			if UIKit.touch:
				%Banner.text += " Tap a slot to take its relic out."
			%Banner.visible = true
			_slots.visible = true
			for pair: Array in Values.RELIC_UNLOCKS:
				_add_card(pair[0], UIKit.item_name(pair[0]), "", true, null)
			_refresh_slots()
		else:
			%Banner.visible = false
			_add_card("", "No relic", "", false, group)
			for pair: Array in Values.RELIC_UNLOCKS:
				_add_card(pair[0], UIKit.item_name(pair[0]), "", true, group)
			_select(_relic)
		%Next.text = "Start run"
	_update_next()


func _add_card(key: String, title: String, _sub: String, is_item: bool, group: ButtonGroup) -> void:
	if is_item and _is_hidden(key):
		return
	var locked := is_item and not _is_unlocked(key)
	var secret := locked and key == "dk"
	var card := ItemCard.new().setup(key, title, Content.unlock_label(key) if locked else "", locked, secret)
	if group != null:
		card.button_group = group
	else:
		card.toggle_mode = false
		if UIKit.phone:   # the Carrier step
			card.custom_minimum_size.y = PHONE_CARRIER_CARD_HEIGHT
	card.mouse_entered.connect(_show_detail.bind(key))
	card.focus_entered.connect(_show_detail.bind(key))
	card.pressed.connect(_on_card_pressed.bind(card))
	%Cards.add_child(card)
	_cards.append(card)


func _select(key: String) -> void:
	for card in _cards:
		if card.key == key:
			card.set_pressed_no_signal(true)
			card.grab_focus.call_deferred(true)
	_show_detail(key)


func _on_card_pressed(card: ItemCard) -> void:
	_show_detail(card.key)
	if card.locked:
		# The choice stays where it was, but the details stay on the locked card (on a touch
		# screen this tap is the only way to read them), so focus is not moved back.
		var chosen := _artefact if _step == 1 else _relic
		for c in _cards:
			c.set_pressed_no_signal(c.key == chosen and c.toggle_mode)
		App.instance.toast("Locked — %s" % Content.unlock_label(card.key), "warning")
		return
	if _step == 1:
		_artefact = card.key
		Sfx.play("select")
	elif _artefact == "carrier":
		if card.key in _carrier:
			App.instance.toast("You already picked that relic.", "warning")
		elif _carrier.size() < Values.CARRIER_RELICS:
			_carrier.append(card.key)
			Sfx.play("select")
			_refresh_slots()
	else:
		_relic = card.key
		Sfx.play("select")
	_update_next()


func _refresh_slots() -> void:
	UIKit.clear_children(_slots)
	for i in Values.CARRIER_RELICS:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(0, UIKit.PHONE_TAP) if UIKit.phone else Vector2(420, 104)
		if UIKit.phone:   # three across the row, each wide enough for the longest name
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_right = -10
		row.add_theme_constant_override("separation", 12)
		slot.add_child(row)
		var filled := i < _carrier.size()
		var icon := UIKit.icon_rect(_carrier[i] if filled else "", 48 if UIKit.phone else 80)
		row.add_child(icon)
		var text := VBoxContainer.new()
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(UIKit.label("Relic #%d%s" % [i + 1, " — active at start" if i == 0 else ""], "SoftLabel", 18))
		var empty := "(tap a relic below)" if UIKit.touch else "(click a relic below)"
		var title := UIKit.label(UIKit.item_name(_carrier[i]) if filled else empty, "BoldLabel" if filled else "SoftLabel", 20)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # the diamond card's name is wider than a slot
		text.add_child(title)
		row.add_child(text)
		UIKit.mouse_through(slot)
		UIKit.hover_tip(slot, "Click to take this relic out" if filled else "")
		var index := i
		slot.pressed.connect(func() -> void:
			if index < _carrier.size():
				_carrier.remove_at(index)
				_refresh_slots()
				_update_next())
		_slots.add_child(slot)
	for card in _cards:
		card.modulate.a = 0.45 if card.key in _carrier else 1.0


func _show_detail(key: String) -> void:
	var is_artefact := _step == 1
	%Icon.texture = UIKit.icon(key) if key != "" else null
	if key == "":
		%Name.text = "No artefact" if is_artefact else "No relic"
		%Desc.text = ""
		return
	var locked := not _is_unlocked(key)
	if key == "dk" and locked:
		%Icon.modulate = Color(0.1, 0.07, 0.05, 0.75)
		%Name.text = "????????"
		%Desc.text = "???????????\n" + UIKit.bb_colour(Content.unlock_label(key), UIKit.kind_colour("muted", true))
		return
	%Icon.modulate = Color(0.1, 0.07, 0.05, 0.75) if locked else Color.WHITE
	if is_artefact:
		%Name.text = Content.ARTEFACT_MENU_NAMES[key]
		%Desc.text = UIKit.desc_bbcode(Content.ARTEFACT_DESCRIPTIONS[key])
	else:
		%Name.text = Content.RELIC_NAMES[key]
		%Desc.text = UIKit.desc_bbcode(Content.RELIC_DESCRIPTIONS[key])
	if locked:
		%Desc.text += "\n" + UIKit.bb_colour(Content.unlock_label(key), UIKit.kind_colour("muted", true))


func _update_next() -> void:
	%Next.disabled = _step == 2 and _artefact == "carrier" and _carrier.size() < Values.CARRIER_RELICS


func _on_back() -> void:
	if _step == 2:
		_show_step(1)
	else:
		App.instance.go_to("main_menu")


func _on_next() -> void:
	if _step == 1:
		if _artefact != "carrier":
			_carrier.clear()
		_show_step(2)
		return
	var relic_choice: Variant = _carrier.duplicate() if _artefact == "carrier" else _relic
	GameState.start_run(_artefact, relic_choice)
	App.instance.go_to("camp")
