class_name SpriteAnim
extends TextureRect
## A TextureRect that plays one row of a sprite sheet (the slime placeholder, the hero).
## play() switches sheets, e.g. idle -> hit -> idle, or die (holds the last frame). A one-shot
## calls its `p_then` when it ends; playing anything else first drops that call.
## With pixel_scale set it draws the frame itself at that whole-number scale, `pivot` (a point in
## the frame, before flip_h) on the control's bottom centre, instead of stretching it to fit.

const SLIME_IDLE := preload("res://assets/sprites/slime_idle2.png")
const SLIME_HIT := preload("res://assets/sprites/slime_hit.png")
const SLIME_DIE := preload("res://assets/sprites/slime_die.png")
const HERO := preload("res://assets/sprites/hero.png")

## Slime sheets: 80x72 cells, 7 colour rows (pink, red, orange, blue, green, tan, grey); the
## slime itself only fills SLIME_CROP of each cell. Levels pick a row via SLIME_BANDS.
const SLIME_CELL := Vector2i(80, 72)
const SLIME_CROP := Rect2i(12, 22, 44, 27)
## Bottom centre of the slime in SLIME_CROP (the bottom row is empty).
const SLIME_PIVOT := Vector2(22, 26)
## Hero sheet, cut from the artist's "Sprite Sheet Hero.png" by tools/make_hero_sheet.py: 56x36
## cells, one row per animation ([row, frames]), the hero facing right with the feet on the bottom
## row; HERO_PIVOT is the point under the hero's head in every cell.
const HERO_CELL := Vector2i(56, 36)
const HERO_PIVOT := Vector2(16, 36)
const HERO_ANIMS := {
	"idle": [0, 16], "walk": [1, 4], "jump": [2, 4], "fall": [3, 3], "attack1": [4, 5],
	"attack2": [5, 5], "air_attack": [6, 5], "attack3": [7, 8], "attack4": [8, 7], "death": [9, 7],
}

var sheet: Texture2D
var cell := Vector2i(32, 32)
var row := 0
var fps := 6.0
var looping := true
var crop := Rect2i()  # part of each cell to show; empty = the whole cell
var pixel_scale := 0:  # 0: stretch the frame to fit; n: draw it n times its size, at `pivot`
	set(value):
		pixel_scale = value
		texture = null if value > 0 else _atlas
		queue_redraw()
var pivot := Vector2():
	set(value):
		pivot = value
		queue_redraw()

var _frames := 1
var _frame := 0
var _time := 0.0
var _atlas := AtlasTexture.new()
var _then := Callable()


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture = _atlas


## Start playing a sheet row from its first frame. p_frames: the row's frame count (0: the
## whole width of the sheet). p_then: called when a one-shot ends (e.g. back to idle).
func play(p_sheet: Texture2D, p_cell: Vector2i, p_fps: float, p_loop := true, p_row := -1,
		p_crop := Rect2i(), p_frames := 0, p_then := Callable()) -> void:
	sheet = p_sheet
	cell = p_cell
	crop = p_crop
	fps = p_fps
	looping = p_loop
	if p_row >= 0:
		row = p_row
	_frames = p_frames if p_frames > 0 else maxi(1, sheet.get_width() / cell.x)
	_frame = 0
	_time = 0.0
	_then = p_then
	_atlas.atlas = sheet
	_show()


## Play one of HERO_ANIMS.
func play_hero(anim: String, p_fps: float, p_loop := true, p_then := Callable()) -> void:
	var a: Array = HERO_ANIMS[anim]
	play(HERO, HERO_CELL, p_fps, p_loop, a[0], Rect2i(), a[1], p_then)


## Monster colour per level band (owner's palette): white L1-5, brown L6-10, green L11-15,
## blue L16-20, yellow L21-25, red L26-29, purple for the level 30 boss. Each band is the
## nearest sheet row plus a tint for self_modulate where the sheet's colour is off (grey ->
## white, tan -> brown, orange -> yellow, pink -> purple); channels above 1 brighten. Battle's
## hit flashes tween `modulate`, which multiplies with this and leaves it intact.
const SLIME_BANDS := [
	[6, Color(1.45, 1.4, 1.43)],   # white
	[5, Color(0.8, 0.62, 0.5)],    # brown
	[4, Color(1, 1, 1)],           # green
	[3, Color(1, 1, 1)],           # blue
	[2, Color(1.12, 1.45, 1.0)],   # yellow
	[1, Color(1, 1, 1)],           # red
	[0, Color(0.85, 0.8, 1.35)],   # purple (boss)
]


## Index into SLIME_BANDS: one band per 5 levels, the last one only for the boss.
static func slime_band(level: int) -> int:
	if level >= Values.FINAL_LEVEL:
		return SLIME_BANDS.size() - 1
	@warning_ignore("integer_division")
	return mini((level - 1) / 5, SLIME_BANDS.size() - 2)


static func slime_row(level: int) -> int:
	return SLIME_BANDS[slime_band(level)][0]


static func slime_tint(level: int) -> Color:
	return SLIME_BANDS[slime_band(level)][1]


func _process(delta: float) -> void:
	if sheet == null or (_frames <= 1 and looping):
		return
	_time += delta
	var step := 1.0 / fps
	while _time >= step:
		_time -= step
		if _frame + 1 >= _frames:
			if looping:
				_frame = 0
			else:
				# Stop before calling back: a callback that starts the next animation (back to
				# idle) turns processing on again, and must not be switched off after it.
				set_process(false)
				var then := _then
				_then = Callable()
				if then.is_valid():
					then.call()
				return
		else:
			_frame += 1
		_show()


func _show() -> void:
	if crop.size == Vector2i.ZERO:
		_atlas.region = Rect2(_frame * cell.x, row * cell.y, cell.x, cell.y)
	else:
		_atlas.region = Rect2(_frame * cell.x + crop.position.x, row * cell.y + crop.position.y, crop.size.x, crop.size.y)
	if pixel_scale > 0:
		queue_redraw()
	set_process(true)


## Where pixel mode draws the current frame (the whole cell), in this control's coordinates;
## flip_h mirrors it inside the same rect.
func sprite_rect() -> Rect2:
	var s := float(pixel_scale)
	var src := _atlas.region
	var px := src.size.x - pivot.x if flip_h else pivot.x
	return Rect2(roundf(size.x / 2.0 - px * s), roundf(size.y - pivot.y * s), src.size.x * s, src.size.y * s)


func _draw() -> void:
	if pixel_scale <= 0 or sheet == null:
		return
	var dest := sprite_rect()
	if flip_h:
		dest.size.x = -dest.size.x  # a negative width draws it mirrored in place, as TextureRect does
	draw_texture_rect_region(sheet, dest, _atlas.region)
