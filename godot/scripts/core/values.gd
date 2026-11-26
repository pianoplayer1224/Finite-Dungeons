class_name Values
extends RefCounted
## Python section 0: VALUES. Generated from balance.yaml by tools/balance.py, like the block
## between "# --- VALUES START ---" and "# --- VALUES END ---" in FiniteDungeons.py: same
## names, same numbers. Edit balance.yaml, not this file (the next run overwrites it). The
## engine, the shop lines, the descriptions and the library all read these, so changing a value
## changes the rules AND the text explaining them. tests/parity checks every constant against
## the Python.
## Python tuples become 2- or 3-element arrays.

# --- Runs and monsters ---
const FINAL_LEVEL := 30           # beat this level to win (save codes store at most 31)
const START_HP := 10              # max HP and HP when a run starts
const START_STAT := 1             # ATK, DEF and SPD when a run starts
const START_MONEY := 0            # money when a run starts
const MONSTER_GROWTH := 1         # a level-L monster has L x this ATK, DEF and SPD,
const MONSTER_EXTRA_HP := 4       #   and that + this many HP
const WIN_MONEY := 4              # money for every monster beaten
const MIN_DAMAGE := 1             # every hit does at least this much

# --- Shop: prices and limits ---
const PRICE := {
	"sword": 2,            # ATK (not sold with the E-Sword or the Drone)
	"shield": 2,           # DEF
	"boots": 2,            # SPD (not sold with Cursed Socks)
	"chicken": 2,          # heals, see Chickens below
	"book": 3,             # every kind: Attack, Defence, Speed, Max HP, Healing
	"battery": 2,          # E-Sword only: counter-attacks
	"ink": 9,              # Forbidden Book only: kills the next monster outright
	"elixir": 2,           # Devotion only, see Artefacts below
}
const LIMIT := {                  # how many you can buy in one run
	"sword": 1,
	"shield": 1,
	"boots": 1,
	"book": 3,             # of EACH kind of book
	"battery": 5,
	"ink": 10,             # one FORBIDDEN_MESSAGES line per ink: add lines if raised
	"elixir": 1,           # per shop visit, not per run
}
const FLAT_ITEM_GAIN := 1         # Sword / Shield / Boots add this to ATK / DEF / SPD
const BOOK_MULTIPLIER := 2        # Books of Attack / Defence / Speed / Max HP multiply
								  #   that stat (the Max HP book says "double")

# --- Chickens (the K*C membership card relics change them) ---
const CHICKEN_HEAL := {"plain": 5, "bk": 8, "sk": 10}  # gold and diamond cards heal to max
const CHICKEN_LIMIT := {"plain": 1, "bk": 2, "sk": 4}  # gold and diamond cards: no limit
const CHICKEN_MIN_MISSING := 5    # plain/bronze/silver: sold only with this much HP missing

# --- Relics ---
const REVIVE_HP := 1              # Picture of Family: revives you once, at this HP
const BLESSED_EVERY := 3          # Blessed Emblem: after every 3rd level,
const BLESSED_MAX_HP := 5         #   +5 max HP, then a full heal;
const BLESSED_START_HP_LOSS := 1  #   -1 HP when a run starts with it packed
const INK_HOLD := 1               # Forbidden Book: inks you can carry at once
const ESWORD_ATK := 1             # E-Sword: ATK it gives when equipped
const BATTERY_COUNTERS := 1       # E-Sword: counter-attacks per battery
const MEOWTON_DEF_LOSS := 1       # Meowton's 2nd lawsuit: DEF lost when equipped

# --- RAY-24 Drone: 4 upgrade tracks, 4 stages each ---
const DRONE_SLOTS := 6            # paid upgrades per run, all tracks together
const DRONE_STAGES := 4           # stages per track (the lists below have one per stage)
const DRONE_STAGE_COSTS := [      # price of each stage
	[1, 2, 3, 4],          # track 1 Hardpoint munition upgrade: drone ATK
	[2, 2, 2, 4],          # track 2 Alpha strike: missiles at the start of fights
	[2, 2, 2, 3],          # track 3 FARP Protocol: healing after each win
	[2, 2, 2, 3],          # track 4 Materiel Recovery: money after each win
]
const DRONE_T1_ATK_GAIN := [1, 2, 2, 8]  # track 1: drone ATK each stage adds
const DRONE_MISSILE_MULTIPLIER := 2      # track 2 from stage 2: a missile hits for drone
										 #   ATK x this (the text says "double")
const DRONE_STAGE4_MISSILES := 3         # track 2 stage 4: missiles per fight, each
const DRONE_SHRED_MULTIPLIER := 2        #   cutting monster DEF by its damage x this
const DRONE_HEALS := [10, 20, 50]        # track 3 stages 1-3: HP healed after a win
										 #   (they add up: 10, then 30, then 80)
const DRONE_HEAL_MULTIPLIER := 2         # track 3 stage 4: all healing x this ("doubles")
const DRONE_T4_MONEY := [10, 16]         # track 4 stages 2-3: money after a win
										 #   (stage 1 gives money = drone ATK)
const DRONE_INCOME_MULTIPLIER := 2       # track 4 stage 4: all income x this ("double")

# --- Artefacts ---
const ELIXIR_SPD_LOSS := 1        # Devotion's Elixir: -1 SPD and -[Elixirs bought] max HP,
const ELIXIR_EXTRA_SPD := 9       #   +9 extra SPD,
const ELIXIR_FIGHTS := 3          #   wearing off over the next 3 fights:
const ELIXIR_SPD_DECAY := 3       #   -3 extra SPD after each of them
const SOCKS_MAX_HP := 4           # Cursed Socks: activate at this HP or less
const AR_MAX_HP_LOSS := 5         # Abyssal Rad-Blood Oath: the water sample (once per run)
const AR_LEVEL_STEP := 5          #   costs 5 max HP and pays
const AR_POWER := 4               #   (levels beaten // 5) ** this money
const COINPOT_STEP := 3           # Alchemist's Coinpot: every 3 money left when you leave
const COINPOT_PAY := 2            #   the shop pays 2 money before the fight
const VITALITY_HP := 50           # Heart of Excessive Vitality: start with 50 max HP and HP,
const VITALITY_MONEY_LOSS := 0.10 #   lose this share of your money before each fight,
const VITALITY_DRAIN_DIVISOR := 1 #   then lose HP = money / this
const CARRIER_RELICS := 3         # Carrier of Legend: relics packed (switches = this - 1);
const CARRIER_RESET := 1          #   HP, ATK, DEF and SPD drop to this at a switch

# --- Unlocks: (key, highest level beaten needed). List order = menu order. ---
const RELIC_UNLOCKS := [
	["family", 0],
	["blessed", 0],
	["forbidden", 0],
	["e-sword", 999999],   # kept out of the game until it is balanced
	["bk", 2],
	["sk", 6],
	["yd", 8],
	["gk", 10],
	["meowton", 15],
	["dk", 30],
]
const ARTEFACT_UNLOCKS := [
	["devotion", 3],
	["socks", 5],
	["ar", 12],
	["coinpot", 18],
	["carrier", 20],
	["vitality", 20],
]

# --- Achievements ---
const RICH_MONEY := 32000000      # "you can't take it with you": die holding this much
const FEW_RUNS := 3               # "The real game": beat FINAL_LEVEL within this many runs
const HARD_MODE_LEVEL := 2        # "hard mode": die on this level with Meowton + Cursed Socks

# --- Interface ---
const MENU_PAUSE := 0.3           # seconds of pause before the shop and main menu redraw
const TEXT_COLOURS := {           # RGB colour of each kind of text (both screens are white)
	"muted": [160, 160, 160],    # greyed-out items, flavour lines, the fight forecast
	"story": [100, 100, 100],    # story scenes
	"good": [0, 128, 0],         # your hits, heals, purchases, wins
	"bad": [190, 0, 0],          # monster hits, drains, deaths
	"warning": [190, 0, 0],      # blocked purchases, invalid input
}                          # anything else (menus, stats, headings, money) is
						   # the normal text colour. Money lines are marked
						   # "money": add a "money" entry here to colour them.
const COLOURS_ON := true          # colours at start; players can switch them off in-game
