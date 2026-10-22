class_name PlayerState
extends Entity
## Python section 2: Player. Relic(s), artefact, money, purchases, drone, timers.
## Python None for "no relic/artefact" is "" here; relics is empty unless Carrier of Legend.

var money: float = Values.START_MONEY
var artefact: String
# Carrier of Legend holds 3 relics; only one is active at a time.
var relics: Array[String] = []
var active_relic_index := 0
var relic: String
var switches := 0            # Carrier: relic switches performed (max CARRIER_RELICS - 1)

var revive_used := false     # Picture of Family
var revived_this_fight := false
var forbidden_ink := 0       # Forbidden Book: ink currently held (max INK_HOLD)
var forbidden_ink_total := 0  # Forbidden Book: total inks ever bought (max LIMIT["ink"])
var counters := 0            # E-Sword battery counters
var used_e_sword_before := false
var coinpot_bonus: float = 0.0  # Alchemist's Coinpot pending payout
var elixir_timers: Array[int] = []  # one ELIXIR_FIGHTS-fight countdown per elixir drunk
var bought_elixir_this_visit := 0
var books := {"atk": 0, "def": 0, "hp": 0, "spd": 0, "heal": 0}
var bought := {"sword": 0, "shield": 0, "boots": 0, "chicken": 0,
		"battery": 0, "elixir": 0}
var socks_sealed := false    # Cursed Socks activated
var pending_hp_multiplier := 1  # Book of Max HP applies after next fight
var ar_used := false         # Abyssal Rad-Blood Oath: once per run
var vitality_drain_pending := false
var drone := DroneState.new()


## relic_choice is a relic key ("" for none), or an Array of CARRIER_RELICS keys when the
## artefact is "carrier".
func _init(relic_choice: Variant = "", artefact_choice: String = "") -> void:
	super(Values.START_HP, Values.START_STAT, Values.START_STAT, Values.START_STAT)
	artefact = artefact_choice
	if artefact == "carrier":
		relics.assign(relic_choice)
		active_relic_index = 0
		relic = relics[0]
	else:
		relic = relic_choice


# Totals are COMPUTED, never hand-maintained: Meowton's "extra ATK = total SPD" and the
# drone's ATK can never drift out of sync with the stats they derive from.
func total_atk() -> int:
	var total := atk + extra_atk
	if relic == "yd":
		total += drone.atk
	if relic == "meowton":
		total += total_spd()
	return total
