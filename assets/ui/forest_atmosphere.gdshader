shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float edge = smoothstep(0.3, 1.35, length(centered));
	COLOR = vec4(0.015, 0.045, 0.035, edge * 0.30);
}
