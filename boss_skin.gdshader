shader_type canvas_item;
render_mode unshaded;

uniform float rage : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
varying vec4 sprite_tint;

void vertex() {
	sprite_tint = COLOR;
}

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	vec2 pixel = TEXTURE_PIXEL_SIZE * 0.65;
	float edge = max(texture(TEXTURE, UV + vec2(pixel.x, 0.0)).a,
		texture(TEXTURE, UV - vec2(pixel.x, 0.0)).a);
	edge = max(edge, texture(TEXTURE, UV + vec2(0.0, pixel.y)).a);
	edge = max(edge, texture(TEXTURE, UV - vec2(0.0, pixel.y)).a);
	float outline = max(edge - texel.a, 0.0);
	float glow = max(texture(TEXTURE, UV + vec2(pixel.x * 3.0, 0.0)).a,
		texture(TEXTURE, UV - vec2(pixel.x * 3.0, 0.0)).a);
	glow = max(glow, texture(TEXTURE, UV + vec2(0.0, pixel.y * 3.0)).a);
	glow = max(glow, texture(TEXTURE, UV - vec2(0.0, pixel.y * 3.0)).a);
	glow = max(glow - texel.a, 0.0) * 0.14;
	vec3 color = min(texel.rgb * 1.35 + vec3(0.015, 0.025, 0.04), vec3(1.0));
	vec3 energy = mix(vec3(0.68, 0.23, 1.0), vec3(1.0, 0.15, 0.58), rage);
	float sword = smoothstep(0.15, 0.55, texel.r + texel.b - texel.g * 2.0);
	color += sword * energy * (0.15 + charge * 0.35);
	color = mix(color, vec3(1.0, 0.92, 0.72), hit_flash * 0.8);
	float pulse = 0.75 + sin(TIME * 5.0) * 0.15;
	color = mix(color, energy * 1.2, outline);
	color = mix(color, energy, glow);
	COLOR = vec4(color, max(texel.a, max(outline * pulse, glow))) * sprite_tint;
}
