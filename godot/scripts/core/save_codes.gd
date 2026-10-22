class_name SaveCodes
extends RefCounted
## Python section 3: SAVE. Format (unchanged from the original):
## value = runs<<13 | highest<<8 | ach_bits, base-61 encoded (alphabet has no capital I),
## always exactly 5 characters. Codes are interchangeable with the Python build.

const SAVE_ALPHABET := "0123456789ABCDEFGHJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"


static func save_code(profile: ProfileState) -> String:
	var bits := 0
	for key in Content.ACH_BIT_ORDER:
		bits = (bits << 1) | (1 if profile.ac[key] else 0)

	# load_code() rejects runs > 1024; cap here so a long-lived save can't self-corrupt.
	var runs := mini(profile.runs, 1024)
	var value := (((runs << 5) | profile.highest) << 8) | bits

	var code := ""
	if value == 0:
		code = SAVE_ALPHABET[0]
	else:
		while value > 0:
			code = SAVE_ALPHABET[value % 61] + code
			@warning_ignore("integer_division")
			value = value / 61

	return code.lpad(5, SAVE_ALPHABET[0])


## Decode a save code into profile. Returns {"ok": bool, "message": String}.
static func load_code(profile: ProfileState, code: String) -> Dictionary:
	if code.length() != 5:
		return {"ok": false, "message": "Invalid save code."}
	for i in code.length():
		if SAVE_ALPHABET.find(code[i]) == -1:
			return {"ok": false, "message": "Invalid save code."}

	var value := 0
	for i in code.length():
		value = value * 61 + SAVE_ALPHABET.find(code[i])

	var bits := value & 0xFF
	value >>= 8
	var highest := value & 0b11111
	value >>= 5
	var runs := value

	if runs > 1024 or highest > 30:
		return {"ok": false, "message": "Corrupted save code."}

	profile.runs = runs
	profile.highest = highest
	for offset in Content.ACH_BIT_ORDER.size():
		profile.ac[Content.ACH_BIT_ORDER[offset]] = bool((bits >> (7 - offset)) & 1)

	return {"ok": true, "message": "\nSave loaded successfully.\nRuns: %d   Highest lv. beaten: %d\n" % [runs, highest]}
