shader_type canvas_item;
render_mode unshaded;

uniform float strength : hint_range(0.0, 1.0) = 0.5;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec2 step_size = TEXTURE_PIXEL_SIZE * 1.8;
	float outside = max(texture(TEXTURE, UV + vec2(step_size.x, 0)).a,
		texture(TEXTURE, UV - vec2(step_size.x, 0)).a);
	outside = max(outside, texture(TEXTURE, UV + vec2(0, step_size.y)).a);
	outside = max(outside, texture(TEXTURE, UV - vec2(0, step_size.y)).a);
	float glow = max(outside - texel.a, 0.0);
	COLOR = vec4(mix(vec3(1.0, 0.67, 0.08), vec3(1.0, 0.97, 0.65), texel.r),
		max(texel.a * strength, glow * strength)) * sprite_tint;
}
