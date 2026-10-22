# How to beat Finite Dungeons

> **Out of date since balance issue 2 (2026-10-21).** Runs 1 and 2 below still work and give the same save codes, but run 3 dies on level 6: the Vitality drain went from half your money to all of it (`VITALITY_DRAIN_DIVISOR` 2 → 1). With the old drain, the route still wins exactly as written. A new run 3 needs finding with `tools/route_search.py`.

Three runs from a brand-new save, which is the fewest possible. The game has **no randomness**, so the exact moves in [`win_actions.txt`](win_actions.txt) win every time. That file lists every level of every run, with what to buy and which keys to press.

| Run | Relic | Artefact | Goal | Ends |
|---|---|---|---|---|
| 1 | Picture of Family | none | unlock Abyssal Rad-Blood Oath (needs highest ≥ 12) | dies on level 13 → highest 12 |
| 2 | Blessed Emblem | Abyssal Rad-Blood Oath | unlock Vitality (needs highest ≥ 20) | dies on level 21 → highest 20 |
| 3 | Blessed Emblem | Heart of Excessive Vitality | **win** | beats level 30 with 117 HP left |

The two deaths are intended. Runs 1 and 2 only exist to unlock the artefacts that run 3 needs.

This route is for the current balance (the Elixir costs 2, Vitality takes 10% of your money, the bronze card unlocks at 2). The V3.1 route went through Devotion, and its Elixirs now cost too much: Blessed + Devotion can't get past level 8.

Checked on `pc/FiniteDungeons.py` and `calc/`. The moves in `win_actions.txt` were replayed through both, and they give the same save codes: **`0033l`** after run 1, **`005od`** after run 2, **`008i1`** after the win.

## Where to start

You don't need a new save. Start at the run your **highest level beaten** allows:

| Your highest | Start at | Why |
|---|---|---|
| 0–11 | Run 1 | Abyssal isn't unlocked yet. |
| 12–19 | Run 2 | You have Abyssal; you still need Vitality. |
| 20 or more | Run 3 | Everything is unlocked. Win now. |

The menu numbers in `win_actions.txt` are the same whatever you've unlocked: Picture of Family is always relic **1**, Blessed Emblem is always relic **2**, Abyssal is always artefact **3**, and Vitality is always artefact **6**. On a save that isn't new, run 1 asks for an artefact: press **0** (no artefact).

For example, the save `002Rz` (1 run, highest 3) starts at run 1: it dies on level 13 with `005G3`, run 2 dies on level 21 with `0080v`, and run 3 wins with `00AuB`. The save `00X7s` (14 runs, highest 19) starts at run 2: `00ZPN`, then the win with `00cHd`. I checked both.

Only a brand-new save can earn **"The real game"** (beat level 30 within 3 runs).

## Controls

Both editions use the same menus and keys. Before each fight you get the level menu: **1** Shop, **2** Stats, **3** Options, **4** Quit, **0** Start fight.

| | PC (`pc/FiniteDungeons.py`) | Calculator (`calc/`) |
|---|---|---|
| Buy an item | **1** (Shop), the item number, Enter … then **0** (Back) | **1** (Shop), the item number, EXE … then **0** (Back) |
| Start the fight | **0** on the level menu | **0** on the level menu |
| Check HP and money | the status line above each prompt | the blue top bar |

`win_actions.txt` gives the keys for every level. Press Enter (PC) or EXE (calculator) after each number.

**Shop numbers** are the same in all three runs: 1 Sword, 2 Shield, 3 Boots, 4 Chicken, 5 Book of Attack, 6 Book of Defence, 7 Book of Speed, 8 Book of Max HP, 9 Book of Healing. In run 2, typing **235** in the shop takes Abyssal's water sample. It isn't listed in the shop menu.

## The three runs in short

**Run 1 (Picture of Family).** Twelve levels. Level 2 kills you and the picture revives you at 1 HP. The Book of Max HP bought before that fight still doubles your max HP afterwards. After that it's Shield, Healing and Defence books, two Max HP books, the Sword, and three Attack books on level 10. You only need to beat level 12, and level 13 then kills you.

**Run 2 (Blessed Emblem + Abyssal).** This is the hard part: reaching level 20 in only the second run. The moves were found by a computer search, and they are tight, so follow them exactly.
- Levels 2–7: Shield and Chicken, then Healing books on 3, 5 and 6, Defence books on 4 and 7, a Max HP book on 5, and the Sword on 7.
- Level 9: type **235** for the water sample. It costs 5 max HP and pays only $1 (8 levels beaten), but that $1 is what pays for the third Book of Attack that visit.
- Level 13: Boots and the last Defence book. Level 15: three Speed books and a Max HP book. Level 18: the last Max HP book. With Blessed, books bought on 15 and 18 are refilled for free (see "Why it works").
- You only need to *beat level 20*. Dying on 21 is fine.

**Run 3 (Blessed Emblem + Vitality), the winning run.**

| Level | Buy | Result |
|---|---|---|
| 2–4 | nothing | |
| 5 | Shield + Book of Defence | DEF 4 |
| 6 | Book of Defence | DEF 8 |
| 10 | Book of Defence | DEF 16 (final) |
| 12 | Sword + Book of Attack ×3 | ATK 16 (final) |
| **15** | Book of Max HP | max HP 70 → 140, and Blessed refills it |
| **18** | Book of Max HP ×2 | max HP 145 → 580, and Blessed refills it |
| 22, 28 | Boots + Book of Speed, then Book of Speed ×2 | SPD 16 |
| 23 | Chicken | |
| 27, 29, 30 | Book of Healing | refill before the big fights |

Don't panic in run 3: level 6 starts with **15 HP** and level 27 with **13 HP**. That's normal. The next Blessed refill or Healing book covers it, and since nothing is random it's the same every time.

## Why it works

1. **Max HP is the only stat that keeps growing.** ATK, DEF and SPD top out at 16: the flat item (+1) followed by three doubling books. A level-*L* monster has `L+4` HP and `L` ATK/DEF/SPD, and every hit does at least 1 damage. So from about level 15 you deal 1 damage per hit, and each fight costs `(L+4) × (L−16)` HP. Level 30 alone costs 476 HP, and there's no healing mid-fight.
2. **Buy the flat item before its books.** Sword then three Attack books gives (1+1)×2×2×2 = **16**. The books first gives only 1×8+1 = 9.
3. **Vitality is required.** It sets your base max HP to 50 instead of 10, and Blessed adds +5 every 3 levels. Three Max HP books then give 585–600 HP. Without Vitality the best you can reach is 440, which isn't enough for level 30.
4. **Buy Max HP books on a level divisible by 3 (with Blessed).** The book doubles your max HP after the fight, and Blessed's full heal comes right after that doubling. So Blessed fills the *new, bigger* bar for free.
5. **Save Healing books for the end.** They refill to max, so a book used on level 29 is worth 600 HP, while the same book on level 5 is worth about 55.

## Mistakes to avoid

- **Don't buy anything extra.** One more purchase changes your money and HP for the rest of the run. Use the "You have" column in `win_actions.txt` to check you're still on track: your HP and money at the start of each level should match it exactly.
- **Don't buy Max HP books early in run 3.** Buy them on levels 15 and 18, as listed. Too early wastes the doubling on a small bar, and too late means levels 19–21 kill you first.
- **With Vitality, don't hoard money.** Before each fight you lose 10% of your money, then lose HP equal to half of what's left, so every $2 you keep costs about 1 HP per fight. The route never holds more than about $26.
- **"4 Quit"** on the level menu ends the run as if you'd died.

## Achievements on this route

| Achievement | Earned |
|---|---|
| **The real game** (beat level 30 in 3 runs) | only from a brand-new save |
| **one hp actually helps?!** (kill a monster after reviving) | run 1, level 2, from Picture of Family's revive |

The other six achievements need deliberate detours. (The V3.1 route also earned **雑魚 / Zako** for a one-shot; this one never one-shots a monster.)
