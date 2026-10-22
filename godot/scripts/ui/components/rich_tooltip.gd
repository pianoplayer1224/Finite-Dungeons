extends Control
## Put on a control by UIKit.rich_tooltip() (any Control: an icon, a gear row): its tooltip_text is
## drawn as BBCode, e.g. a relic description with the name in bold. Godot's own tooltip is a plain
## Label; this one is laid out like it (one line per text line, the TooltipLabel font and colour).
## In touch mode (UIKit.touch: no hover) a tap shows the text in a bubble instead (App.show_info).

var _press_at := Vector2.INF


func _get_tooltip(_at_position: Vector2) -> String:
	return "" if UIKit.touch else tooltip_text


func _make_custom_tooltip(for_text: String) -> Object:
	return UIKit.tooltip_label(self, for_text)


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton  # a touch arrives as an emulated mouse click
	if not UIKit.touch or click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# Global positions: a list scrolled by the finger moves this control along with it.
	if click.pressed:
		_press_at = click.global_position
	elif _press_at.distance_to(click.global_position) <= UIKit.TAP_SLOP:
		_press_at = Vector2.INF
		App.instance.show_info(self, tooltip_text)
		accept_event()
