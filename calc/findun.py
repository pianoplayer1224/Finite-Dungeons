# findun.py - Finite Dungeons for the Casio fx-CG100 (MicroPython 1.9.4).
# Run this file from the Python app; every calc/*.py file must sit next to it.
# Finite Dungeons - Demo Version, created by Timothy
# Copyright (c) 2026 Timothy Tang

from fdval import *
from fdterm import say, shell, ask, ask_text, status, G, R, paint, state
from fddata import RELIC_NAMES, ARTEFACT_MENU_NAMES, ACHIEVEMENT_DISPLAY
from fddata import ACHIEVEMENT_SECRET_HINTS, UNLOCK_LEVEL
from fdmodel import Player, Profile, create_monster, save_code, load_code
from fdshop import unlocked_relics, unlocked_artefacts
from fdfight import vitality_money_penalty, coinpot_payout, fight, post_fight
from fdui import render_events, print_descriptions
from fdhub import pre_fight, QuitGame
from fdtxt1 import BLESSED_FUMBLE_TEXT

S = str


def ask_number():
    try:
        return int(ask("> "))
    except ValueError:
        return None


def choose_artefact(artefacts):
    if not artefacts:
        say("No artefacts unlocked yet! You must continue without one.")
        return None
    while True:
        say("\nChoose, with all your brain power, one artefact:")
        say("0 No artefact")
        for i in range(len(artefacts)):
            say(S(i + 1) + " " + ARTEFACT_MENU_NAMES[artefacts[i]])
        say("505 show artefact descriptions")
        choice = ask_number()
        if choice is None:
            say(paint("warning", "Invalid input. Please enter a number."))
            continue
        if choice == 0:
            return None
        if choice == 505:
            from fdtxt2 import ARTEFACT_DESCRIPTIONS
            print_descriptions("ARTEFACT", artefacts, ARTEFACT_DESCRIPTIONS)
            continue
        if 1 <= choice <= len(artefacts):
            return artefacts[choice - 1]
        say(paint("warning", "Invalid choice. Select a valid artefact number."))


def choose_relic(relics):
    while True:
        say("0 No relic")
        for i in range(len(relics)):
            say(S(i + 1) + " " + RELIC_NAMES[relics[i]])
        say("505 show relics description")
        choice = ask_number()
        if choice is None:
            say(paint("warning", "Invalid input. Please enter a number."))
            continue
        if choice == 0:
            return None
        if choice == 505:
            from fdtxt2 import RELIC_DESCRIPTIONS
            print_descriptions("RELIC", relics, RELIC_DESCRIPTIONS)
            continue
        if 1 <= choice <= len(relics):
            return relics[choice - 1]
        say(paint("warning", "Invalid choice. Select a valid relic number."))


def choose_carrier_relics(relics):
    say("You chose the Carrier of Legend! Pick " + S(CARRIER_RELICS) + " relics in order "
        "(only the first one is active at start).")
    picked = []
    for n in range(1, CARRIER_RELICS + 1):
        while True:
            say("\nSelect relic #" + S(n) + ":")
            for i in range(len(relics)):
                say(S(i + 1) + " " + RELIC_NAMES[relics[i]])
            say("505 show relic descriptions")
            raw = ask("> ")
            if raw == "505":
                from fdtxt2 import RELIC_DESCRIPTIONS
                print_descriptions("RELIC", relics, RELIC_DESCRIPTIONS)
                continue
            try:
                choice = int(raw)
            except ValueError:
                say(paint("warning", "Invalid input."))
                continue
            if 1 <= choice <= len(relics):
                chosen = relics[choice - 1]
                if chosen in picked:
                    say(paint("warning", "You already picked that relic."))
                    continue
                picked.append(chosen)
                break
            say(paint("warning", "Invalid choice."))
    return picked


def end_of_run(profile, level_died_at):
    profile.highest = max(profile.highest, level_died_at - 1)
    say(paint("bad", "\nYou died! Level completed this run: " + S(level_died_at - 1)
              + ".   Highest: " + S(profile.highest)))


def run(profile):
    profile.runs += 1
    relics = unlocked_relics(profile.highest)
    artefacts = unlocked_artefacts(profile.highest)

    artefact = choose_artefact(artefacts)

    say("\nChoose, very carefully, your relic:")
    if artefact == "carrier":
        player = Player(choose_carrier_relics(relics), artefact)
    else:
        player = Player(choose_relic(relics), artefact)

    if player.relic == "e-sword":
        player.atk += ESWORD_ATK
        say("You have your own sword, not needing the shop one! +" + S(ESWORD_ATK) + " ATK!")
    if artefact == "vitality":
        player.max_hp = VITALITY_HP
        player.hp = VITALITY_HP
    if player.relic == "meowton":
        player.df -= MEOWTON_DEF_LOSS
        say("A lawsuit is not one that provides defence ability, DEF-" + S(MEOWTON_DEF_LOSS))
    blessed_packed = ("blessed" in player.relics) if player.relics else (player.relic == "blessed")
    if blessed_packed:
        player.hp -= BLESSED_START_HP_LOSS
        say(paint("story", BLESSED_FUMBLE_TEXT))

    for level in range(1, FINAL_LEVEL + 1):
        result = pre_fight(player, level, profile)
        status()
        if result == "quit":
            profile.highest = max(profile.highest, level - 1)
            say("\nYou left the dungeon. Highest: " + S(profile.highest))
            shell("Save code:", save_code(profile))
            raise QuitGame()
        if result == "dead":
            end_of_run(profile, level)
            say("\nRun " + S(profile.runs) + " finished! \n")
            shell("Save code:", save_code(profile))
            return

        render_events(vitality_money_penalty(player))
        render_events(coinpot_payout(player))

        won, events = fight(player, create_monster(level), level, profile.ac)
        render_events(events)

        if not won:
            end_of_run(profile, level)
            if player.money >= RICH_MONEY:
                profile.ac["drich"] = True
            if level == HARD_MODE_LEVEL and player.relic == "meowton" and player.artefact == "socks":
                profile.ac["hmode"] = True
                say("I don't blame you, you just attempted the hardest difficulty")
            say("\nRun " + S(profile.runs) + " finished! \n")
            shell("Save code:", save_code(profile))
            return

        render_events(post_fight(player, level))

    say(paint("good", "\nYou beat level " + S(FINAL_LEVEL) + ". You win!"))
    profile.highest = FINAL_LEVEL
    if profile.runs <= FEW_RUNS:
        profile.ac["trun"] = True
        say(paint("good", "You beat the game with the fewest runs possible!"))
    shell("Save code:", save_code(profile))


def print_achievements(profile):
    say("---unlocked achievements---")
    for key, title, hint in ACHIEVEMENT_DISPLAY:
        if profile.ac[key]:
            say(title)
            say(G + hint + "\n" + R)
    say("---locked achievements---")
    for key, title, hint in ACHIEVEMENT_DISPLAY:
        if not profile.ac[key]:
            say(title)
            if key in ACHIEVEMENT_SECRET_HINTS:
                hint = "?????????"
            say(G + hint + "\n" + R)


def print_library(profile):
    from fdtxt3 import LIB_HEAD, LIB_LOCKED, LIB_DIAMOND, LIB_TAIL
    middle = LIB_LOCKED if profile.highest < UNLOCK_LEVEL["dk"] else LIB_DIAMOND
    for block in (LIB_HEAD, middle, LIB_TAIL):
        for line in block:
            say(line)


def print_credits():
    from fdtxt4 import CREDITS
    for line in CREDITS:
        say(line)


def prompt_save_code(profile, cancel_hint):
    while True:
        code = ask_text("Enter save code (or 0 to " + cancel_hint
                        + ", there is no capital letter i): ").strip()
        if code == "0":
            return
        ok, message = load_code(profile, code)
        shell(message if ok else paint("warning", message))
        if ok:
            return
        shell(paint("warning", "Please try again.\n"))


def main(profile):
    # Ask before drawing: the Shell's input() is the only way to type letters.
    prompt_save_code(profile, "start a new game")
    say("Finite Dungeons by Timothy")
    say("Copyright (c) 2026 Timothy Tang")
    from fdtxt2 import INTRO
    for line in INTRO:
        say(line)

    while True:
        say("MAIN MENU\n1 start run\n2 achievements\n3 library\n4 credits"
            "\n5 input save code\n6 obtain save code\n7 turn colours "
            + ("off" if state["colours"] else "on"))
        act = ask_number()
        if act is None:
            say(paint("warning", "Invalid input, please try again."))
        elif act == 1:
            run(profile)
        elif act == 2:
            print_achievements(profile)
        elif act == 3:
            print_library(profile)
        elif act == 4:
            say("CREDITS\n\nI'd like to give HUGE thanks to these people, without you, "
                "this game wouldn't be possible.")
            print_credits()
        elif act == 5:
            say("(type the save code in the Shell)")
            prompt_save_code(profile, "cancel")
        elif act == 6:
            shell("Save code:", save_code(profile))
        elif act == 7:
            state["colours"] = not state["colours"]
            say("Colours are now " + ("on." if state["colours"] else "off."))
        else:
            say(paint("warning", "Invalid input, please try again"))


profile = Profile()
try:
    main(profile)
except QuitGame:
    pass
except KeyboardInterrupt:
    # AC stops the program; leave the save code in the Shell.
    print("Save code: " + save_code(profile))
except Exception as e:
    print("sorry,an unknown error occurred...\nDo you mind telling me what happened?")
    print(repr(e))
    print("Save code: " + save_code(profile))
