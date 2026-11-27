class_name ShopMenu
extends RefCounted
## Python section 5: shop_menu() and drone_menu() as data. Decides which rows exist for this
## player, in the Python's order and numbering, with each row's exact Python text (minus the
## leading "<num> "). Card UIs read the structured fields; tooltips and the parity harness
## read "text".
##
## Row: {num, item, text, name, effect, cost, left (-1 = unlimited), greyed, buyable}
## Special: {num, action ("water_sample" | "socks" | "switch_relic"), text}

const BOOK_ROWS := [
	["atk", "Book of Attack", "x%d atk"],
	["def", "Book of Defence", "x%d def"],
	["spd", "Book of Speed", "x%d spd"],
	["hp", "Book of Max HP", "x%d max hp after winning next fight"],
	["heal", "Book of Healing", ""],
]


static func _row(num: int, item: String, text: String, name: String, effect: String,
		cost: int, left: int, greyed: bool, buyable: bool = true) -> Dictionary:
	return {"num": num, "item": item, "text": text, "name": name, "effect": effect,
			"cost": cost, "left": left, "greyed": greyed, "buyable": buyable}


## Returns {"rows": [...], "specials": [...]}.
static func shop_rows(player: PlayerState, level: int) -> Dictionary:
	var rows: Array[Dictionary] = []
	var i := 1
	var left := 0

	# Slot 1: drone upgrade menu / Sword / Battery
	if player.relic == "yd":
		rows.append(_row(i, "yds", "Ray-24 upgrade menu", "RAY-24 upgrades", "", 0, -1, false))
		i += 1
	elif player.relic != "e-sword" and not player.used_e_sword_before:
		left = Values.LIMIT["sword"] - player.bought["sword"]
		rows.append(_row(i, "sword", "Sword (+%d atk) - %d (%d left)" % [Values.FLAT_ITEM_GAIN, Values.PRICE["sword"], left],
				"Sword", "+%d atk" % Values.FLAT_ITEM_GAIN, Values.PRICE["sword"], left, left == 0))
		i += 1
	else:
		left = Values.LIMIT["battery"] - player.bought["battery"]
		rows.append(_row(i, "battery", "Battery for Countering - %d (%d left)" % [Values.PRICE["battery"], left],
				"Battery", "for Countering", Values.PRICE["battery"], left, left == 0))
		i += 1

	# Shield
	left = Values.LIMIT["shield"] - player.bought["shield"]
	rows.append(_row(i, "shield", "Shield (+%d def) - %d (%d left)" % [Values.FLAT_ITEM_GAIN, Values.PRICE["shield"], left],
			"Shield", "+%d def" % Values.FLAT_ITEM_GAIN, Values.PRICE["shield"], left, left == 0))
	i += 1

	# Boots (blocked by Cursed Socks; the number is still used up)
	if player.artefact == "socks":
		rows.append(_row(i, "boots", "Boots (+%d spd) - cannot buy due to Cursed Socks-some bad curse will occur if you try putting that sock into a sealed space, so this game might crash" % Values.FLAT_ITEM_GAIN,
				"Boots", "sealed by Cursed Socks", Values.PRICE["boots"], 0, true, false))
	else:
		left = Values.LIMIT["boots"] - player.bought["boots"]
		rows.append(_row(i, "boots", "Boots (+%d spd) - %d (%d left)" % [Values.FLAT_ITEM_GAIN, Values.PRICE["boots"], left],
				"Boots", "+%d spd" % Values.FLAT_ITEM_GAIN, Values.PRICE["boots"], left, left == 0))
	i += 1

	# Chicken
	if player.relic in ["gk", "dk"]:
		rows.append(_row(i, "chicken", "Chicken (heal max) - %d (∞ left)" % Values.PRICE["chicken"],
				"Chicken", "heal max", Values.PRICE["chicken"], -1, false))
	else:
		var card := GameEngine.chicken_variant(player.relic)  # "plain", "bk" or "sk"
		left = Values.CHICKEN_LIMIT[card] - player.bought["chicken"]
		rows.append(_row(i, "chicken", "Chicken (+%d hp if missing >=%d) - %d (%d left)" % [Values.CHICKEN_HEAL[card], Values.CHICKEN_MIN_MISSING, Values.PRICE["chicken"], left],
				"Chicken", "+%d hp if missing >=%d" % [Values.CHICKEN_HEAL[card], Values.CHICKEN_MIN_MISSING],
				Values.PRICE["chicken"], left, left == 0))
	i += 1

	# Books
	for b: Array in BOOK_ROWS:
		var key: String = b[0]
		var effect: String = (b[2] % Values.BOOK_MULTIPLIER) if b[2] != "" else "hp → max hp"
		left = Values.LIMIT["book"] - player.books[key]
		rows.append(_row(i, "book_" + key, "%s (%s) - %d (%d left)" % [b[1], effect, Values.PRICE["book"], left],
				b[1], effect, Values.PRICE["book"], left, left == 0))
		i += 1

	# Elixir (The Damned Proof of Devotion)
	if player.artefact == "devotion":
		left = Values.LIMIT["elixir"] - player.bought_elixir_this_visit
		var effect := "max hp-%d, spd-%d, extra spd+%d, extra spd -%d after fight for %d turns" % [player.bought["elixir"] + 1, Values.ELIXIR_SPD_LOSS, Values.ELIXIR_EXTRA_SPD, Values.ELIXIR_SPD_DECAY, Values.ELIXIR_FIGHTS]
		rows.append(_row(i, "elixir", "Elixir (*onster) - %s - %d (%d left)" % [effect, Values.PRICE["elixir"], left],
				"Elixir (*onster)", effect, Values.PRICE["elixir"], left, left == 0))
		i += 1

	# Forbidden Ink (Forbidden Book)
	if player.relic == "forbidden":
		left = Values.LIMIT["ink"] - player.forbidden_ink_total
		rows.append(_row(i, "ink", "Forbidden Ink (insta-kill next monster when entering next fight) - %d (%d left)" % [Values.PRICE["ink"], left],
				"Forbidden Ink", "insta-kill next monster when entering next fight", Values.PRICE["ink"], left, left == 0))
		i += 1

	var specials: Array[Dictionary] = []
	if player.artefact == "ar":
		# Same helper the payout uses, so the advertised figure includes the drone track-4
		# stage-4 doubling instead of understating it.
		specials.append({"num": 235, "action": "water_sample",
				"text": "Test water sample (max hp-%d, money+%d)" % [Values.AR_MAX_HP_LOSS, GameEngine.water_sample_reward(player, level)]})
	if player.artefact == "socks":
		specials.append({"num": 777, "action": "socks", "text": "Activate cursed socks"})
	if player.artefact == "carrier":
		# DEVIATION from the Python, which prints the relic's key ("yd"): the port shows its
		# name (owner decision, PORT_PLAN.md §10). parity.py rewrites the Python line to match.
		specials.append({"num": 888, "action": "switch_relic",
				"text": "Switch to next relic (currently active: %s)" % Content.RELIC_NAMES.get(player.relic, player.relic)})
	return {"rows": rows, "specials": specials}


## drone_menu()'s display. Returns {"atk", "slots_used", "header", "tracks": [...]} where each
## track is {track, name, stage, header, next_cost (-1 at max), stages: [{stage, text, greyed}]}.
static func drone_rows(player: PlayerState) -> Dictionary:
	var d := player.drone
	var tracks: Array[Dictionary] = []
	for track in range(4):
		var stages: Array[Dictionary] = []
		for stage in range(1, Values.DRONE_STAGES + 1):
			var desc: String = Content.DRONE_STAGE_DESCS[track][stage - 1].format(
					{"atk": d.atk, "atk2": d.atk * Values.DRONE_MISSILE_MULTIPLIER})
			# Readable: stages you own plus the next one you can buy.
			stages.append({"stage": stage, "text": desc, "greyed": stage > d.stages[track] + 1})
		var next_cost: int = -1
		if d.stages[track] < Values.DRONE_STAGES:
			next_cost = Values.DRONE_STAGE_COSTS[track][d.stages[track]]
		tracks.append({"track": track, "name": Content.DRONE_TRACK_NAMES[track], "stage": d.stages[track],
				"header": "%d %s-stage %d/%d" % [track + 1, Content.DRONE_TRACK_NAMES[track], d.stages[track], Values.DRONE_STAGES],
				"next_cost": next_cost, "stages": stages})
	return {"atk": d.atk, "slots_used": d.slots_used,
			"header": "RAY-24    Drone atk:%d    Upgrade slot %d/%d" % [d.atk, d.slots_used, Values.DRONE_SLOTS],
			"tracks": tracks}
