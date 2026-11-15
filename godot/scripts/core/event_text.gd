class_name EventText
extends RefCounted
## Python section 5 wording: format_event() and its tables, the colour of each event, and the
## small display formatters (stat bar, stats screen, fight forecast). The engine emits
## data-only events; ALL wording lives here. Strings are verbatim from FiniteDungeons.py,
## including leading "\n"s (UI code may strip them; the parity harness compares them).

# Blocked-purchase wording, keyed "item|reason". sword/shield/boots fall through to the
# templated version in format_event instead.
# DEVIATION from the Python, which has six "not enough money" phrasings: every refusal for money
# uses its own "Cannot buy X — not enough money." template (owner decision, PORT_PLAN.md §10).
# parity.py's port_deviations() maps the Python's lines to these.
static var BUY_BLOCKED_TEXT := {
	"chicken|limit": "Cannot buy Chicken — purchase limit reached.",
	"chicken|money": "Cannot buy Chicken — not enough money.",
	"chicken|hp_full": "Cannot buy Chicken — your hp is too high and would waste food if you bought chicken!",
	"book|limit": "Cannot buy Book — purchase limit reached.",
	"book|money": "Cannot buy Book — not enough money.",
	"book|sealed": "max hp sealed by socks, don't ask how or why",
	"battery|limit": "Cannot buy Battery — purchase limit reached.",
	"battery|money": "Cannot buy Battery — not enough money.",
	"battery|no_esword": "Your current sword is wooden, nowhere to put in battery!",
	"ink|max": "You can't write another formula down again, it hurt too much when you got laughed at last time!",
	"ink|held": "You already have a Forbidden Ink in your pocket, don't be greedy, ink spills easily!",
	"ink|money": "Cannot buy Forbidden Ink — not enough money.",
	"elixir|visit_limit": "Cannot buy Elixir — turn purchase limit reached.",
	"elixir|money": "Cannot buy Elixir — not enough money.",
	"boots|socks": "Cannot buy Boots — no Cursed Socks inside sealed spaces.",
}

const SHOP_DEATH_TEXT := {
	"elixir": "\nYou chug the elixir, hope it tasted good, as it's the last one you had.\n",
	"water_sample": "\nThe Blight was more cursed than radioactive — your body gives out right there in the shop.\n",
}

const DRONE_BLOCKED_TEXT := {
	"slots": "Upgrade failed-slot is full.",
	"max": "This upgrade is already at maximum level.",
	"money": "Cannot buy upgrade — not enough money.",
}

static var SOCKS_BLOCKED_TEXT := {
	"already": "Cursed Socks are already activated.",
	"hp_too_high": "Cursed Socks cannot activate unless HP is %d or less." % Values.SOCKS_MAX_HP,
}

## Colour kind of each event's lines (kinds are the keys of Values.TEXT_COLOURS;
## missing = "normal"). The run-flow events follow the Python's print()/paint() calls.
const EVENT_COLOUR := {
	"buy_blocked": "warning", "purchased": "good", "shop_death": "bad",
	"socks_blocked": "warning", "socks_activated": "good", "water_sample": "story",
	"water_sample_blocked": "warning", "relic_switch_blocked": "warning",
	"drone_blocked": "warning", "drone_upgraded": "good",
	"vitality_penalty": "money", "coinpot_payout": "money",
	"smirk": "good", "drone_shot": "good", "drone_overkill": "good",
	"vitality_drain": "bad", "ink_kill": "good",
	"player_hit": "good", "monster_hit": "bad",
	"revive": "story", "pic_kill": "story",
	"book_hp_applied": "good", "book_hp_fizzled": "warning",
	# run flow (Godot-only event types, coloured as the Python prints them)
	"blessed_fumble": "story", "run_died": "bad", "game_won": "good", "few_runs_win": "good",
}


static func colour_of(ev: Dictionary) -> String:
	return EVENT_COLOUR.get(ev["type"], "normal")


## Python str.capitalize(): first character upper, the rest lower.
static func py_capitalize(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1).to_lower()


## Render one engine event into 0+ lines.
static func format_event(ev: Dictionary) -> Array[String]:
	var t: String = ev["type"]

	# --- shop ---
	if t == "buy_blocked":
		var item: String = ev["item"]
		var reason: String = ev["reason"]
		var key := item + "|" + reason
		if BUY_BLOCKED_TEXT.has(key):
			return [BUY_BLOCKED_TEXT[key]]
		if reason == "limit":
			return ["Cannot buy %s — purchase limit reached." % py_capitalize(item)]
		if reason == "money":
			return ["Cannot buy %s — not enough money." % py_capitalize(item)]
		return []

	if t == "purchased":
		var item: String = ev["item"]
		if item == "chicken" and ev.get("variant") == "plain":
			return ["Chicken purchase successful"]
		if item == "book" and ev.get("key") == "hp":
			return ["Book of Max HP purchased! Max HP will double after your next fight."]
		if item == "ink":
			return ["Forbidden Ink purchased! (%d/%d). Enter the Battle and instant kill the monster!" % [ev["total"], Values.LIMIT["ink"]]]
		if item == "elixir":
			return ["You feel energised, your future self doesn't. SPD-%d, extra spd +%d" % [Values.ELIXIR_SPD_LOSS, Values.ELIXIR_EXTRA_SPD]]
		return []  # sword/shield/boots/other books/battery/card chickens are silent

	if t == "shop_death":
		return [SHOP_DEATH_TEXT[ev["cause"]]]

	if t == "socks_blocked":
		return [SOCKS_BLOCKED_TEXT[ev["reason"]]]

	if t == "socks_activated":
		return ["Cursed Socks activated!\n- ATK increased by %d\n- Max HP sealed at %d" % [ev["atk_gain"], ev["max_hp"]]]

	if t == "water_sample":
		return [Content.AR_SAMPLE_TEXT.format({"arb": ev["money"]})]

	if t == "water_sample_blocked":
		return ["You can't risk in taking another sample of voidous venom(contaminated water)"]

	if t == "relic_switch_blocked":
		return ["Cannot switch: you are already on your last relic!"]

	if t == "relic_switched":
		return ["Your power is drained from activating multiple relics, stats go to %d!" % Values.CARRIER_RESET,
				"Active relic switched to: %s" % Content.RELIC_NAMES[ev["relic"]]]

	if t == "meowton_equipped":
		return ["A law suit is not one that provides defence ability, DEF-%d" % Values.MEOWTON_DEF_LOSS]

	if t == "esword_equipped":
		if ev["had_sword"]:
			return ["You swapped your wooden sword from shop into the Automatic Counter E-Sword!"]
		return ["You equipped the Automatic Counter E-Sword! +%d ATK!" % Values.ESWORD_ATK]

	# --- drone ---
	if t == "drone_blocked":
		return [DRONE_BLOCKED_TEXT[ev["reason"]]]

	if t == "drone_upgraded":
		return [Content.DRONE_BUY_MSGS[ev["track"]][ev["stage"] - 1]]

	# --- pre-fight ---
	if t == "vitality_penalty":
		return ["Heart of Excessive Vitality drains %d%% of your money: -%.2f Money" % [Content.VITALITY_PERCENT, ev["amount"]],
				"Apparently, being super healthy is expensive — your wallet got a protein shake tax!"]

	if t == "coinpot_payout":
		return ["Coinpot bonus: +%.2f money before fight!" % ev["amount"]]

	# --- combat ---
	if t == "smirk":
		return ["'雑魚', you smirked"]

	if t == "drone_shot":
		var head: String = ["a", "a second", "a third"][ev["shot"]]
		var line := ("RAY-24 fires %s Tomahawk Cruise Missile at the monster!\nmonster hp: %d-%d=%d"
				% [head, ev["monster_hp_before"], ev["dmg"], ev["monster_hp"]])
		if ev["shreds_df"]:
			line += ("    monster def: %d-%d=%d(minimum 0)"
					% [ev["monster_df_before"], ev["df_loss"], ev["monster_df"]])
		return [line]

	if t == "drone_overkill":
		return ["Stop wasting ammo on dead bodies!"]

	if t == "vitality_drain":
		return ["weight of your wallet is draining your health, hp-%d" % ev["amount"]]

	if t == "ink_kill":
		if ev["final_boss"]:
			return ["Beat game special text not avalible in demo version"]
		return [Content.FORBIDDEN_MESSAGES[ev["message_index"]]]

	if t == "player_hit":
		return ["\nYou deal %d dmg!" % ev["dmg"],
				"Your HP: %d       Monster's HP: %d-%d=%d" % [ev["player_hp"], ev["monster_hp_before"], ev["dmg"], ev["monster_hp"]]]

	if t == "monster_hit":
		return ["\nMonster deals %d dmg!" % ev["dmg"],
				"Your HP: %d-%d=%d       Monster's HP: %d" % [ev["player_hp_before"], ev["dmg"], ev["player_hp"], ev["monster_hp"]]]

	if t == "revive":
		return [Content.TRAMPLE_TEXT if ev["in_combat"] else Content.SHOP_REVIVE_TEXT]

	if t == "pic_kill":
		return [Content.PIC_KILL_TEXT]

	# --- post-fight ---
	if t == "book_hp_applied":
		return ["Book of Max HP activates! Your max HP is now %d." % ev["max_hp"]]

	if t == "book_hp_fizzled":
		return ["The Book of Max HP fizzles out against your sealed max HP. Cursed Socks don't negotiate."]

	# --- run flow (the Python prints these from run()) ---
	if t == "esword_start":
		return ["You have your own sword, not needing the shop one! +%d ATK!" % Values.ESWORD_ATK]

	if t == "blessed_fumble":
		return [Content.BLESSED_FUMBLE_TEXT]

	if t == "run_died":
		return ["\nYou died! Level completed this run: %d.   Highest: %d" % [ev["level_completed"], ev["highest"]]]

	if t == "hard_mode":
		return ["I don't balme you, you just attempted the hardest difficulty"]

	if t == "run_finished":
		return ["\nRun %d finished! \n" % ev["runs"]]

	if t == "run_quit":
		return ["\nYou left the dungeon. Highest: %d" % ev["highest"]]

	if t == "game_won":
		return ["\nYou beat level %d. You win!" % Values.FINAL_LEVEL]

	if t == "few_runs_win":
		return ["You beat the game with the fewest runs possible!"]

	push_error("unknown event type: %s" % t)
	return []


## The calculator's top bar (stat_bar), printed above each prompt during a run.
static func stat_bar(player: PlayerState, level: int) -> String:
	return ("HP %d/%d  $%.2f  A%d D%d S%d  | Next: Lv%d"
			% [player.hp, player.max_hp, player.money,
			player.total_atk(), player.total_df(), player.total_spd(), level])


## One stat line of the stats screen: "ATK: 3+2 (5)", or "ATK: 3" without extra.
static func stat_line(label: String, base: int, total: int) -> String:
	var extra := total - base
	if extra > 0:
		return "%s: %d+%d (%d)" % [label, base, extra, total]
	return "%s: %d" % [label, base]


## display_player_and_next_monster(): each entry is one print() call.
static func stats_screen(player: PlayerState, level: int) -> Array[String]:
	var out: Array[String] = ["\n--- Player Stats ---", "HP: %d/%d" % [player.hp, player.max_hp]]
	out.append(stat_line("ATK", player.atk, player.total_atk()))
	out.append(stat_line("DEF", player.df, player.total_df()))
	out.append(stat_line("SPD", player.spd, player.total_spd()))
	if player.relic == "family" and not player.revive_used:
		out.append("Revives: 1")
	if player.counters > 0:
		out.append("Counters: %d" % player.counters)
	var m := Entity.create_monster(level)
	out.append("\nNext Monster - Level %d" % level)
	out.append("HP: %d" % m.hp)
	out.append("ATK: %d" % m.atk)
	out.append("DEF: %d" % m.df)
	out.append("SPD: %d" % m.spd)
	return out


## The muted forecast pre_fight() prints when the fight starts (from GameEngine.fight_forecast).
static func forecast_lines(fc: Dictionary) -> Array[String]:
	return [
		"\nYou will deal %d-%d=%d(at least %d) dmg," % [fc["atk"], fc["m_df"], fc["you_deal"], Values.MIN_DAMAGE],
		"\nMonster will deal %d-%d=%d(at least %d) dmg" % [fc["m_atk"], fc["df"], fc["monster_deals"], Values.MIN_DAMAGE],
		"Your spd is %d compared to the monster's %d," % [fc["spd"], fc["m_spd"]],
		"so you will go first!" if fc["you_first"] else "so the monster will go first!",
	]
