class_name Content
extends RefCounted
## Python section 1: CONTENT DATA, plus the fixed texts from section 5 (library, credits, intro)
## kept as data so screens can lay them out. Every string is verbatim from FiniteDungeons.py and
## every number in a string is read from Values, so a VALUES change updates the text too.
## Computed texts are static vars (const expressions cannot call functions).

# Derived from VALUES for the texts below (not values of their own).
static var UNLOCK_LEVEL: Dictionary = _build_unlock_level()
static var VITALITY_PERCENT: int = int(round(Values.VITALITY_MONEY_LOSS * 100))
static var AR_POWER_SIGN: String = {2: "²", 3: "³", 4: "⁴"}.get(Values.AR_POWER, "^%d" % Values.AR_POWER)
static var VITALITY_DRAIN_TEXT: String = "money" if Values.VITALITY_DRAIN_DIVISOR == 1 else "money/%d" % Values.VITALITY_DRAIN_DIVISOR

static func _build_unlock_level() -> Dictionary:
	var d := {}
	for pair: Array in Values.RELIC_UNLOCKS + Values.ARTEFACT_UNLOCKS:
		d[pair[0]] = pair[1]
	return d


const FORBIDDEN_MESSAGES: Array[String] = [
	"You wrote out the formula to beat this game (a wrong one), the monster dies laughing!",
	"You wrote out Navier-Stokes equation, the monster dies trying to understand!",
	"You wrote out Einstein’s field equations, the monster dies overwhelmed!",
	"You wrote out Schrodinger's equation, the monster dies in confusion!",
	"You scribbled down Maxwell's equations, the monster dies from panic!",
	"You wrote out Rocket propulsion formulas, the monster dies screaming!",
	"You jotted down Euler's formula, the monster dies in horror!",
	"You wrote out the cubic formula, the monster faints and dies!",
	"You scribbled out the Pythagorean theorem, the monster dies of fright!",
	"You wrote out the equation for the area of a triangle, the monster got scared to death!",
]

const RELIC_NAMES := {
	"family": "Picture of Family",
	"blessed": "Blessed Emblem",
	"forbidden": "Forbidden Book",
	"bk": "K*C bronze membership card",
	"e-sword": "Automatic Counter E-Sword",
	"yd": "RAY-24 Drone",
	"sk": "K*C silver membership card",
	"meowton": "Meowton’s Second Lawsuit",
	"gk": "K*C gold membership card",
	"dk": "K*C diamond membership card",
}

static var RELIC_DESCRIPTIONS := {
	"family": "Picture of Family - Revives once to %d HP when defeated." % Values.REVIVE_HP,
	"blessed": "Blessed Emblem - Every %d monsters defeated, +%d max HP and heal max. -%d HP when run starts" % [Values.BLESSED_EVERY, Values.BLESSED_MAX_HP, Values.BLESSED_START_HP_LOSS],
	"forbidden": "Forbidden Book - unlocks in shop: ink - costs %d, max purchase %d, max hold %d, auto consumed at start of fight and defeats the monster." % [Values.PRICE["ink"], Values.LIMIT["ink"], Values.INK_HOLD],
	"bk": "K*C bronze membership card - chickens heal %d more hp, max purchase +%d" % [Values.CHICKEN_HEAL["bk"] - Values.CHICKEN_HEAL["plain"], Values.CHICKEN_LIMIT["bk"] - Values.CHICKEN_LIMIT["plain"]],
	"yd": "RAY-24 Drone - have a drone to help you fight! Buy up to %d upgrades" % Values.DRONE_SLOTS,
	"e-sword": "E-Sword - Starts with +%d ATK." % Values.ESWORD_ATK,
	"sk": "K*C silver membership card - chickens heal %d more hp, max purchase +%d" % [Values.CHICKEN_HEAL["sk"] - Values.CHICKEN_HEAL["plain"], Values.CHICKEN_LIMIT["sk"] - Values.CHICKEN_LIMIT["plain"]],
	"meowton": "Meowton's 2nd lawsuit - -%d DEF when equipping, gain extra ATK = total SPD" % Values.MEOWTON_DEF_LOSS,
	"gk": "K*C gold membership card - chickens heal max, no max purchase limit",
	"dk": "K*C diamond membership card - chickens heal max, remove all conditions required to purchase chickens",
}

const ARTEFACT_MENU_NAMES := {
	"devotion": "The Damned Proof of Devotion (i.e. corner shop loyalty card)",
	"socks": "Cursed (old, smelly) Socks",
	"coinpot": "Alchemist's Coinpot (savings account)",
	"ar": "Abyssal Rad-Blood Oath (suspicious nuclear food testing contract)",
	"carrier": "The carrier of legends (Backpack)",
	"vitality": "Heart of Excessive Vitality (Protein shake heath package plan)",
}

static var ARTEFACT_DESCRIPTIONS := {
	"devotion": "The Damned Proof of Devotion - Elixir unlocked in shop - costs %d, max hp - [elixir bought], SPD-%d, extra spd+%d, for next %d fights -%d extra SPD after fight, can only buy one per turn." % [Values.PRICE["elixir"], Values.ELIXIR_SPD_LOSS, Values.ELIXIR_EXTRA_SPD, Values.ELIXIR_FIGHTS, Values.ELIXIR_SPD_DECAY],
	"socks": "Cursed Socks - Boots sealed. When HP <= %d, unlocks option in shop to decrease and seal max HP to current HP, gaining the same amount of ATK." % Values.SOCKS_MAX_HP,
	"coinpot": "Alchemist's Coinpot - Every %d money left before fight gives %d money." % [Values.COINPOT_STEP, Values.COINPOT_PAY],
	"ar": "Abyssal Rad-Blood Oath - Unlocks a shop option once per run to lose %d max HP, gain money={level beaten/%d (round down)}%s." % [Values.AR_MAX_HP_LOSS, Values.AR_LEVEL_STEP, AR_POWER_SIGN],
	"carrier": "Carrier of Legend - Choose %d relics, switch from the 1st to 2nd to 3rd one. All stats except max hp drains to %d at relic switch." % [Values.CARRIER_RELICS, Values.CARRIER_RESET],
	"vitality": "Heart of Excessive Vitality - Start with %d HP but lose %d%% money before fights, at the start of fights, lose HP equal to %s." % [Values.VITALITY_HP, VITALITY_PERCENT, VITALITY_DRAIN_TEXT],
}

# Achievement save-code bit order, most significant bit first. Do NOT reorder:
# save codes pack these 8 flags into one byte in exactly this order.
const ACH_BIT_ORDER: Array[String] = [
	"pic_kill", "negative_money", "shop_death", "one_shot",
	"trun", "okill", "drich", "hmode",
]

# Display order + text for the achievements screen: [key, title, hint].
# Hints listed here are hidden while the achievement is still locked.
const ACHIEVEMENT_SECRET_HINTS: Array[String] = ["negative_money"]
@warning_ignore("integer_division")
static var ACHIEVEMENT_DISPLAY: Array = [
	["trun", "The real game", "beat level %d in %d runs" % [Values.FINAL_LEVEL, Values.FEW_RUNS]],
	["drich", "you can't take it with you", "die with over %dm money" % (Values.RICH_MONEY / 1000000)],
	["one_shot", "雑魚", "one shot a monster"],
	["okill", "'just in case its still alive, you know?'", "shoot a Tomahawk Cruise Missile at a dead monster"],
	["hmode", "hard mode", "inevitably die on level %d" % Values.HARD_MODE_LEVEL],
	["negative_money", "Well, you did say ALL conditions", "purchase a chicken without enough money"],
	["shop_death", "as dangerous as 'monster'", "die in shop"],
	["pic_kill", "one hp actually helps?!", "kill a monster after reviving"],
]

# --- RAY-24 drone upgrade texts ---
# Costs and effects are in Values and applied by GameEngine.apply_drone_stage(). The
# descriptions keep {atk} / {atk2} (the drone's current atk) for String.format() to fill in.
const DRONE_TRACK_NAMES: Array[String] = [
	"Hardpoint munition upgrade",  # the drone's regular attack - its ATK rides with yours
	"Alpha strike",                # the start-of-fight Tomahawk volley
	"FARP Protocol",               # post-fight healing (Forward Arming and Refueling Point)
	"Materiel Recovery",           # post-fight income. "Materiel" is the correct military
								   # spelling and is deliberate - do not "fix" it to "Material".
]

static var DRONE_STAGE_DESCS: Array = [
	[
		"Stage 1-drone atk +%d, cost: %d" % [Values.DRONE_T1_ATK_GAIN[0], Values.DRONE_STAGE_COSTS[0][0]],
		"Stage 2-drone atk +%d, cost: %d" % [Values.DRONE_T1_ATK_GAIN[1], Values.DRONE_STAGE_COSTS[0][1]],
		"Stage 3-drone atk +%d, cost: %d" % [Values.DRONE_T1_ATK_GAIN[2], Values.DRONE_STAGE_COSTS[0][2]],
		"Stage 4-drone atk +%d, cost: %d" % [Values.DRONE_T1_ATK_GAIN[3], Values.DRONE_STAGE_COSTS[0][3]],
	],
	[
		"Stage 1-at start of fight fire Tomahawk Cruise Missile, attacking monster with drone atk({atk}), cost: %d" % Values.DRONE_STAGE_COSTS[1][0],
		"Stage 2-the Tomahawk Cruise Missile has double atk, cost: %d" % Values.DRONE_STAGE_COSTS[1][1],
		"Stage 3-Tomahawk Cruise Missile penetrate defence=its attack({atk2}), cost: %d" % Values.DRONE_STAGE_COSTS[1][2],
		"Stage 4-fires %d more Tomahawk Cruise Missiles, Tomahawk Cruise Missiles decrease monster defence=their dmg*%d, cost: %d" % [Values.DRONE_STAGE4_MISSILES - 1, Values.DRONE_SHRED_MULTIPLIER, Values.DRONE_STAGE_COSTS[1][3]],
	],
	[
		"Stage 1-when you defeat a monster heal %d, cost: %d" % [Values.DRONE_HEALS[0], Values.DRONE_STAGE_COSTS[2][0]],
		"Stage 2-heal max, when you defeat a monster heal %d, cost: %d" % [_sum(Values.DRONE_HEALS.slice(0, 2)), Values.DRONE_STAGE_COSTS[2][1]],
		"Stage 3-heal max, when you defeat a monster heal %d, cost: %d" % [_sum(Values.DRONE_HEALS.slice(0, 3)), Values.DRONE_STAGE_COSTS[2][2]],
		"Stage 4-heal max, healings(from all source) doubles, cost: %d" % Values.DRONE_STAGE_COSTS[2][3],
	],
	[
		"Stage 1-when you defeat a monster +money = drone atk, cost: %d" % Values.DRONE_STAGE_COSTS[3][0],
		"Stage 2-when you defeat a monster +%d money, upgrade all stage 1 upgrades into stage 2(doesn't take up one of the %d slots), cost: %d" % [Values.DRONE_T4_MONEY[0], Values.DRONE_SLOTS, Values.DRONE_STAGE_COSTS[3][1]],
		"Stage 3-when you defeat a monster +%d money, make all upgrades at least stage 1(does not take up slot), cost: %d" % [Values.DRONE_T4_MONEY[1], Values.DRONE_STAGE_COSTS[3][2]],
		"Stage 4-double income (from all sources), upgrade all stage 3 into stage 4(doesn't take up slot), cost: %d" % Values.DRONE_STAGE_COSTS[3][3],
	],
]

static var DRONE_BUY_MSGS: Array = [
	[
		"upgrade purchased, drone atk + %d" % Values.DRONE_T1_ATK_GAIN[0],
		"upgrade purchased, drone atk + %d" % Values.DRONE_T1_ATK_GAIN[1],
		"upgrade purchased, drone atk + %d" % Values.DRONE_T1_ATK_GAIN[2],
		"upgrade purchased, drone atk + %d" % Values.DRONE_T1_ATK_GAIN[3],
	],
	[
		"Upgrade purchased, drone will attack at start of fight!",
		"upgrade purchased, Tomahawk Cruise Missile atk*%d" % Values.DRONE_MISSILE_MULTIPLIER,
		"Upgrade purchased, Tomahawk Cruise Missiles will now penetrate defence!",
		"Upgrade purchased, drone will now fire %d more Tomahawk Cruise Missiles and they reduce monster def!" % (Values.DRONE_STAGE4_MISSILES - 1),
	],
	[
		"upgrade purchased, drone will now heal you after fight!",
		"upgrade purchased, drone healed you max will now heal more after fight!",
		"upgrade purchased, drone healed you max will now heal more after fight!",
		"upgrade purchased, drone will now double your heal!",
	],
	[
		"upgrade purchased, drone will give extra money after fight!",
		"upgrade purchased, drone is developed and will give extra money after fight!",
		"upgrade purchased, drone is developed and will give extra money after fight!",
		"upgrade purchased, drone is enhanced and will double your income!",
	],
]

static func _sum(values: Array) -> int:
	var total := 0
	for v: int in values:
		total += v
	return total

# --- Long story texts ---
const TRAMPLE_TEXT := "Harshly, you are shuffled to the ground. Out of your pocket a picture flew out, the picture that stands as your fuel, the picture that supported you up to here, the picture that captures the moment you can never return to...\nthen TRASH\nnot dramatically, not emotionally, the monster trampled on it.\nYou feel a string snapped inside you as the picture shattered into pieces.\nBefore you knew it, you were charging towards the monster with all your might..."

const PIC_KILL_TEXT := "From that burst of energy not explainable by science, you regained just enough power to put the down the monster before dropping to the ground\nAfter what felt like eternities later, you dragged yourself up, and moved on, just like what they would have wanted to see..."

# Used when the revive happens with no monster around (shop deaths).
const SHOP_REVIVE_TEXT := "Your knees buckle, and the picture slips out of your pocket, landing face-down in the dirt.\nNo monster, no dramatic music, no one to blame — just you, a shop, and a photograph you will never be able to look at the same way again.\nYou pick yourself up anyway. They would have wanted you to."

static var BLESSED_FUMBLE_TEXT := "You fumble with the Blessed Emblem while getting ready and pinched yourself, losing %d HP.....\nI am not laughing at you, I promise." % Values.BLESSED_START_HP_LOSS

# {arb} is filled with String.format({"arb": money}).
static var AR_SAMPLE_TEXT := "You collected some Blight (glowing water) in the dungeon, despite knowing it is radioactive(crused), you still decided to betray your DNA(soul) and melded with(drank) it.\nReading your treatise(report), the demons(people at the summit of glorious achievement) decided to bestow(reward) you with {arb} money, given the deepness the sample is from.\nYou feel your body is already regretting this decision, max hp -%d!" % Values.AR_MAX_HP_LOSS


# ------------------------------------------------------------------
# Section 5 fixed texts, kept as data for the screens.
# ------------------------------------------------------------------

## print_intro(): each entry is one print() call.
static var INTRO: Array[String] = [
	"\nWelcome to FINITE DUNGEONS(demo)!",
	"Long long ago, in the blessed town of...skipping opening cutscene?! How dare you...\nfine, straight to the tutorial...",
	"--- How to play ---",
	"This is an auto-combat game where life choices and shopping collide, and your aim is to defeat me, the level %d boss. Why me? Shouldn't have skipped the intro if you want to know😈\nCharacters have 4 stats: HP, ATK DEF and SPD.(effect explained later)\nHP is shown in the form hp/max hp, others are shown in the form 'base+extra(total)'\nMonsters gain +%d to every stat each level, while you mainly increase stats by purchasing stuff in the shop before each fight, using a (creative) currency called 'money'.\nThe effect and stock of each item can be seen in its tile.\nTo purchase an item, simply click on its tile or input its number on the keyboard.\nEffect of items are instantly applied unless specified, and all stat increases refer to base unless 'extra' is specified. \nAt the start of runs you can pick (usually) 1 'relics' and 'artefacts', which you will unlock more as your highest level reached increases.\nWhen you get defeated you go back to level 1 and can start a new run, probably with new relics and artefacts you unlocked on the previous run!\n\n\n\n-------combat system------\nFighting in each level consists of 2 main phases: hitting the monster and getting hit by the monster, these two phases loop until the HP of you or the monster reaches 0.\nThe character with higher SPD hits first, if SPD ties, I'll let you hit first, cause I'm genuinely nice.\nWhen getting hit, HP decreases by:\nAttacker total ATK-Defender total DEF (HP lost is at least one if this gives <1)\nA preview of the fight can be found in the box above 'start fight'\nThe whole fight is automatic, and could be skipped/sped up using the bottom right panel.\n\nGood luck, and I shall see you at level %d.\n\n" % [Values.FINAL_LEVEL, Values.MONSTER_GROWTH, Values.FINAL_LEVEL],
]

const TITLE_LINES: Array[String] = ["Finite Dungeons by Timothy", "Copyright © 2026 Timothy Tang"]

const CREDITS_HEADING := "CREDITS\n\nI'd like to give HUGE thanks to these people, without you, this game wouldn't be possible."

## print_credits(): each entry is one print() call, verbatim (leading "\n" included).
const CREDITS: Array[String] = [
	"\nGuido van Rossum, creator of Python, who provided coding language to me",
	"\nSteve Jobs, co-founder of Apple, who provided my device to me",
	"\nNick Holonyak Jr., inventor of the practical LED, who provided glowing screens to me",
	"\nOleg Losev, LED research pioneer, who provided more glowing things to type on to me",
	"\nAlessandro Volta, inventor of the battery, who provided portable power to me",
	"\nMichael Faraday, discoverer of electromagnetic induction, who provided electricity generation to me",
	"\nTim Berners-Lee, creator of the World Wide Web, who provided internet access to me for research",
	"\nLarry Page and Sergey Brin, founders of Google, who provided more searching ability to me",
	"\nLinus Torvalds, creator of Linux, who provided computing foundations to me",
	"\nDennis Ritchie, creator of C language, who provided programming foundations to me",
	"\nThe inventors of WiFi, who provided freedom(wireless connection) to me",
	"\nThe inventors of electricity, who provided energy to me(literally and metaphorically)",
	"\nThe inventor of the chair, who provided comfort to me while coding",
	"\n---special credits---",
	"pianoplayer1224, who distracted me from making this game by giving me a code to solve, and by giving me a game of theirs to play, and by saying 'He wasn't impressed' at this very moment I am typing. But more importantly, for their contributions to my knowledge of coding and contributions to all angles of this game as the first playtester.",
	"\nRachmaninov and blackpenredpen, who provided me with emotional support by writing a 2nd piano concerto and made YouTube videos respectively. (Check out Rach 2 and blackpenredpen if you don't know them!!)",
	"\nMy family, who provided me with love, shelter, and most importantly, food, when I am making this game",
	"\nAll my friends who played the paper version of this game, contributing huge to the balancing and shaping of this game",
	"\nAnd of course, YOU, the player, who decided to read the credits instead of playing the game, proving to me how my game is not even as entertaining as some random credits, providing me with emotional damage\n",
]

## print_library(), as data. Each entry: key, kind, name, labelled (shows the unlock label),
## body, flavour. The diamond card's locked/unlocked forms are special-cased in the Python and
## exposed by library_entry(); see tests/parity for the exact print layout.
static var LIBRARY: Array[Dictionary] = [
	{"key": "family", "kind": "relic", "name": "Picture of Family", "labelled": false,
		"body": "Revives once to %d HP when defeated." % Values.REVIVE_HP,
		"flavour": "'If you don't believe in yourself, believe in me who believe in you'"},
	{"key": "blessed", "kind": "relic", "name": "Blessed Emblem", "labelled": false,
		"body": "Every %d monsters defeated, +%d max HP and fully heals. hp-%d when run starts" % [Values.BLESSED_EVERY, Values.BLESSED_MAX_HP, Values.BLESSED_START_HP_LOSS],
		"flavour": "This Emblem is really blessed, definitely, trust."},
	{"key": "forbidden", "kind": "relic", "name": "Forbidden Book", "labelled": false,
		"body": "Unlocks in the shop: ink-costs %d, max purchase %d, max hold %d, automatically consumed at start of fight and defeats the monster." % [Values.PRICE["ink"], Values.LIMIT["ink"], Values.INK_HOLD],
		"flavour": "What can be more cursed than a book full of equations?"},
	{"key": "bk", "kind": "relic", "name": "K*C bronze membership card", "labelled": true,
		"body": "Chickens heal %d more HP, max purchase +%d" % [Values.CHICKEN_HEAL["bk"] - Values.CHICKEN_HEAL["plain"], Values.CHICKEN_LIMIT["bk"] - Values.CHICKEN_LIMIT["plain"]],
		"flavour": "A membership card that gets you extra food on order!"},
	{"key": "sk", "kind": "relic", "name": "K*C silver membership card", "labelled": true,
		"body": "Chickens heal %d more HP, max purchase +%d" % [Values.CHICKEN_HEAL["sk"] - Values.CHICKEN_HEAL["plain"], Values.CHICKEN_LIMIT["sk"] - Values.CHICKEN_LIMIT["plain"]],
		"flavour": "Don't ask how a membership card increases stock, it's what you call a 'Fantasy world'"},
	{"key": "yd", "kind": "relic", "name": "RAY-24 Drone", "labelled": true,
		"body": "Have a drone to help you fight, having extra atk=its atk! Buy up to %d accumulative upgrades" % Values.DRONE_SLOTS,
		"flavour": "This relic is made in respect to my friend who managed to looked through this unimaginable messy code and spent a few hours given me insights"},
	{"key": "gk", "kind": "relic", "name": "K*C gold membership card", "labelled": true,
		"body": "Chickens heal max, no max purchase limit",
		"flavour": "Shouldn't infinite K*C chicken damage your health? Anyways, eating ALWAYS heals..."},
	{"key": "meowton", "kind": "relic", "name": "Meowton's 2nd lawsuit", "labelled": true,
		"body": "-%d DEF upon equipping, gain extra ATK = total SPD" % Values.MEOWTON_DEF_LOSS,
		"flavour": "I know Newton's 2nd law is multiply, but I need to consider game balance ok?"},
	{"key": "dk", "kind": "relic", "name": "K*C diamond membership card", "labelled": true,
		"body": "Chickens heal max, remove all conditions required to purchase chickens",
		"flavour": "Sorry for the 'yet another K*C card' disappointment, I am not a very creative person"},
	{"key": "devotion", "kind": "artefact", "name": "The Damned Proof of Devotion", "labelled": true,
		"body": "Elixir unlocked in shop: costs %d, max HP - [elixir bought], SPD-%d, extra SPD+%d; for next %d fights, -%d extra SPD after fight, can only buy one per turn." % [Values.PRICE["elixir"], Values.ELIXIR_SPD_LOSS, Values.ELIXIR_EXTRA_SPD, Values.ELIXIR_FIGHTS, Values.ELIXIR_SPD_DECAY],
		"flavour": "But to some soul, isn't energy drinks their only 'elixir'?"},
	{"key": "socks", "kind": "artefact", "name": "Cursed Socks", "labelled": true,
		"body": "Boots sealed. When HP <= %d, unlocks option in the shop to decrease and seal max HP to current HP, gaining the same amount of ATK." % Values.SOCKS_MAX_HP,
		"flavour": "Socks in certain conditions can really have a high ATK, don't find it out the hard way..."},
	{"key": "ar", "kind": "artefact", "name": "Abyssal Rad-Blood Oath", "labelled": true,
		"body": "Unlocks a shop option once per run to lose %d max HP, gain money = {level beaten/%d (round down)}%s." % [Values.AR_MAX_HP_LOSS, Values.AR_LEVEL_STEP, AR_POWER_SIGN],
		"flavour": "A contract to test suspicious water samples in the dungeon, a world without power oppression wouldn't be a realistic one, would it?"},
	{"key": "coinpot", "kind": "artefact", "name": "Alchemist's Coinpot", "labelled": true,
		"body": "Every %d money left before fight gives %d money." % [Values.COINPOT_STEP, Values.COINPOT_PAY],
		"flavour": "So...do the monsters transfer money to you digitally when they get defeated?"},
	{"key": "vitality", "kind": "artefact", "name": "Heart of Excessive Vitality", "labelled": true,
		"body": "Start with %d HP but lose %d%% money before fights, at start of fight HP - %s." % [Values.VITALITY_HP, VITALITY_PERCENT, VITALITY_DRAIN_TEXT],
		"flavour": "I hope that is the right use of 'vitality', I don't fully understand that word till this day"},
	{"key": "carrier", "kind": "artefact", "name": "Carrier of Legend", "labelled": true,
		"body": "Choose %d relics, switch from the 1st to 2nd to 3rd one. All stats except max HP drain to %d at relic switch." % [Values.CARRIER_RELICS, Values.CARRIER_RESET],
		"flavour": "The biggest relic is a drone, so the volume of this bag is realistic...I hope?"},
]

## The text in the Python's unlock_label() (it is greyed there).
static func unlock_label(key: String) -> String:
	return "(unlocks after beating lv. %d)" % UNLOCK_LEVEL[key]


## Library entry as shown for this profile: the diamond card stays secret until unlocked.
static func library_entry(entry: Dictionary, highest: int) -> Dictionary:
	if entry["key"] == "dk" and highest < UNLOCK_LEVEL["dk"]:
		return {"key": "dk", "kind": "relic", "name": "????????", "labelled": true,
				"body": "???????????", "flavour": "", "secret": true}
	return entry
