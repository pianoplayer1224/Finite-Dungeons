shader_type canvas_item;
// "Greyed out": greyscale and faded. Locked relics/artefacts on the main menu (UIKit.greyed).

uniform float fade : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(g), c.a * fade);
}
