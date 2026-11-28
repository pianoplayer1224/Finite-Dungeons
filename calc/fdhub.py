from fdval import *
from fdterm import say, ask, shell, status, paint, state
from fdmodel import create_monster, save_code
from fdui import UI, pause, stat_bar, shop, print_descriptions

S = str


class QuitGame(Exception):
    """Raised after the player chose Quit; findun.py stops the program."""


def stats_screen(player, level):
    say("\n--- Player Stats ---")
    say("HP: " + S(player.hp) + "/" + S(player.max_hp))
    for label, base, total in (("ATK", player.atk, player.total_atk()),
                               ("DEF", player.df, player.total_df()),
                               ("SPD", player.spd, player.total_spd())):
        extra = total - base
        if extra > 0:
            say(label + ": " + S(base) + "+" + S(extra) + " (" + S(total) + ")")
        else:
            say(label + ": " + S(base))
    if player.relic == "family" and not player.revive_used:
        say("Revives: 1")
    if player.counters > 0:
        say("Counters: " + S(player.counters))

    m = create_monster(level)
    say("\nNext Monster - Level " + S(level))
    say("HP: " + S(m.hp) + "   ATK: " + S(m.atk) + "   DEF: " + S(m.df) + "   SPD: " + S(m.spd))
    stat_bar(player, level)
    ask("\nPress EXE to return...")


def describe_mine(player):
    from fdtxt2 import RELIC_DESCRIPTIONS, ARTEFACT_DESCRIPTIONS
    relics = player.relics if player.relics else [player.relic]
    relics = [r for r in relics if r]
    if relics:
        print_descriptions("RELIC", relics, RELIC_DESCRIPTIONS)
    else:
        say("You have no relic.")
    if player.artefact:
        print_descriptions("ARTEFACT", [player.artefact], ARTEFACT_DESCRIPTIONS)
    else:
        say("You have no artefact.")


def options_menu(player, level, profile):
    while True:
        say("\n--- Options ---")
        say("1 Turn " + ("off" if UI["show_hits"] else "on")
            + " printing normal attacks in fight")
        say("2 Describe my relic and artefact")
        say("3 Show save code")
        say("4 Turn " + ("off" if state["colours"] else "on") + " colours")
        say("0 Back")
        stat_bar(player, level)
        choice = ask("> ")
        if choice == "0":
            return
        if choice == "1":
            UI["show_hits"] = not UI["show_hits"]
            say("Normal attacks will " + ("" if UI["show_hits"] else "not ")
                + "be printed.")
        elif choice == "2":
            describe_mine(player)
        elif choice == "3":
            shell("Save code:", save_code(profile))
        elif choice == "4":
            state["colours"] = not state["colours"]
            say("Colours are now " + ("on." if state["colours"] else "off."))
        else:
            say(paint("warning", "Invalid input, please try again"))


def confirm_quit(player, level):
    say("\nQuit the game? Levels beaten this run still count.")
    say("1 Yes, quit and show my save code")
    say("0 No, go back")
    stat_bar(player, level)
    return ask("> ") == "1"


def pre_fight(player, level, profile):
    """Menu before each fight. Returns 'dead' (died in the shop), 'quit',
    or None once the fight should start."""
    ac = profile.ac
    player.bought_elixir_this_visit = 0
    while True:
        pause()
        say("\n--- Level " + S(level) + " ---")
        say("1 Shop\n2 Stats\n3 Options\n4 Quit game (shows save code)\n0 Start fight")
        stat_bar(player, level)
        choice = ask("> ")

        if choice == "1":
            if shop(player, level, ac) == "dead":
                return "dead"
        elif choice == "2":
            stats_screen(player, level)
        elif choice == "3":
            options_menu(player, level, profile)
        elif choice == "4":
            if confirm_quit(player, level):
                return "quit"
        elif choice == "0":
            if player.artefact == "coinpot" and player.money >= COINPOT_STEP:
                player.coinpot_bonus += (player.money // COINPOT_STEP) * COINPOT_PAY
            if player.artefact == "vitality":
                player.vitality_drain_pending = True

            atk = player.total_atk()
            spd = player.total_spd()
            df = player.total_df()
            m = create_monster(level)
            if atk > m.df:
                say(paint("muted", "\nYour ATK - Monster DEF = " + S(atk - m.df) + ","))
            else:
                say(paint("muted", "\nYour ATK ≤ Monster DEF,"))
            if m.atk > df:
                say(paint("muted", "\nMonster ATK - Your DEF = " + S(m.atk - df) + ","))
            else:
                say(paint("muted", "\nMonster ATK ≤ Your DEF,"))
            say(paint("muted", "So you will deal " + S(max(atk - m.df, MIN_DAMAGE))
                + " damage per turn,"))
            say(paint("muted", "Monster will deal " + S(max(m.atk - df, MIN_DAMAGE))
                + " damage per turn,"))
            say(paint("muted", "Your spd is " + S(spd) + " compared to the monster's "
                      + S(m.spd) + ","))
            if spd >= m.spd:
                say(paint("muted", "so you will go first!"))
            else:
                say(paint("muted", "so the monster will go first!"))
            status()
            return None
        else:
            say(paint("warning", "Invalid input, please try again"))
