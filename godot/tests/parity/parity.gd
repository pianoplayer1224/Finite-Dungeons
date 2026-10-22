extends SceneTree
## Parity harness, GDScript side. Mirror of tests/parity/parity.py: writes the same records
## from the GDScript port so run_parity.sh can diff them.
##
## Usage: $GODOT --headless --path . -s tests/parity/parity.gd -- OUT_FILE
## Runs without autoloads, so it can only use scripts/core/.

const G := "«"   # the Python's GREY ... RESET, as parity.py marks them
const R := "»"

# Event colours the Python's EVENT_COLOUR does not have (run-flow events, Godot only).
const GODOT_ONLY_COLOURS := ["blessed_fumble", "run_died", "game_won", "few_runs_win"]

const LIBRARY_HIGHEST := [0, 3, 4, 12, 29, 30]
const SAVE_RUNS := [0, 1, 2, 3, 7, 60, 61, 62, 100, 1023, 1024, 1025, 5000]
const BAD_CODES := ["", "0000", "000000", "I0000", "0000I", "zzzzz", "00P92", "!!!!!", "0000O",
		"ABCDE", "00I00", "a b c", "Zzzzz", "10000", "0ZZZZ", "00000"]

const SNAP_FIELDS := [
	"hp", "max_hp", "atk", "df", "spd", "extra_atk", "extra_df", "extra_spd", "total_atk",
	"total_df", "total_spd", "money", "artefact", "relic", "relics", "active_relic_index",
	"switches", "revive_used", "revived_this_fight", "forbidden_ink", "forbidden_ink_total",
	"counters", "used_e_sword_before", "coinpot_bonus", "elixir_timers",
	"bought_elixir_this_visit", "books", "bought", "socks_sealed", "pending_hp_multiplier",
	"ar_used", "vitality_drain_pending",
]

var lines := PackedStringArray()


func out(s: String) -> void:
	lines.append(s)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: -s tests/parity/parity.gd -- OUT_FILE")
		quit(2)
		return
	static_sections()
	for scenario: Dictionary in load_scenarios():
		replay(scenario)
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	quit(0)


# ---------------------------------------------------------------- serialisation

func ser(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "~"
		TYPE_BOOL:
			return "T" if v else "F"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			if v == float(int(v)):
				return str(int(v))
			return "f" + str(int(v * 4294967296.0))
		TYPE_STRING, TYPE_STRING_NAME:
			return '"' + String(v).replace("\\", "\\\\").replace("\n", "\\n").replace('"', '\\"') + '"'
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			var parts := PackedStringArray()
			for x in v:
				parts.append(ser(x))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array = v.keys()
			var by_name := {}
			for k: Variant in keys:
				by_name[String(k)] = k
			var names: Array = by_name.keys()
			names.sort()
			var parts := PackedStringArray()
			for k: String in names:
				parts.append("%s:%s" % [k, ser(v[by_name[k]])])
			return "{" + ",".join(parts) + "}"
	push_error("cannot serialise %s" % type_string(typeof(v)))
	return "?"


## The lines a sequence of Python print() calls would produce.
func printed(prints: Array) -> PackedStringArray:
	var text := "\n".join(PackedStringArray(prints))
	return text.split("\n")


# ---------------------------------------------------------------- static sections

func content_values() -> Dictionary:
	var colours := {}
	for k: String in EventText.EVENT_COLOUR:
		if k not in GODOT_ONLY_COLOURS:
			colours[k] = EventText.EVENT_COLOUR[k]
	return {
		"UNLOCK_LEVEL": Content.UNLOCK_LEVEL, "VITALITY_PERCENT": Content.VITALITY_PERCENT,
		"AR_POWER_SIGN": Content.AR_POWER_SIGN, "FORBIDDEN_MESSAGES": Content.FORBIDDEN_MESSAGES,
		"RELIC_NAMES": Content.RELIC_NAMES, "RELIC_DESCRIPTIONS": Content.RELIC_DESCRIPTIONS,
		"ARTEFACT_MENU_NAMES": Content.ARTEFACT_MENU_NAMES,
		"ARTEFACT_DESCRIPTIONS": Content.ARTEFACT_DESCRIPTIONS,
		"ACH_BIT_ORDER": Content.ACH_BIT_ORDER,
		"ACHIEVEMENT_SECRET_HINTS": Content.ACHIEVEMENT_SECRET_HINTS,
		"ACHIEVEMENT_DISPLAY": Content.ACHIEVEMENT_DISPLAY,
		"DRONE_TRACK_NAMES": Content.DRONE_TRACK_NAMES, "DRONE_STAGE_DESCS": Content.DRONE_STAGE_DESCS,
		"DRONE_BUY_MSGS": Content.DRONE_BUY_MSGS, "TRAMPLE_TEXT": Content.TRAMPLE_TEXT,
		"PIC_KILL_TEXT": Content.PIC_KILL_TEXT, "SHOP_REVIVE_TEXT": Content.SHOP_REVIVE_TEXT,
		"BLESSED_FUMBLE_TEXT": Content.BLESSED_FUMBLE_TEXT, "AR_SAMPLE_TEXT": Content.AR_SAMPLE_TEXT,
		"BUY_BLOCKED_TEXT": EventText.BUY_BLOCKED_TEXT, "SHOP_DEATH_TEXT": EventText.SHOP_DEATH_TEXT,
		"DRONE_BLOCKED_TEXT": EventText.DRONE_BLOCKED_TEXT,
		"SOCKS_BLOCKED_TEXT": EventText.SOCKS_BLOCKED_TEXT, "EVENT_COLOUR": colours,
		"SAVE_ALPHABET": SaveCodes.SAVE_ALPHABET,
	}


## print_library(), laid out exactly as the Python prints it.
func render_library(highest: int) -> Array:
	var p := ["\n---relics---"]
	for entry: Dictionary in Content.LIBRARY:
		if entry["key"] == "devotion":
			p.append("---artefacts--")
		var e := Content.library_entry(entry, highest)
		var label: String = G + Content.unlock_label(e["key"]) + R
		if e["key"] == "dk":
			if e.get("secret", false):
				p.append("????????" + label + " \n???????????\n")
			else:
				p.append(e["name"] + " " + label + " \n" + e["body"] + "\n")
				p.append(G + e["flavour"] + R)
			continue
		var head: String = e["name"] + ((" " + label) if e["labelled"] else "")
		p.append(head + " \n" + e["body"])
		p.append(G + e["flavour"] + "\n" + R)
	return p


## print_achievements(), laid out exactly as the Python prints it.
func render_achievements(ac: Dictionary) -> Array:
	var p := ["---unlocked achievements---"]
	for a: Array in Content.ACHIEVEMENT_DISPLAY:
		if ac[a[0]]:
			p.append(a[1])
			p.append(G + a[2] + "\n" + R)
	p.append("---locked achievements---")
	for a: Array in Content.ACHIEVEMENT_DISPLAY:
		if not ac[a[0]]:
			p.append(a[1])
			var hint: String = "?????????" if a[0] in Content.ACHIEVEMENT_SECRET_HINTS else a[2]
			p.append(G + hint + "\n" + R)
	return p


func ach_sets() -> Array:
	var all: Array = Array(Content.ACH_BIT_ORDER)
	var not_neg := all.filter(func(k: String) -> bool: return k != "negative_money")
	return [[], all, ["negative_money"], not_neg, ["pic_kill", "shop_death", "trun", "drich"]]


func static_sections() -> void:
	var values := (load("res://scripts/core/values.gd") as GDScript).get_script_constant_map()
	var names: Array = values.keys().map(func(k: Variant) -> String: return String(k))
	names.sort()
	for name: String in names:
		out("V %s %s" % [name, ser(values[name])])
	var content := content_values()
	for name: String in ["UNLOCK_LEVEL", "VITALITY_PERCENT", "AR_POWER_SIGN", "FORBIDDEN_MESSAGES", "RELIC_NAMES",
			"RELIC_DESCRIPTIONS", "ARTEFACT_MENU_NAMES", "ARTEFACT_DESCRIPTIONS", "ACH_BIT_ORDER",
			"ACHIEVEMENT_SECRET_HINTS", "ACHIEVEMENT_DISPLAY", "DRONE_TRACK_NAMES", "DRONE_STAGE_DESCS",
			"DRONE_BUY_MSGS", "TRAMPLE_TEXT", "PIC_KILL_TEXT", "SHOP_REVIVE_TEXT", "BLESSED_FUMBLE_TEXT",
			"AR_SAMPLE_TEXT", "BUY_BLOCKED_TEXT", "SHOP_DEATH_TEXT", "DRONE_BLOCKED_TEXT",
			"SOCKS_BLOCKED_TEXT", "EVENT_COLOUR", "SAVE_ALPHABET"]:
		out("C %s %s" % [name, ser(content[name])])

	for line in printed(Content.INTRO):
		out("T intro " + line)
	for line in printed(Content.CREDITS):
		out("T credits " + line)
	for h: int in LIBRARY_HIGHEST:
		for line in printed(render_library(h)):
			out("T library%d %s" % [h, line])
	var sets := ach_sets()
	for i in sets.size():
		var prof := ProfileState.new()
		for k: String in sets[i]:
			prof.ac[k] = true
		for line in printed(render_achievements(prof.ac)):
			out("T ach%d %s" % [i, line])

	for runs: int in SAVE_RUNS:
		var bit_values: Array = range(256) if runs in [0, 1024] else [0, 1, 2, 0x80, 0xAA, 0x55, 0xFF]
		for highest in range(31):
			for bits: int in bit_values:
				var prof := ProfileState.new()
				prof.runs = runs
				prof.highest = highest
				for offset in Content.ACH_BIT_ORDER.size():
					prof.ac[Content.ACH_BIT_ORDER[offset]] = bool((bits >> (7 - offset)) & 1)
				var code := SaveCodes.save_code(prof)
				var back := ProfileState.new()
				var res := SaveCodes.load_code(back, code)
				out("S %d %d %d %s %s %s %d %d %s" % [runs, highest, bits, code, ser(res["ok"]), ser(res["message"]),
						back.runs, back.highest, ser(back.ac)])
	for code: String in BAD_CODES:
		var prof := ProfileState.new()
		prof.runs = 9
		var res := SaveCodes.load_code(prof, code)
		out("S bad %s %s %s %d %d %s" % [ser(code), ser(res["ok"]), ser(res["message"]), prof.runs, prof.highest, ser(prof.ac)])


# ---------------------------------------------------------------- scenario replay

class Run:
	var profile := ProfileState.new()
	var player: PlayerState = null
	var level := 1
	var over := false


func snap(p: PlayerState) -> Dictionary:
	var d := {}
	for f: String in SNAP_FIELDS:
		match f:
			"total_atk":
				d[f] = p.total_atk()
			"total_df":
				d[f] = p.total_df()
			"total_spd":
				d[f] = p.total_spd()
			_:
				d[f] = p.get(f)
	d["drone_atk"] = p.drone.atk
	d["drone_stages"] = p.drone.stages
	d["drone_slots"] = p.drone.slots_used
	return d


func worded(events: Array) -> Array:
	var res := []
	for ev: Dictionary in events:
		res.append([ev, EventText.format_event(ev), EventText.colour_of(ev)])
	return res


func shop_death_end(r: Run) -> Array:
	r.over = true
	return worded(GameEngine.shop_death_end(r.profile, r.level))


## Returns {"res", "extra", "died"}, or null when the op is skipped.
func apply_op(r: Run, op: Array) -> Variant:
	var name: String = op[0]
	if name == "start":
		var started := GameEngine.start_run(r.profile, op[1], op[2])
		r.player = started["player"]
		r.level = 1
		r.over = false
		return {"res": worded(started["events"]), "extra": [], "died": false}
	if name == "profile":
		var prof := ProfileState.new()
		var loaded := SaveCodes.load_code(prof, op[1])
		if loaded["ok"]:
			r.profile = prof
		return {"res": [], "extra": ["profile %s %s" % [ser(loaded["ok"]), ser(loaded["message"])]], "died": false}
	if r.player == null or r.over:
		return null
	var p := r.player
	var ac := r.profile.ac
	match name:
		"level":
			GameEngine.begin_level(p)
			return {"res": [], "extra": [], "died": false}
		"buy":
			var bought := GameEngine.try_buy(p, op[1], ac)
			var res := worded(bought["events"])
			if bought["died"]:
				res.append_array(shop_death_end(r))
			return {"res": res, "extra": [], "died": bought["died"]}
		"drone":
			return {"res": worded(GameEngine.buy_drone_upgrade(p, int(op[1]))), "extra": [], "died": false}
		"socks":
			return {"res": worded(GameEngine.activate_socks(p)), "extra": [], "died": false}
		"water":
			var sampled := GameEngine.take_water_sample(p, r.level, ac)
			var res := worded(sampled["events"])
			if sampled["died"]:
				res.append_array(shop_death_end(r))
			return {"res": res, "extra": [], "died": sampled["died"]}
		"switch":
			return {"res": worded(GameEngine.switch_relic(p)), "extra": [], "died": false}
		"fight":
			GameEngine.begin_level(p)  # pre_fight() entry
			GameEngine.leave_for_fight(p)
			var forecast := printed(EventText.forecast_lines(GameEngine.fight_forecast(p, r.level)))
			var result := GameEngine.resolve_level(p, r.level, r.profile)
			var events: Array = result["pre"] + result["fight"] + result["post"]
			if result["run_over"]:
				r.over = true
			elif result["won"]:
				r.level += 1
			return {"res": worded(events), "extra": Array(forecast), "died": false}
		"quit":
			r.over = true
			return {"res": worded(GameEngine.quit_run(r.profile, r.level)), "extra": [], "died": false}
		"set":
			var field: String = op[1]
			match typeof(p.get(field)):
				TYPE_INT:
					p.set(field, int(op[2]))
				TYPE_FLOAT:
					p.set(field, float(op[2]))
				TYPE_BOOL:
					p.set(field, bool(op[2]))
				_:
					push_error("set: unknown field %s" % field)
			return {"res": [], "extra": [], "died": false}
		"addmoney":
			p.money += float(op[1])
			return {"res": [], "extra": [], "died": false}
		"setlevel":
			r.level = int(op[1])
			return {"res": [], "extra": [], "died": false}
	push_error("unknown op %s" % [op])
	return null


func display(r: Run) -> void:
	var p := r.player
	var level := r.level
	out("B " + EventText.stat_bar(p, level))
	var shop := ShopMenu.shop_rows(p, level)
	for row: Dictionary in shop["rows"]:
		var line := "%d %s" % [row["num"], row["text"]]
		out("M " + ((G + line + R) if row["greyed"] else line))
	out("M 0 Back")
	for sp: Dictionary in shop["specials"]:
		out("M %d %s" % [sp["num"], sp["text"]])
	if p.relic == "yd":
		var drone := ShopMenu.drone_rows(p)
		out("D " + drone["header"])
		for track: Dictionary in drone["tracks"]:
			out("D ")
			out("D " + track["header"])
			for st: Dictionary in track["stages"]:
				out("D " + ((G + st["text"] + R) if st["greyed"] else st["text"]))
		out("D ")
		out("D 0 return to shop")
		out("D " + EventText.stat_bar(p, level))
	for line in printed(EventText.stats_screen(p, level)):
		out("X " + line)


func replay(scenario: Dictionary) -> void:
	var sname: String = scenario["name"]
	var r := Run.new()
	var code: String = scenario.get("code", "00000")
	if code != "":
		SaveCodes.load_code(r.profile, code)
	var show: String = scenario.get("display", "all")
	var ops: Array = scenario["ops"]
	for i in ops.size():
		var op: Array = ops[i]
		var tag := "%s#%03d %s" % [sname, i, op[0]]
		var applied: Variant = apply_op(r, op)
		if applied == null:
			out("O %s skip" % tag)
			continue
		var events := []
		for item: Array in applied["res"]:
			events.append(item[0])
		out("O %s ev=%s died=%s" % [tag, ser(events), ser(applied["died"])])
		for item: Array in applied["res"]:
			for text: String in item[1]:
				for line in text.split("\n"):
					out("L %s|%s" % [item[2], line])
		for line: String in applied["extra"]:
			out("E " + line)
		var prof := r.profile
		out("A runs=%d highest=%d ac=%s code=%s level=%d over=%s" % [prof.runs, prof.highest, ser(prof.ac),
				SaveCodes.save_code(prof), r.level, ser(r.over)])
		if r.player != null:
			out("P " + ser(snap(r.player)))
			if not r.over and (show == "all" or op[0] in ["level", "start"]):
				display(r)


func load_scenarios() -> Array:
	var scen := []
	for fname: String in ["scenarios.json", "fuzz.json"]:
		var path := "res://tests/parity/" + fname
		if FileAccess.file_exists(path):
			scen.append_array(JSON.parse_string(FileAccess.get_file_as_string(path)))
	return scen
