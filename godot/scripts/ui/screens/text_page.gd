extends Control
## How to play: the Python's print_intro() text, verbatim, on a scrolling parchment page.
## First launch continues to the save-code question. (Credits have their own screen.)

var args := {}

@onready var _title: Label = %Title
@onready var _note: Label = %Note
@onready var _text: RichTextLabel = %Text
@onready var _back: Button = %Back


func _ready() -> void:
	_title.text = "How to play"
	if UIKit.phone:   # the full width: longer lines, less scrolling
		var panel: Control = $Panel
		panel.offset_left = 32
		panel.offset_right = -32
		panel.offset_top = 24
		panel.offset_bottom = -24
	if UIKit.touch:
		_note.text = "In this version you tap a shop item to buy it."
	else:
		_note.text = "In this version you click a shop item to buy it — or type its number, like the original."
	_text.text = UIKit.bb_escape("\n".join(Content.INTRO).strip_edges())
	if args.get("first", false):
		_back.text = "Continue"
	_back.pressed.connect(_on_back)
	_back.grab_focus.call_deferred(true)


## Content clear of a phone's camera cutout (App.safe_inset; see UIKit.keep_clear).
func keep_clear(inset: Vector2) -> void:
	UIKit.keep_clear($Panel, inset)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()


func _on_back() -> void:
	if args.get("first", false):
		args["first"] = false
		await SaveCodeDialog.open(true)
		GameState.first_launch = false
		GameState.save_profile()
	App.instance.go_to("main_menu")
