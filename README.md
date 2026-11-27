# Finite Dungeons

A short auto-battler where life choices and shopping collide, by Timothy Tang, helped by Ray.
Fight your way up 30 dungeon levels by buying the right gear between fights, then beat the
level 30 boss.

It comes in three editions with the same rules, numbers, jokes and save codes. Every value they
play by is in [`balance.yaml`](balance.yaml). To change one, edit it there and run
`python3 tools/balance.py`: it updates all three editions, then checks that they still play the
same game.

| Edition | Folder | How to play |
| --- | --- | --- |
| PC (terminal) | [`pc/`](pc) | `python3 pc/FiniteDungeons.py` |
| Casio fx-CG100 | [`calc/`](calc) | Copy all 14 files to the calculator, then run `findun.py` from the Python app. |
| Godot 4 (desktop, web, Android) | [`godot/`](godot) | Play the web version at https://fd.sealnet.xyz/, or open `godot/project.godot` in Godot 4.7. |

## How to play

1. **Start a run.** Choose an artefact and a relic. They bend the rules: a drone that fights for
   you, a purse that grows interest, a second life. You unlock more of both as your best level
   rises.
2. **Shop.** Before each fight, spend money on gear. Swords, shields and boots raise ATK, DEF and
   SPD. Chicken heals you, and books and elixirs do stranger things.
3. **Fight.** Combat is automatic. The faster fighter hits first (ties go to you). Each hit takes
   the attacker's ATK minus the defender's DEF off the defender's HP, at least 1.
4. **Climb.** Monsters gain +1 to every stat each level, so keep shopping.
5. **Die and try again.** A defeat sends you back to level 1, usually with new relics and
   artefacts unlocked for the next run.

Your four stats are HP, ATK (attack), DEF (defence) and SPD (speed). A full clear takes a few
minutes. Every edition has a library describing each relic and artefact (main menu **3** on PC
and calculator); the Godot edition's **How to play** has the original tutorial. For a 3-run
win, see [`strats/`](strats).

## Controls

**PC and calculator.** Type menu numbers and press Enter (**EXE** on the calculator, **DEL** to
delete). Before each fight: **1** Shop, **2** Stats, **3** Options, **4** Quit (shows your save
code), **0** Start fight. The status bar shows HP, money, your stats and the next monster's
level. Both editions use the same keys.

On the calculator, **UP/DOWN** page through earlier text, **LEFT** jumps to the start of the
latest output and **RIGHT** goes back to the end. Save codes (they contain letters) are typed
in the Shell when asked. Every save code is also printed to the Shell, so it is still there
after **AC** stops the game.

**Godot.** The mouse (or touch) does everything. **Enter** starts the fight at camp, the number
keys pick an option by its number from the original game's menus, **Esc** opens the options and
**F11** toggles fullscreen.

## Saving

A five-character save code holds your runs, best level and achievements. Codes work in every
edition, so you can carry on from one to another. The Godot edition also saves automatically;
**Save code** in its main menu shows yours.

## Repository layout

| Path | What it is |
| --- | --- |
| `pc/FiniteDungeons.py` | The PC edition: one file, and the reference the other two follow. |
| `calc/` | The fx-CG100 edition (MicroPython 1.9.4). |
| `godot/` | The Godot 4 project; asset credits in `godot/credits.txt`. |
| `balance.yaml` | Every gameplay value, with what it does: the one place to change them. |
| `tools/` | `balance.py` (writes `balance.yaml` into every edition), plus checks and searches for the PC and calculator editions. |
| `strats/` | How to win in three runs. |
| `archive/` | The original game and other reference copies. |
