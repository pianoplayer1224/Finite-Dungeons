class_name Entity
extends RefCounted
## Python section 2: Entity, the base class for player and monsters.
## Totals are methods, computed on read and never stored.

var max_hp: int
var hp: int
var atk: int
var df: int
var spd: int
var extra_atk := 0
var extra_df := 0
var extra_spd := 0


func _init(p_hp: int = 0, p_atk: int = 0, p_df: int = 0, p_spd: int = 0) -> void:
	max_hp = p_hp
	hp = p_hp
	atk = p_atk
	df = p_df
	spd = p_spd


func total_atk() -> int:
	return atk + extra_atk


func total_df() -> int:
	return df + extra_df


func total_spd() -> int:
	return spd + extra_spd


func is_alive() -> bool:
	return hp > 0


## Create monster stats based on level.
static func create_monster(level: int) -> Entity:
	var stat := level * Values.MONSTER_GROWTH
	return Entity.new(stat + Values.MONSTER_EXTRA_HP, stat, stat, stat)
