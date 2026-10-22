class_name ProfileState
extends RefCounted
## Python section 2: Profile. Persistent progress: run count, highest level beaten, achievements.

var runs := 0
var highest := 0
var ac := {}


func _init() -> void:
	for key in Content.ACH_BIT_ORDER:
		ac[key] = false
