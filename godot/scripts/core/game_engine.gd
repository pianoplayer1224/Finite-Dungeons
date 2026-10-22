class_name GameEngine
extends RefCounted
## Python section 4: ENGINE. Pure game logic: every function mutates state and returns
## data-only event dictionaries for the UI to show. No text, no nodes, no autoloads.
##
## Kept function-for-function with FiniteDungeons.py (same names, argument order, branch
## shapes and payload keys) so the two can be diffed. Python (events, died) tuples are
## {"events": [...], "died": bool}; fight() returns {"won": bool, "events": [...]}.
## The "RUN FLOW" section at the bottom is logic the Python keeps in its terminal UI
## (run(), pre_fight()), lifted here unchanged so the GUI and the parity harness share it.


static func unlocked_relics(highest: int) -> Array[String]:
	var out: Array[String] = []
	for pair: Array in Values.RELIC_UNLOCKS:
		if highest >= pair[1]:
			out.append(pair[0])
	return out


static func unlocked_artefacts(highest: int) -> Array[String]:
	var out: Array[String] = []
	for pair: Array in Values.ARTEFACT_UNLOCKS:
		if highest >= pair[1]:
			out.append(pair[0])
	return out


## Deduct VITALITY_MONEY_LOSS of current money if artefact is Heart of Excessive Vitality.
static func vitality_money_penalty(player: PlayerState) -> Array:
	var out := []
	if player.artefact == "vitality" and player.money > 0:
		var penalty := player.money * Values.VITALITY_MONEY_LOSS
		player.money -= penalty
		out.append({"type": "vitality_penalty", "amount": penalty})
	return out


## Pay out the Coinpot bonus accumulated on leaving the shop.
static func coinpot_payout(player: PlayerState) -> Array:
	var out := []
	if player.coinpot_bonus > 0:
		if player.drone.stages[3] == 4:
			player.coinpot_bonus *= Values.DRONE_INCOME_MULTIPLIER
		out.append({"type": "coinpot_payout", "amount": player.coinpot_bonus})
		player.money += player.coinpot_bonus
		player.coinpot_bonus = 0
	return out


## Picture of Family: revive once to REVIVE_HP. Returns true if it fired.
##
## EVERY place that can drop the player to 0 HP must call this - combat damage, the vitality
## drain, and the shop's elixir/water-sample self-harm alike - otherwise the relic silently
## fails to pay out on that death.
static func try_revive(player: PlayerState, out: Array, in_combat: bool) -> bool:
	if player.hp <= 0 and player.relic == "family" and not player.revive_used:
		# The shop deaths clamp hp to max_hp, so they always arrive here with max HP at 0 or
		# below. You cannot hold 1 HP in a 0-capacity body, so the picture drags that back to
		# 1 as well - a revive into an instant second death would not be a revive.
		player.max_hp = maxi(player.max_hp, Values.REVIVE_HP)
		player.hp = Values.REVIVE_HP
		player.revive_used = true
		player.revived_this_fight = true
		out.append({"type": "revive", "in_combat": in_combat})
		return true
	return false


# ---------- shop purchases ----------

static func blocked(item: String, reason: String, extra: Dictionary = {}) -> Dictionary:
	var ev := {"type": "buy_blocked", "item": item, "reason": reason}
	ev.merge(extra)
	return ev


## Attempt one shop purchase. Returns {"events": [...], "died": died_in_shop}.
static func try_buy(player: PlayerState, item: String, ac: Dictionary) -> Dictionary:
	var out := []

	if item in ["sword", "shield", "boots"]:
		if player.bought[item] >= Values.LIMIT[item]:
			out.append(blocked(item, "limit"))
		elif item == "boots" and player.artefact == "socks":
			out.append(blocked(item, "socks"))
		elif player.money < Values.PRICE[item]:
			out.append(blocked(item, "money"))
		else:
			player.money -= Values.PRICE[item]
			player.bought[item] += 1
			if item == "sword":
				player.atk += Values.FLAT_ITEM_GAIN
			elif item == "shield":
				player.df += Values.FLAT_ITEM_GAIN
			else:
				player.spd += Values.FLAT_ITEM_GAIN
			out.append({"type": "purchased", "item": item, "cost": Values.PRICE[item]})

	elif item == "chicken":
		out.append_array(buy_chicken(player, ac))

	elif item.begins_with("book_"):
		var key: String = item.split("_")[1]
		if player.books[key] >= Values.LIMIT["book"]:
			out.append(blocked("book", "limit", {"key": key}))
		elif player.money < Values.PRICE["book"]:
			out.append(blocked("book", "money", {"key": key}))
		elif key == "hp" and player.socks_sealed:
			# Refused before charging (originally this still cost 3 money and a purchase)
			out.append(blocked("book", "sealed", {"key": key}))
		else:
			if key == "heal":
				player.hp = player.max_hp
			elif key == "hp":
				player.pending_hp_multiplier *= Values.BOOK_MULTIPLIER
			elif key == "spd":
				player.spd *= Values.BOOK_MULTIPLIER
			elif key == "atk":
				player.atk *= Values.BOOK_MULTIPLIER
			elif key == "def":
				player.df *= Values.BOOK_MULTIPLIER
			player.books[key] += 1
			player.money -= Values.PRICE["book"]
			out.append({"type": "purchased", "item": "book", "key": key, "cost": Values.PRICE["book"]})

	elif item == "battery":
		if player.relic != "e-sword":
			out.append(blocked("battery", "no_esword"))
		elif player.bought["battery"] >= Values.LIMIT["battery"]:
			out.append(blocked("battery", "limit"))
		elif player.money < Values.PRICE["battery"]:
			out.append(blocked("battery", "money"))
		else:
			player.counters += Values.BATTERY_COUNTERS
			player.money -= Values.PRICE["battery"]
			player.bought["battery"] += 1
			out.append({"type": "purchased", "item": "battery", "cost": Values.PRICE["battery"]})

	elif item == "ink":
		if player.forbidden_ink_total >= Values.LIMIT["ink"]:
			out.append(blocked("ink", "max"))
		elif player.forbidden_ink >= Values.INK_HOLD:
			out.append(blocked("ink", "held"))
		elif player.money < Values.PRICE["ink"]:
			out.append(blocked("ink", "money"))
		else:
			player.forbidden_ink += 1
			player.forbidden_ink_total += 1
			player.money -= Values.PRICE["ink"]
			out.append({"type": "purchased", "item": "ink", "cost": Values.PRICE["ink"],
					"total": player.forbidden_ink_total})

	elif item == "elixir":
		return buy_elixir(player, ac)

	return {"events": out, "died": false}


## Which membership card (if any) governs chicken purchases.
static func chicken_variant(relic: String) -> String:
	return relic if relic in ["bk", "sk", "gk", "dk"] else "plain"


static func buy_chicken(player: PlayerState, ac: Dictionary) -> Array:
	var out := []
	var variant := chicken_variant(player.relic)

	if variant in ["bk", "sk"]:
		var limit: int = Values.CHICKEN_LIMIT[variant]
		if player.bought["chicken"] >= limit:
			out.append(blocked("chicken", "limit", {"variant": variant}))
		elif player.money < Values.PRICE["chicken"]:
			out.append(blocked("chicken", "money", {"variant": variant}))
		elif player.max_hp - player.hp < Values.CHICKEN_MIN_MISSING:
			out.append(blocked("chicken", "hp_full", {"variant": variant}))
		else:
			var healed: int = mini(player.hp + Values.CHICKEN_HEAL[variant], player.max_hp) - player.hp
			player.hp += healed
			player.money -= Values.PRICE["chicken"]
			player.bought["chicken"] += 1
			out.append({"type": "purchased", "item": "chicken", "variant": variant,
					"cost": Values.PRICE["chicken"], "healed": healed})

	elif variant == "gk":
		if player.money < Values.PRICE["chicken"]:
			out.append(blocked("chicken", "money", {"variant": variant}))
		else:
			var healed := player.max_hp - player.hp
			player.hp = player.max_hp
			player.money -= Values.PRICE["chicken"]
			player.bought["chicken"] += 1
			out.append({"type": "purchased", "item": "chicken", "variant": variant,
					"cost": Values.PRICE["chicken"], "healed": healed})

	elif variant == "dk":
		# Diamond card removes ALL purchase conditions - including having the money.
		var healed := player.max_hp - player.hp
		player.hp = player.max_hp
		player.money -= Values.PRICE["chicken"]
		player.bought["chicken"] += 1
		if player.money < 0:
			ac["negative_money"] = true
		out.append({"type": "purchased", "item": "chicken", "variant": variant,
				"cost": Values.PRICE["chicken"], "healed": healed})

	else:
		if player.bought["chicken"] >= Values.CHICKEN_LIMIT["plain"]:
			out.append(blocked("chicken", "limit", {"variant": variant}))
		elif player.money < Values.PRICE["chicken"]:
			out.append(blocked("chicken", "money", {"variant": variant}))
		elif player.max_hp - player.hp < Values.CHICKEN_MIN_MISSING:
			out.append(blocked("chicken", "hp_full", {"variant": variant}))
		else:
			var heal: int = Values.CHICKEN_HEAL["plain"]
			if player.drone.stages[2] == 4:  # FARP stage 4 multiplies all healing
				heal *= Values.DRONE_HEAL_MULTIPLIER
			var healed := mini(player.hp + heal, player.max_hp) - player.hp
			player.hp += healed
			player.money -= Values.PRICE["chicken"]
			player.bought["chicken"] += 1
			out.append({"type": "purchased", "item": "chicken", "variant": variant,
					"cost": Values.PRICE["chicken"], "healed": healed})

	return out


static func buy_elixir(player: PlayerState, ac: Dictionary) -> Dictionary:
	var out := []
	if player.bought_elixir_this_visit >= Values.LIMIT["elixir"]:
		out.append(blocked("elixir", "visit_limit"))
	elif player.money < Values.PRICE["elixir"]:
		out.append(blocked("elixir", "money"))
	else:
		player.money -= Values.PRICE["elixir"]
		player.bought["elixir"] += 1
		player.bought_elixir_this_visit += 1
		player.max_hp -= player.bought["elixir"]
		if player.hp > player.max_hp:
			player.hp = player.max_hp
		if player.hp <= 0 and not try_revive(player, out, false):
			ac["shop_death"] = true
			out.append({"type": "shop_death", "cause": "elixir"})
			return {"events": out, "died": true}

		player.spd -= Values.ELIXIR_SPD_LOSS
		player.extra_spd += Values.ELIXIR_EXTRA_SPD
		player.elixir_timers.append(Values.ELIXIR_FIGHTS)
		out.append({"type": "purchased", "item": "elixir", "cost": Values.PRICE["elixir"],
				"total": player.bought["elixir"]})
	return {"events": out, "died": false}


static func activate_socks(player: PlayerState) -> Array:
	var out := []
	if player.socks_sealed:
		out.append({"type": "socks_blocked", "reason": "already"})
	elif player.hp > Values.SOCKS_MAX_HP:
		out.append({"type": "socks_blocked", "reason": "hp_too_high"})
	else:
		var atk_gain := player.max_hp - player.hp
		player.atk += atk_gain
		player.max_hp = player.hp
		player.socks_sealed = true
		out.append({"type": "socks_activated", "atk_gain": atk_gain,
				"max_hp": player.max_hp})
	return out


## Money the 235 option pays at this level (doubled by drone track 4 stage 4).
static func water_sample_reward(player: PlayerState, level: int) -> int:
	@warning_ignore("integer_division")
	var base: int = ((level - 1) / Values.AR_LEVEL_STEP) ** Values.AR_POWER
	return base * Values.DRONE_INCOME_MULTIPLIER if player.drone.stages[3] == 4 else base


## Abyssal Rad-Blood Oath's 235 shop option. Returns {"events": [...], "died": died_in_shop}.
static func take_water_sample(player: PlayerState, level: int, ac: Dictionary) -> Dictionary:
	var out := []
	if player.ar_used:
		out.append({"type": "water_sample_blocked"})
		return {"events": out, "died": false}

	player.ar_used = true
	player.max_hp -= Values.AR_MAX_HP_LOSS
	player.hp = mini(player.hp, player.max_hp)
	var arb := water_sample_reward(player, level)
	player.money += arb  # the reward used to be printed but never actually granted
	out.append({"type": "water_sample", "money": arb, "max_hp_lost": Values.AR_MAX_HP_LOSS})

	if player.hp <= 0 and not try_revive(player, out, false):
		ac["shop_death"] = true
		out.append({"type": "shop_death", "cause": "water_sample"})
		return {"events": out, "died": true}
	return {"events": out, "died": false}


## Carrier of Legend's 888 shop option.
static func switch_relic(player: PlayerState) -> Array:
	var out := []
	if player.switches >= Values.CARRIER_RELICS - 1:
		out.append({"type": "relic_switch_blocked"})
		return out

	player.switches += 1
	player.drone = DroneState.new()
	player.hp = Values.CARRIER_RESET
	player.atk = Values.CARRIER_RESET
	player.df = Values.CARRIER_RESET
	player.spd = Values.CARRIER_RESET

	player.active_relic_index += 1
	player.relic = player.relics[player.active_relic_index]
	out.append({"type": "relic_switched", "relic": player.relic,
			"index": player.active_relic_index})

	if player.relic == "meowton":
		out.append({"type": "meowton_equipped"})
		player.df -= Values.MEOWTON_DEF_LOSS
	if player.relic == "e-sword":
		player.used_e_sword_before = true
		var had_sword: bool = player.bought.get("sword", 0) > 0
		if not had_sword:
			player.atk += Values.ESWORD_ATK
			player.counters = 0
		out.append({"type": "esword_equipped", "had_sword": had_sword})
	return out


# ---------- drone upgrades ----------

## Advance one drone track a single stage and apply its effect.
##
## Used by BOTH paid purchases and Track 4's free auto-upgrades, so free upgrades always grant
## the real effect (they used to only bump the number).
static func apply_drone_stage(player: PlayerState, track: int) -> void:
	var d := player.drone
	d.stages[track] += 1
	var stage := d.stages[track]

	if track == 0:
		d.atk += Values.DRONE_T1_ATK_GAIN[stage - 1]
	elif track == 2 and stage >= 2:
		player.hp = player.max_hp
	elif track == 3:
		if stage == 2:
			for t in range(3):
				if d.stages[t] == 1:
					apply_drone_stage(player, t)
		elif stage == 3:
			for t in range(3):
				if d.stages[t] == 0:
					apply_drone_stage(player, t)
		elif stage == 4:
			for t in range(3):
				if d.stages[t] == 3:
					apply_drone_stage(player, t)


static func buy_drone_upgrade(player: PlayerState, track: int) -> Array:
	var out := []
	var d := player.drone
	if d.slots_used >= Values.DRONE_SLOTS:
		out.append({"type": "drone_blocked", "reason": "slots", "track": track})
	elif d.stages[track] >= Values.DRONE_STAGES:
		out.append({"type": "drone_blocked", "reason": "max", "track": track})
	else:
		var stage := d.stages[track] + 1
		var cost: int = Values.DRONE_STAGE_COSTS[track][stage - 1]
		if player.money < cost:
			out.append({"type": "drone_blocked", "reason": "money", "track": track})
		else:
			player.money -= cost
			d.slots_used += 1
			apply_drone_stage(player, track)
			out.append({"type": "drone_upgraded", "track": track, "stage": stage,
					"cost": cost, "drone_atk": d.atk})
	return out


# ---------- fight ----------

static func player_strike(player: PlayerState, monster: Entity, out: Array, ac: Dictionary) -> void:
	var atk := player.total_atk()
	var df := monster.total_df()
	var dmg := maxi(atk - df, Values.MIN_DAMAGE)
	var monster_was_full := (monster.hp == monster.max_hp)
	var hp_before := monster.hp
	monster.hp -= dmg
	out.append({"type": "player_hit", "dmg": dmg, "player_hp": player.hp,
			"monster_hp_before": hp_before, "monster_hp": monster.hp})
	# 雑魚: a true one-hit kill by YOUR attack (works on level 30 too; ink and drone kills
	# don't count).
	if monster_was_full and monster.hp <= 0:
		ac["one_shot"] = true


static func monster_strike(monster: Entity, player: PlayerState, out: Array) -> void:
	var atk := monster.total_atk()
	var df := player.total_df()
	var dmg := maxi(atk - df, Values.MIN_DAMAGE)
	var hp_before := player.hp
	player.hp -= dmg
	out.append({"type": "monster_hit", "dmg": dmg, "player_hp_before": hp_before,
			"player_hp": player.hp, "monster_hp": monster.hp})

	try_revive(player, out, true)


## RAY-24's start-of-fight attack (drone track 2).
static func drone_volley(player: PlayerState, monster: Entity, out: Array, ac: Dictionary) -> void:
	var stage := player.drone.stages[1]
	if stage == 0:
		return
	var datk := player.drone.atk

	if stage < 4:
		var dmg := 0
		if stage == 1:
			dmg = maxi(datk - monster.df, Values.MIN_DAMAGE)
		elif stage == 2:
			dmg = maxi(datk * Values.DRONE_MISSILE_MULTIPLIER - monster.df, Values.MIN_DAMAGE)
		else:
			dmg = maxi(datk * Values.DRONE_MISSILE_MULTIPLIER - maxi(0, monster.df - datk * Values.DRONE_MISSILE_MULTIPLIER), Values.MIN_DAMAGE)
		out.append({"type": "drone_shot", "shot": 0, "dmg": dmg, "shreds_df": false,
				"monster_hp_before": monster.hp, "monster_hp": monster.hp - dmg})
		monster.hp -= dmg
	else:
		# Stage 4: DRONE_STAGE4_MISSILES shots, each also shreds DEF by its damage x DRONE_SHRED_MULTIPLIER.
		for shot in range(Values.DRONE_STAGE4_MISSILES):
			var dmg := maxi(datk * Values.DRONE_MISSILE_MULTIPLIER - maxi(0, monster.df - datk * Values.DRONE_MISSILE_MULTIPLIER), Values.MIN_DAMAGE)
			var new_df := maxi(monster.df - dmg * Values.DRONE_SHRED_MULTIPLIER, 0)
			out.append({"type": "drone_shot", "shot": shot, "dmg": dmg, "shreds_df": true,
					"monster_hp_before": monster.hp, "monster_hp": monster.hp - dmg,
					"monster_df_before": monster.df, "monster_df": new_df,
					"df_loss": dmg * Values.DRONE_SHRED_MULTIPLIER})
			monster.hp -= dmg
			monster.df = new_df
			if shot == Values.DRONE_STAGE4_MISSILES - 2 and monster.hp <= 0:
				ac["okill"] = true
				out.append({"type": "drone_overkill"})


## Simulate the whole fight. Returns {"won": player_won, "events": [...]}.
static func fight(player: PlayerState, monster: Entity, level: int, ac: Dictionary) -> Dictionary:
	var out := []

	# Guaranteed one-shot? Smirk before the fight even starts.
	if player.total_atk() >= monster.hp + monster.df:
		out.append({"type": "smirk"})

	if player.relic == "yd":
		drone_volley(player, monster, out, ac)

	# Heart of Excessive Vitality wallet drain. Clamped at 0 so negative money can't heal
	# you, and dying here is a real death - even with ink in your pocket.
	if player.vitality_drain_pending:
		player.vitality_drain_pending = false
		var drain := maxi(0, floori(player.money / Values.VITALITY_DRAIN_DIVISOR))
		player.hp -= drain
		out.append({"type": "vitality_drain", "amount": drain, "player_hp": player.hp})
		try_revive(player, out, true)
		if not player.is_alive():
			return {"won": false, "events": out}

	# Forbidden Ink: instant kill.
	if player.forbidden_ink > 0:
		# Plays the list bottom-up: simplest formula first, the "formula to beat this game"
		# saved for the last ink.
		var msg_index := mini(Values.LIMIT["ink"] - player.forbidden_ink_total, Content.FORBIDDEN_MESSAGES.size() - 1)
		out.append({"type": "ink_kill", "message_index": msg_index,
				"final_boss": level == Values.FINAL_LEVEL})
		monster.hp = 0
		player.forbidden_ink -= 1
		return {"won": true, "events": out}

	while player.is_alive() and monster.is_alive():
		if player.total_spd() >= monster.total_spd():
			player_strike(player, monster, out, ac)
			if not monster.is_alive():
				break
			if player.counters > 0:
				player.counters -= 1
				player_strike(player, monster, out, ac)
			else:
				monster_strike(monster, player, out)
		else:
			if player.counters > 0:
				player.counters -= 1
				player_strike(player, monster, out, ac)
			else:
				monster_strike(monster, player, out)
				if not player.is_alive():
					break
			if monster.is_alive():
				player_strike(player, monster, out, ac)

	var won := player.is_alive()
	# The flag survives across the shop, so a revive bought at the elixir counter still pays
	# out on the next monster you put down.
	if won and player.revived_this_fight:
		out.append({"type": "pic_kill"})
		ac["pic_kill"] = true
		player.revived_this_fight = false
	return {"won": won, "events": out}


## Rewards and upkeep after winning a fight.
static func post_fight(player: PlayerState, level: int) -> Array:
	var out := []

	if player.pending_hp_multiplier > 1:
		# A book bought BEFORE the socks sealed you still tries to fire here. The seal wins -
		# otherwise you keep the sealed ATK payout and get your max HP back, which is the
		# whole thing the seal is meant to cost you.
		if player.socks_sealed:
			out.append({"type": "book_hp_fizzled"})
		else:
			player.max_hp = int(player.max_hp * player.pending_hp_multiplier)
			out.append({"type": "book_hp_applied", "max_hp": player.max_hp})
		player.pending_hp_multiplier = 1

	# Money. Track 4 stage 4 "doubles income": it pays everything above again,
	# (DRONE_INCOME_MULTIPLIER - 1) more times.
	player.money += Values.WIN_MONEY
	var stages := player.drone.stages
	if stages[3] >= 1:
		player.money += player.drone.atk
	if stages[3] >= 2:
		player.money += Values.DRONE_T4_MONEY[0]
	if stages[3] >= 3:
		player.money += Values.DRONE_T4_MONEY[1]
	if stages[3] >= 4:
		player.money += (Values.DRONE_INCOME_MULTIPLIER - 1) * (
				Values.WIN_MONEY + player.drone.atk + Values.DRONE_T4_MONEY[0] + Values.DRONE_T4_MONEY[1])

	# Drone healing (track 3): the stages add up, and stage 4 "doubles" the total by healing
	# it again, (DRONE_HEAL_MULTIPLIER - 1) more times.
	var heals: Array = Values.DRONE_HEALS + [(Values.DRONE_HEAL_MULTIPLIER - 1) * Content._sum(Values.DRONE_HEALS)]
	for i in heals.size():
		var threshold := i + 1
		if stages[2] >= threshold:
			player.hp = mini(player.hp + heals[i], player.max_hp)

	if player.relic == "blessed" and level % Values.BLESSED_EVERY == 0:
		if not player.socks_sealed:
			player.max_hp += Values.BLESSED_MAX_HP
		player.hp = player.max_hp

	# Elixir hangover: extra SPD wears off after each fight following a drink.
	var remaining: Array[int] = []
	for timer in player.elixir_timers:
		timer -= 1
		player.extra_spd -= Values.ELIXIR_SPD_DECAY
		if timer > 0:
			remaining.append(timer)
	player.elixir_timers = remaining

	return out


# ============================================================
# RUN FLOW (from the Python's run() and pre_fight(), section 5)
# ============================================================
# The Python prints these effects inline; here they return events (types the Python's
# format_event does not have: esword_start, blessed_fumble, run_died, hard_mode,
# run_finished, run_quit, game_won, few_runs_win - EventText words them exactly as the
# Python prints them).

## run(): count the run, build the player, apply start-of-run effects in the Python's order.
## relic_choice: a relic key ("" for none), or the Carrier's Array of relic keys.
## Returns {"player": PlayerState, "events": [...]}.
static func start_run(profile: ProfileState, artefact: String, relic_choice: Variant) -> Dictionary:
	profile.runs += 1
	var player := PlayerState.new(relic_choice, artefact)
	var out := []

	if player.relic == "e-sword":
		player.atk += Values.ESWORD_ATK
		out.append({"type": "esword_start"})
	if artefact == "vitality":
		player.max_hp = Values.VITALITY_HP
		player.hp = Values.VITALITY_HP
	if player.relic == "meowton":
		player.df -= Values.MEOWTON_DEF_LOSS
		out.append({"type": "meowton_equipped"})
	# Blessed Emblem pinches you if it's anywhere in your luggage.
	var blessed_packed := ("blessed" in player.relics) if not player.relics.is_empty() else (player.relic == "blessed")
	if blessed_packed:
		player.hp -= Values.BLESSED_START_HP_LOSS
		out.append({"type": "blessed_fumble"})

	return {"player": player, "events": out}


## pre_fight() entry: once per level (NOT per shop visit) the elixir limit resets.
static func begin_level(player: PlayerState) -> void:
	player.bought_elixir_this_visit = 0


## pre_fight() "0 Start fight": Coinpot charges up the moment you leave for the fight, and the
## Vitality drain is armed. Call exactly once per fight, when the fight is committed.
static func leave_for_fight(player: PlayerState) -> void:
	if player.artefact == "coinpot" and player.money >= Values.COINPOT_STEP:
		player.coinpot_bonus += floorf(player.money / Values.COINPOT_STEP) * Values.COINPOT_PAY
	if player.artefact == "vitality":
		player.vitality_drain_pending = true


## The forecast pre_fight() prints when the fight starts.
static func fight_forecast(player: PlayerState, level: int) -> Dictionary:
	var atk := player.total_atk()
	var spd := player.total_spd()
	var df := player.total_df()
	var m := Entity.create_monster(level)
	return {"atk": atk, "df": df, "spd": spd, "m_atk": m.atk, "m_df": m.df, "m_spd": m.spd,
			"you_deal": maxi(atk - m.df, Values.MIN_DAMAGE),
			"monster_deals": maxi(m.atk - df, Values.MIN_DAMAGE),
			"you_first": spd >= m.spd}


## run()'s level-loop body after pre_fight() returned "start the fight".
## Returns {"won", "run_over", "game_won", "pre": [...], "fight": [...], "post": [...]}.
static func resolve_level(player: PlayerState, level: int, profile: ProfileState) -> Dictionary:
	var pre := vitality_money_penalty(player)
	pre.append_array(coinpot_payout(player))

	var res := fight(player, Entity.create_monster(level), level, profile.ac)
	var result := {"won": res["won"], "run_over": false, "game_won": false,
			"pre": pre, "fight": res["events"], "post": []}

	if not res["won"]:
		var post := end_of_run(profile, level)
		if player.money >= Values.RICH_MONEY:
			profile.ac["drich"] = true
		if level == Values.HARD_MODE_LEVEL and player.relic == "meowton" and player.artefact == "socks":
			profile.ac["hmode"] = true
			post.append({"type": "hard_mode"})
		post.append({"type": "run_finished", "runs": profile.runs})
		result["post"] = post
		result["run_over"] = true
		return result

	var post_events := post_fight(player, level)
	if level == Values.FINAL_LEVEL:
		post_events.append_array(win_game(profile))
		result["run_over"] = true
		result["game_won"] = true
	result["post"] = post_events
	return result


## end_of_run(): the levels beaten this run count towards the highest.
static func end_of_run(profile: ProfileState, level_died_at: int) -> Array:
	profile.highest = maxi(profile.highest, level_died_at - 1)
	return [{"type": "run_died", "level_completed": level_died_at - 1, "highest": profile.highest}]


## run()'s "dead" branch (died in the shop): no drich / hmode checks, as in the Python.
static func shop_death_end(profile: ProfileState, level: int) -> Array:
	var out := end_of_run(profile, level)
	out.append({"type": "run_finished", "runs": profile.runs})
	return out


## run()'s "quit" branch: quitting ends the run like a death would - levels beaten count.
static func quit_run(profile: ProfileState, level: int) -> Array:
	profile.highest = maxi(profile.highest, level - 1)
	return [{"type": "run_quit", "highest": profile.highest}]


## run() after the level loop: FINAL_LEVEL beaten.
static func win_game(profile: ProfileState) -> Array:
	var out := [{"type": "game_won"}]
	profile.highest = Values.FINAL_LEVEL
	if profile.runs <= Values.FEW_RUNS:
		profile.ac["trun"] = true
		out.append({"type": "few_runs_win"})
	return out
