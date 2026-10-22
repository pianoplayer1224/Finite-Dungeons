# fdshop.py - shop purchase engine for Finite Dungeons (fx-CG100).
# Hand-ported from section 4 (ENGINE) of "FiniteDungeons.py": pure logic,
# no I/O. Each function mutates state and returns event dicts for fdevent.

from fdval import *


def unlocked_relics(highest):
    return [r for r, lvl in RELIC_UNLOCKS if highest >= lvl]


def unlocked_artefacts(highest):
    return [a for a, lvl in ARTEFACT_UNLOCKS if highest >= lvl]


def try_revive(player, out, in_combat):
    """Picture of Family: revive once to REVIVE_HP. Returns True if it fired.

    EVERY place that can drop the player to 0 HP must call this.
    """
    if player.hp <= 0 and player.relic == "family" and not player.revive_used:
        player.max_hp = max(player.max_hp, REVIVE_HP)
        player.hp = REVIVE_HP
        player.revive_used = True
        player.revived_this_fight = True
        out.append({"type": "revive", "in_combat": in_combat})
        return True
    return False


def blocked(item, reason, key=None, variant=None):
    ev = {"type": "buy_blocked", "item": item, "reason": reason}
    if key is not None:
        ev["key"] = key
    if variant is not None:
        ev["variant"] = variant
    return ev


def try_buy(player, item, ac):
    """Attempt one shop purchase. Returns (events, died_in_shop)."""
    out = []

    if item in ("sword", "shield", "boots"):
        if player.bought[item] >= LIMIT[item]:
            out.append(blocked(item, "limit"))
        elif item == "boots" and player.artefact == "socks":
            out.append(blocked(item, "socks"))
        elif player.money < PRICE[item]:
            out.append(blocked(item, "money"))
        else:
            player.money -= PRICE[item]
            player.bought[item] += 1
            if item == "sword":
                player.atk += FLAT_ITEM_GAIN
            elif item == "shield":
                player.df += FLAT_ITEM_GAIN
            else:
                player.spd += FLAT_ITEM_GAIN
            out.append({"type": "purchased", "item": item, "cost": PRICE[item]})

    elif item == "chicken":
        out += buy_chicken(player, ac)

    elif item.startswith("book_"):
        key = item.split("_")[1]
        if player.books[key] >= LIMIT["book"]:
            out.append(blocked("book", "limit", key=key))
        elif player.money < PRICE["book"]:
            out.append(blocked("book", "money", key=key))
        elif key == "hp" and player.socks_sealed:
            out.append(blocked("book", "sealed", key=key))
        else:
            if key == "heal":
                player.hp = player.max_hp
            elif key == "hp":
                player.pending_hp_multiplier *= BOOK_MULTIPLIER
            elif key == "spd":
                player.spd *= BOOK_MULTIPLIER
            elif key == "atk":
                player.atk *= BOOK_MULTIPLIER
            elif key == "def":
                player.df *= BOOK_MULTIPLIER
            player.books[key] += 1
            player.money -= PRICE["book"]
            out.append({"type": "purchased", "item": "book", "key": key, "cost": PRICE["book"]})

    elif item == "battery":
        if player.relic != "e-sword":
            out.append(blocked("battery", "no_esword"))
        elif player.bought["battery"] >= LIMIT["battery"]:
            out.append(blocked("battery", "limit"))
        elif player.money < PRICE["battery"]:
            out.append(blocked("battery", "money"))
        else:
            player.counters += BATTERY_COUNTERS
            player.money -= PRICE["battery"]
            player.bought["battery"] += 1
            out.append({"type": "purchased", "item": "battery", "cost": PRICE["battery"]})

    elif item == "ink":
        if player.forbidden_ink_total >= LIMIT["ink"]:
            out.append(blocked("ink", "max"))
        elif player.forbidden_ink >= INK_HOLD:
            out.append(blocked("ink", "held"))
        elif player.money < PRICE["ink"]:
            out.append(blocked("ink", "money"))
        else:
            player.forbidden_ink += 1
            player.forbidden_ink_total += 1
            player.money -= PRICE["ink"]
            out.append({"type": "purchased", "item": "ink", "cost": PRICE["ink"],
                        "total": player.forbidden_ink_total})

    elif item == "elixir":
        return buy_elixir(player, ac)

    return out, False


def chicken_variant(relic):
    """Which membership card (if any) governs chicken purchases."""
    return relic if relic in ("bk", "sk", "gk", "dk") else "plain"


def buy_chicken(player, ac):
    out = []
    variant = chicken_variant(player.relic)

    if variant in ("bk", "sk"):
        limit = CHICKEN_LIMIT[variant]
        if player.bought["chicken"] >= limit:
            out.append(blocked("chicken", "limit", variant=variant))
        elif player.money < PRICE["chicken"]:
            out.append(blocked("chicken", "money", variant=variant))
        elif player.max_hp - player.hp < CHICKEN_MIN_MISSING:
            out.append(blocked("chicken", "hp_full", variant=variant))
        else:
            healed = min(player.hp + CHICKEN_HEAL[variant], player.max_hp) - player.hp
            player.hp += healed
            player.money -= PRICE["chicken"]
            player.bought["chicken"] += 1
            out.append({"type": "purchased", "item": "chicken", "variant": variant,
                        "cost": PRICE["chicken"], "healed": healed})

    elif variant == "gk":
        if player.money < PRICE["chicken"]:
            out.append(blocked("chicken", "money", variant=variant))
        else:
            healed = player.max_hp - player.hp
            player.hp = player.max_hp
            player.money -= PRICE["chicken"]
            player.bought["chicken"] += 1
            out.append({"type": "purchased", "item": "chicken", "variant": variant,
                        "cost": PRICE["chicken"], "healed": healed})

    elif variant == "dk":
        # Diamond card removes ALL purchase conditions - including having the money.
        healed = player.max_hp - player.hp
        player.hp = player.max_hp
        player.money -= PRICE["chicken"]
        player.bought["chicken"] += 1
        if player.money < 0:
            ac["negative_money"] = True
        out.append({"type": "purchased", "item": "chicken", "variant": variant,
                    "cost": PRICE["chicken"], "healed": healed})

    else:
        if player.bought["chicken"] >= CHICKEN_LIMIT["plain"]:
            out.append(blocked("chicken", "limit", variant=variant))
        elif player.money < PRICE["chicken"]:
            out.append(blocked("chicken", "money", variant=variant))
        elif player.max_hp - player.hp < CHICKEN_MIN_MISSING:
            out.append(blocked("chicken", "hp_full", variant=variant))
        else:
            heal = CHICKEN_HEAL["plain"]
            if player.drone.stages[2] == 4:  # FARP stage 4 multiplies all healing
                heal *= DRONE_HEAL_MULTIPLIER
            healed = min(player.hp + heal, player.max_hp) - player.hp
            player.hp += healed
            player.money -= PRICE["chicken"]
            player.bought["chicken"] += 1
            out.append({"type": "purchased", "item": "chicken", "variant": variant,
                        "cost": PRICE["chicken"], "healed": healed})

    return out


def buy_elixir(player, ac):
    out = []
    if player.bought_elixir_this_visit >= LIMIT["elixir"]:
        out.append(blocked("elixir", "visit_limit"))
    elif player.money < PRICE["elixir"]:
        out.append(blocked("elixir", "money"))
    else:
        player.money -= PRICE["elixir"]
        player.bought["elixir"] += 1
        player.bought_elixir_this_visit += 1
        player.max_hp -= player.bought["elixir"]
        if player.hp > player.max_hp:
            player.hp = player.max_hp
        if player.hp <= 0 and not try_revive(player, out, False):
            ac["shop_death"] = True
            out.append({"type": "shop_death", "cause": "elixir"})
            return out, True

        player.spd -= ELIXIR_SPD_LOSS
        player.extra_spd += ELIXIR_EXTRA_SPD
        player.elixir_timers.append(ELIXIR_FIGHTS)
        out.append({"type": "purchased", "item": "elixir", "cost": PRICE["elixir"],
                    "total": player.bought["elixir"]})
    return out, False


def activate_socks(player):
    out = []
    if player.socks_sealed:
        out.append({"type": "socks_blocked", "reason": "already"})
    elif player.hp > SOCKS_MAX_HP:
        out.append({"type": "socks_blocked", "reason": "hp_too_high"})
    else:
        atk_gain = player.max_hp - player.hp
        player.atk += atk_gain
        player.max_hp = player.hp
        player.socks_sealed = True
        out.append({"type": "socks_activated", "atk_gain": atk_gain,
                    "max_hp": player.max_hp})
    return out


def water_sample_reward(player, level):
    """Money the 235 option pays at this level (doubled by drone track 4 stage 4)."""
    base = ((level - 1) // AR_LEVEL_STEP) ** AR_POWER
    return base * DRONE_INCOME_MULTIPLIER if player.drone.stages[3] == 4 else base


def take_water_sample(player, level, ac):
    """Abyssal Rad-Blood Oath's 235 shop option. Returns (events, died_in_shop)."""
    out = []
    if player.ar_used:
        out.append({"type": "water_sample_blocked"})
        return out, False

    player.ar_used = True
    player.max_hp -= AR_MAX_HP_LOSS
    player.hp = min(player.hp, player.max_hp)
    arb = water_sample_reward(player, level)
    player.money += arb
    out.append({"type": "water_sample", "money": arb, "max_hp_lost": AR_MAX_HP_LOSS})

    if player.hp <= 0 and not try_revive(player, out, False):
        ac["shop_death"] = True
        out.append({"type": "shop_death", "cause": "water_sample"})
        return out, True
    return out, False
