shader_type canvas_item;

// Set once per frame from Base._process() (Input.is_key_pressed(KEY_SHIFT) +
// get_global_mouse_position()) via RenderingServer.global_shader_parameter_set -
// global uniforms so every occluder sprite wearing this shader reacts without
// any of them needing their own per-frame script wiring. xray_radius is set
// once (a const) rather than every frame.
global uniform vec2 xray_center;
global uniform float xray_radius;
global uniform float xray_active;

varying vec2 world_pos;

void vertex() {
	// MODEL_MATRIX transforms local VERTEX into the same global 2D coordinate
	// space Node2D.global_position/get_global_mouse_position() use, so
	// world_pos lines up directly with xray_center without any extra
	// conversion in GDScript.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	if (xray_active > 0.5) {
		float dist = distance(world_pos, xray_center);
		// Soft edge rather than a hard-cut circle - starts fading at 60% of
		// the radius, fully faded by the radius itself.
		float reveal = 1.0 - smoothstep(xray_radius * 0.6, xray_radius, dist);
		// Faded, not fully invisible (20% opacity) - the occluder should
		// still read as "there," just not blocking the view.
		float alpha_mult = mix(1.0, 0.2, reveal);
		tex_color.a *= alpha_mult;
	}
	COLOR = tex_color;
}
