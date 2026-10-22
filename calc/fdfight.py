# fdfight.py - drone, relic switch, fight and post-fight engine (fx-CG100).
# Hand-ported from section 4 (ENGINE) of "FiniteDungeons.py": pure logic,
# no I/O. Each function mutates state and returns event dicts for fdevent.

from fdval import *
from fdtxt1 import FORBIDDEN_MESSAGES
from fdmodel import Drone
from fdshop import try_revive


def vitality_money_penalty(player):
    """Deduct VITALITY_MONEY_LOSS of current money if artefact is Heart of Excessive Vitality."""
    out = []
    if player.artefact == "vitality" and player.money > 0:
        penalty = player.money * VITALITY_MONEY_LOSS
        player.money -= penalty
        out.append({"type": "vitality_penalty", "amount": penalty})
    return out


def coinpot_payout(player):
    """Pay out the Coinpot bonus accumulated on leaving the shop."""
    out = []
    if player.coinpot_bonus > 0:
        if player.drone.stages[3] == 4:
            player.coinpot_bonus *= DRONE_INCOME_MULTIPLIER
        out.append({"type": "coinpot_payout", "amount": player.coinpot_bonus})
        player.money += player.coinpot_bonus
        player.coinpot_bonus = 0
    return out


def switch_relic(player):
    """Carrier of Legend's 888 shop option."""
    out = []
    if player.switches >= CARRIER_RELICS - 1:
        out.append({"type": "relic_switch_blocked"})
        return out

    player.switches += 1
    player.drone = Drone()
    player.hp = CARRIER_RESET
    player.atk = CARRIER_RESET
    player.df = CARRIER_RESET
    player.spd = CARRIER_RESET

    player.active_relic_index += 1
    player.relic = player.relics[player.active_relic_index]
    out.append({"type": "relic_switched", "relic": player.relic,
                "index": player.active_relic_index})

    if player.relic == "meowton":
        out.append({"type": "meowton_equipped"})
        player.df -= MEOWTON_DEF_LOSS
    if player.relic == "e-sword":
        player.used_e_sword_before = True
        had_sword = player.bought.get("sword", 0) > 0
        if not had_sword:
            player.atk += ESWORD_ATK
            player.counters = 0
        out.append({"type": "esword_equipped", "had_sword": had_sword})
    return out


# ---------- drone upgrades ----------

def apply_drone_stage(player, track):
    """Advance one drone track a single stage and apply its effect.

    Used by BOTH paid purchases and Track 4's free auto-upgrades.
    """
    d = player.drone
    d.stages[track] += 1
    stage = d.stages[track]

    if track == 0:
        d.atk += DRONE_T1_ATK_GAIN[stage - 1]
    elif track == 2 and stage >= 2:
        player.hp = player.max_hp
    elif track == 3:
        if stage == 2:
            for t in range(3):
                if d.stages[t] == 1:
                    apply_drone_stage(player, t)
        elif stage == 3:
            for t in range(3):
                if d.stages[t] == 0:
                    apply_drone_stage(player, t)
        elif stage == 4:
            for t in range(3):
                if d.stages[t] == 3:
                    apply_drone_stage(player, t)


def buy_drone_upgrade(player, track):
    out = []
    d = player.drone
    if d.slots_used >= DRONE_SLOTS:
        out.append({"type": "drone_blocked", "reason": "slots", "track": track})
    elif d.stages[track] >= DRONE_STAGES:
        out.append({"type": "drone_blocked", "reason": "max", "track": track})
    else:
        stage = d.stages[track] + 1
        cost = DRONE_STAGE_COSTS[track][stage - 1]
        if player.money < cost:
            out.append({"type": "drone_blocked", "reason": "money", "track": track})
        else:
            player.money -= cost
            d.slots_used += 1
            apply_drone_stage(player, track)
            out.append({"type": "drone_upgraded", "track": track, "stage": stage,
                        "cost": cost, "drone_atk": d.atk})
    return out


# ---------- fight ----------

def player_strike(player, monster, out, ac):
    atk = player.total_atk()
    df = monster.total_df()
    dmg = max(atk - df, MIN_DAMAGE)
    monster_was_full = (monster.hp == monster.max_hp)
    hp_before = monster.hp
    monster.hp -= dmg
    out.append({"type": "player_hit", "dmg": dmg, "player_hp": player.hp,
                "monster_hp_before": hp_before, "monster_hp": monster.hp})
    # Zako: a true one-hit kill by YOUR attack (ink and drone kills don't count).
    if monster_was_full and monster.hp <= 0:
        ac["one_shot"] = True


def monster_strike(monster, player, out):
    atk = monster.total_atk()
    df = player.total_df()
    dmg = max(atk - df, MIN_DAMAGE)
    hp_before = player.hp
    player.hp -= dmg
    out.append({"type": "monster_hit", "dmg": dmg, "player_hp_before": hp_before,
                "player_hp": player.hp, "monster_hp": monster.hp})

    try_revive(player, out, True)


def drone_volley(player, monster, out, ac):
    """RAY-24's start-of-fight attack (drone track 2)."""
    stage = player.drone.stages[1]
    if stage == 0:
        return
    datk = player.drone.atk

    if stage < 4:
        if stage == 1:
            dmg = max(datk - monster.df, MIN_DAMAGE)
        elif stage == 2:
            dmg = max(datk * DRONE_MISSILE_MULTIPLIER - monster.df, MIN_DAMAGE)
        else:
            dmg = max(datk * DRONE_MISSILE_MULTIPLIER - max(0, monster.df - datk * DRONE_MISSILE_MULTIPLIER), MIN_DAMAGE)
        out.append({"type": "drone_shot", "shot": 0, "dmg": dmg, "shreds_df": False,
                    "monster_hp_before": monster.hp, "monster_hp": monster.hp - dmg})
        monster.hp -= dmg
    else:
        # Stage 4: DRONE_STAGE4_MISSILES shots, each shredding DEF by its damage x DRONE_SHRED_MULTIPLIER.
        for shot in range(DRONE_STAGE4_MISSILES):
            dmg = max(datk * DRONE_MISSILE_MULTIPLIER - max(0, monster.df - datk * DRONE_MISSILE_MULTIPLIER), MIN_DAMAGE)
            new_df = max(monster.df - dmg * DRONE_SHRED_MULTIPLIER, 0)
            out.append({"type": "drone_shot", "shot": shot, "dmg": dmg, "shreds_df": True,
                        "monster_hp_before": monster.hp, "monster_hp": monster.hp - dmg,
                        "monster_df_before": monster.df, "monster_df": new_df,
                        "df_loss": dmg * DRONE_SHRED_MULTIPLIER})
            monster.hp -= dmg
            monster.df = new_df
            if shot == DRONE_STAGE4_MISSILES - 2 and monster.hp <= 0:
                ac["okill"] = True
                out.append({"type": "drone_overkill"})


def fight(player, monster, level, ac):
    """Simulate the whole fight. Returns (player_won, events)."""
    out = []

    if player.total_atk() >= monster.hp + monster.df:
        out.append({"type": "smirk"})

    if player.relic == "yd":
        drone_volley(player, monster, out, ac)

    # Heart of Excessive Vitality wallet drain, clamped at 0.
    if player.vitality_drain_pending:
        player.vitality_drain_pending = False
        drain = max(0, int(player.money // VITALITY_DRAIN_DIVISOR))
        player.hp -= drain
        out.append({"type": "vitality_drain", "amount": drain, "player_hp": player.hp})
        try_revive(player, out, True)
        if not player.is_alive():
            return False, out

    # Forbidden Ink: instant kill.
    if player.forbidden_ink > 0:
        msg_index = min(LIMIT["ink"] - player.forbidden_ink_total, len(FORBIDDEN_MESSAGES) - 1)
        out.append({"type": "ink_kill", "message_index": msg_index,
                    "final_boss": level == FINAL_LEVEL})
        monster.hp = 0
        player.forbidden_ink -= 1
        return True, out

    while player.is_alive() and monster.is_alive():
        if player.total_spd() >= monster.total_spd():
            player_strike(player, monster, out, ac)
            if not monster.is_alive():
                break
            if player.counters > 0:
                player.counters -= 1
                player_strike(player, monster, out, ac)
            else:
                monster_strike(monster, player, out)
        else:
            if player.counters > 0:
                player.counters -= 1
                player_strike(player, monster, out, ac)
            else:
                monster_strike(monster, player, out)
                if not player.is_alive():
                    break
            if monster.is_alive():
                player_strike(player, monster, out, ac)

    won = player.is_alive()
    if won and player.revived_this_fight:
        out.append({"type": "pic_kill"})
        ac["pic_kill"] = True
        player.revived_this_fight = False
    return won, out


def post_fight(player, level):
    """Rewards and upkeep after winning a fight."""
    out = []

    if player.pending_hp_multiplier > 1:
        if player.socks_sealed:
            out.append({"type": "book_hp_fizzled"})
        else:
            player.max_hp = int(player.max_hp * player.pending_hp_multiplier)
            out.append({"type": "book_hp_applied", "max_hp": player.max_hp})
        player.pending_hp_multiplier = 1

    # Money. Track 4 stage 4 "doubles income": it pays everything above
    # again, (DRONE_INCOME_MULTIPLIER - 1) more times.
    player.money += WIN_MONEY
    stages = player.drone.stages
    if stages[3] >= 1:
        player.money += player.drone.atk
    if stages[3] >= 2:
        player.money += DRONE_T4_MONEY[0]
    if stages[3] >= 3:
        player.money += DRONE_T4_MONEY[1]
    if stages[3] >= 4:
        player.money += (DRONE_INCOME_MULTIPLIER - 1) * (
            WIN_MONEY + player.drone.atk + DRONE_T4_MONEY[0] + DRONE_T4_MONEY[1])

    # Drone healing (track 3): the stages add up, and stage 4 "doubles" the
    # total by healing it again, (DRONE_HEAL_MULTIPLIER - 1) more times.
    heals = DRONE_HEALS + [(DRONE_HEAL_MULTIPLIER - 1) * sum(DRONE_HEALS)]
    for threshold in range(1, len(heals) + 1):
        if stages[2] >= threshold:
            player.hp = min(player.hp + heals[threshold - 1], player.max_hp)

    if player.relic == "blessed" and level % BLESSED_EVERY == 0:
        if not player.socks_sealed:
            player.max_hp += BLESSED_MAX_HP
        player.hp = player.max_hp

    # Elixir hangover: extra SPD wears off after each fight following a drink.
    remaining = []
    for timer in player.elixir_timers:
        timer -= 1
        player.extra_spd -= ELIXIR_SPD_DECAY
        if timer > 0:
            remaining.append(timer)
    player.elixir_timers = remaining

    return out
