# Finite Dungeons balance

**Balance issue 4**, 2026-11-09

Every value Finite Dungeons plays by, written out to read and to compare between ports of the
game. Each value goes by the name the original game gives it, so any port's numbers can be
checked against this list name by name, whatever its own code looks like. Two ports on the same
balance issue have the same numbers; the [update log](#update-log) says what changed between
issues.

`PRICE["ink"]` is one entry of a table, `[10, 20, 50]` a list (one number per stage), and
`"bk"`, `"sk"` and the like are the relic and artefact [keys](#keys).

## Runs and monsters

| Name | Value | What it does |
| --- | --- | --- |
| `FINAL_LEVEL` | 30 | Beat this level to win. |
| `START_HP` | 10 | Max HP and HP when a run starts. |
| `START_STAT` | 1 | ATK, DEF and SPD when a run starts. |
| `START_MONEY` | 0 | Money when a run starts. |
| `MONSTER_GROWTH` | 1 | A level-L monster has L × this ATK, DEF and SPD... |
| `MONSTER_EXTRA_HP` | 4 | ...and that + this many HP. |
| `WIN_MONEY` | 4 | Money for every monster beaten. |
| `MIN_DAMAGE` | 1 | Every hit does at least this much. |

## Shop

| Name | Value | What it does |
| --- | --- | --- |
| `PRICE["sword"]` | 2 | +ATK. Not sold with the E-Sword or the RAY-24 Drone. |
| `PRICE["shield"]` | 2 | +DEF. |
| `PRICE["boots"]` | 2 | +SPD. Not sold with Cursed Socks. |
| `PRICE["chicken"]` | 2 | Heals; see [Chickens](#chickens). |
| `PRICE["book"]` | 3 | Every kind: Attack, Defence, Speed, Max HP, Healing. |
| `PRICE["battery"]` | 2 | E-Sword only: counter-attacks. |
| `PRICE["ink"]` | 9 | Forbidden Book only: kills the next monster outright. |
| `PRICE["elixir"]` | 2 | Devotion only; see [Artefacts](#artefacts). |
| `LIMIT["sword"]` | 1 | How many you can buy in one run. |
| `LIMIT["shield"]` | 1 | |
| `LIMIT["boots"]` | 1 | |
| `LIMIT["book"]` | 3 | Of each kind of book. |
| `LIMIT["battery"]` | 5 | |
| `LIMIT["ink"]` | 10 | |
| `LIMIT["elixir"]` | 1 | Per shop visit, not per run. |
| `FLAT_ITEM_GAIN` | 1 | Sword, Shield and Boots add this to ATK, DEF and SPD. |
| `BOOK_MULTIPLIER` | 2 | Books of Attack, Defence, Speed and Max HP multiply that stat by this. |

## Chickens

The K\*C membership card relics change chickens. With the gold or diamond card a chicken heals
to full and there is no limit.

| Name | Value | What it does |
| --- | --- | --- |
| `CHICKEN_HEAL["plain"]` | 5 | HP a chicken heals, without a card. |
| `CHICKEN_HEAL["bk"]` | 8 | With the bronze card. |
| `CHICKEN_HEAL["sk"]` | 10 | With the silver card. |
| `CHICKEN_LIMIT["plain"]` | 1 | Chickens you can buy in one run, without a card. |
| `CHICKEN_LIMIT["bk"]` | 2 | With the bronze card. |
| `CHICKEN_LIMIT["sk"]` | 4 | With the silver card. |
| `CHICKEN_MIN_MISSING` | 5 | Without a card or with bronze or silver, sold only with this much HP missing. |

## Relics

| Name | Value | What it does |
| --- | --- | --- |
| `REVIVE_HP` | 1 | Picture of Family: revives you once, at this HP. |
| `BLESSED_EVERY` | 3 | Blessed Emblem: after every 3rd level... |
| `BLESSED_MAX_HP` | 5 | ...+5 max HP, then a full heal. |
| `BLESSED_START_HP_LOSS` | 1 | ...and -1 HP when a run starts with it packed. |
| `INK_HOLD` | 1 | Forbidden Book: inks you can carry at once. |
| `ESWORD_ATK` | 1 | E-Sword: ATK it gives when equipped. |
| `BATTERY_COUNTERS` | 1 | E-Sword: counter-attacks per battery. |
| `MEOWTON_DEF_LOSS` | 1 | Meowton's Second Lawsuit: DEF lost when equipped. |

## RAY-24 Drone

Four upgrade tracks of four stages each. `DRONE_STAGE_COSTS`, the price of each stage:

| Track | Stage 1 | Stage 2 | Stage 3 | Stage 4 |
| --- | --- | --- | --- | --- |
| 1 Hardpoint munition upgrade (drone ATK) | 1 | 2 | 3 | 4 |
| 2 Alpha strike (missiles at the start of fights) | 2 | 2 | 2 | 4 |
| 3 FARP Protocol (healing after each win) | 2 | 2 | 2 | 3 |
| 4 Materiel Recovery (money after each win) | 2 | 2 | 2 | 3 |

| Name | Value | What it does |
| --- | --- | --- |
| `DRONE_SLOTS` | 6 | Paid upgrades per run, all tracks together. |
| `DRONE_STAGES` | 4 | Stages per track. |
| `DRONE_T1_ATK_GAIN` | [1, 2, 2, 8] | Track 1: drone ATK each stage adds. |
| `DRONE_MISSILE_MULTIPLIER` | 2 | Track 2, from stage 2: a missile hits for drone ATK × this. |
| `DRONE_STAGE4_MISSILES` | 3 | Track 2, stage 4: missiles per fight, each... |
| `DRONE_SHRED_MULTIPLIER` | 2 | ...cutting the monster's DEF by its damage × this. |
| `DRONE_HEALS` | [10, 20, 50] | Track 3, stages 1-3: HP healed after a win. They add up: 10, then 30, then 80. |
| `DRONE_HEAL_MULTIPLIER` | 2 | Track 3, stage 4: all healing × this. |
| `DRONE_T4_MONEY` | [10, 16] | Track 4, stages 2-3: money after a win. They add up: 10, then 26. Stage 1 gives money = drone ATK. |
| `DRONE_INCOME_MULTIPLIER` | 2 | Track 4, stage 4: all income × this. |

## Artefacts

| Name | Value | What it does |
| --- | --- | --- |
| `ELIXIR_SPD_LOSS` | 1 | The Damned Proof of Devotion's elixir: -1 SPD and -[elixirs bought] max HP... |
| `ELIXIR_EXTRA_SPD` | 9 | ...+9 extra SPD... |
| `ELIXIR_FIGHTS` | 3 | ...wearing off over the next 3 fights... |
| `ELIXIR_SPD_DECAY` | 3 | ...-3 extra SPD after each of them. |
| `SOCKS_MAX_HP` | 5 | Cursed Socks: activate at this HP or less. |
| `AR_MAX_HP_LOSS` | 5 | Abyssal Rad-Blood Oath: the water sample (once per run) costs 5 max HP... |
| `AR_LEVEL_STEP` | 5 | ...and pays (levels beaten ÷ 5, rounded down)... |
| `AR_POWER` | 4 | ...to this power, in money. |
| `COINPOT_STEP` | 3 | Alchemist's Coinpot: every 3 money you still have when you leave the shop... |
| `COINPOT_PAY` | 2 | ...pays 2 money before the fight. |
| `VITALITY_HP` | 50 | Heart of Excessive Vitality: start with 50 max HP and HP... |
| `VITALITY_MONEY_LOSS` | 0.10 | ...lose this share of your money before each fight... |
| `VITALITY_DRAIN_DIVISOR` | 1 | ...then lose HP = money ÷ this. |
| `CARRIER_RELICS` | 3 | Carrier of Legend: relics packed (switches = this - 1)... |
| `CARRIER_RESET` | 1 | ...and HP, ATK, DEF and SPD drop to this at a switch. |

## Unlocks

The highest level you need to have beaten. The order is the menu order.

`RELIC_UNLOCKS`

| Key | Relic | Level |
| --- | --- | --- |
| `family` | Picture of Family | 0 |
| `blessed` | Blessed Emblem | 0 |
| `forbidden` | Forbidden Book | 0 |
| `e-sword` | Automatic Counter E-Sword | 999999 (kept out of the game until it is balanced) |
| `bk` | K\*C bronze membership card | 2 |
| `sk` | K\*C silver membership card | 6 |
| `yd` | RAY-24 Drone | 8 |
| `gk` | K\*C gold membership card | 10 |
| `meowton` | Meowton's Second Lawsuit | 15 |
| `dk` | K\*C diamond membership card | 30 |

`ARTEFACT_UNLOCKS`

| Key | Artefact | Level |
| --- | --- | --- |
| `devotion` | The Damned Proof of Devotion | 3 |
| `socks` | Cursed Socks | 5 |
| `ar` | Abyssal Rad-Blood Oath | 12 |
| `coinpot` | Alchemist's Coinpot | 18 |
| `carrier` | Carrier of Legend | 20 |
| `vitality` | Heart of Excessive Vitality | 20 |

## Achievements

| Name | Value | What it does |
| --- | --- | --- |
| `RICH_MONEY` | 32000000 | "you can't take it with you": die holding this much money. |
| `FEW_RUNS` | 3 | "The real game": beat `FINAL_LEVEL` within this many runs. |
| `HARD_MODE_LEVEL` | 2 | "hard mode": die on this level with Meowton's Second Lawsuit and Cursed Socks. |

## Interface

Not balance, but the original game keeps them with the values.

| Name | Value | What it does |
| --- | --- | --- |
| `MENU_PAUSE` | 0.3 | Seconds of pause before the shop and main menu redraw (the terminal game). |
| `TEXT_COLOURS["muted"]` | (160, 160, 160) | RGB colour of greyed-out items, flavour lines, the fight forecast. |
| `TEXT_COLOURS["story"]` | (100, 100, 100) | Story scenes. |
| `TEXT_COLOURS["good"]` | (0, 128, 0) | Your hits, heals, purchases, wins. |
| `TEXT_COLOURS["bad"]` | (190, 0, 0) | Monster hits, drains, deaths. |
| `TEXT_COLOURS["warning"]` | (190, 0, 0) | Blocked purchases, invalid input. |
| `COLOURS_ON` | true | Colours at start; players can switch them off in-game. |

## Keys

The relics are `family`, `blessed`, `forbidden`, `e-sword`, `bk`, `sk`, `yd`, `gk`, `meowton`
and `dk`; the artefacts `devotion`, `socks`, `ar`, `coinpot`, `carrier` and `vitality`. The
[Unlocks](#unlocks) tables give each one's name. In the chicken tables, `"plain"` means no K\*C
card.

## Update log

| Issue | Date | Changes |
| --- | --- | --- |
| 4 | 2026-11-09 | `ELIXIR_EXTRA_SPD` 6 → 9.<br>`ELIXIR_SPD_DECAY` 2 → 3.<br>`SOCKS_MAX_HP` 3 → 5.<br>`RELIC_UNLOCKS`: `sk` 7 → 6.<br>`ARTEFACT_UNLOCKS`: `socks` 6 → 5.<br>`RICH_MONEY` 25000000 → 32000000. |
| 3 | 2026-10-21 | `MENU_PAUSE` 0.5 → 0.3. Interface only: the terminal game had paused 0.3 s since 2026-10-16, which this list had missed. |
| 2 | 2026-10-21 | `PRICE["ink"]` 10 → 9.<br>`PRICE["elixir"]` 1 → 2.<br>`CHICKEN_HEAL["bk"]` 7 → 8, `CHICKEN_HEAL["sk"]` 7 → 10.<br>`CHICKEN_LIMIT["bk"]` 1 → 2, `CHICKEN_LIMIT["sk"]` 3 → 4.<br>`DRONE_STAGE_COSTS`, track 4 stage 4: 4 → 3.<br>`DRONE_HEALS` [5, 10, 25] → [10, 20, 50] (in all: 5, 15, 40 → 10, 30, 80).<br>`DRONE_T4_MONEY` [6, 12] → [10, 16] (in all: 6, 18 → 10, 26).<br>`AR_POWER` 3 → 4.<br>`VITALITY_MONEY_LOSS` 0.25 → 0.10.<br>`VITALITY_DRAIN_DIVISOR` 2 → 1 (the description now reads "lose HP equal to money").<br>`RELIC_UNLOCKS`: `bk` 4 → 2, `gk` 12 → 10. |
| 1 | 2026-10-17 | The original values of Timothy Tang's Finite Dungeons. |

## Changing a value

1. Change the value in every port that follows this list, the same way. Descriptions that
   quote a value, such as a relic's "chickens heal 5 more hp" or a drone stage's "heal 30",
   should be built from it, so they follow by themselves.
2. Update its row here, add an [update log](#update-log) entry with the next issue number,
   today's date and each change as old → new, and change the issue number at the top.
3. If a text gains a new symbol, check that every port can show it: a font without it shows an
   empty box. `AR_POWER` 4, for example, needed a `⁴` where 2 and 3 had used `²` and `³`.
