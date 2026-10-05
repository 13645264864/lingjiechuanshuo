shader_type canvas_item;
render_mode unshaded;

uniform vec4 neon_color : source_color = vec4(0.05, 1.0, 0.95, 1.0);

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	vec2 step_size = TEXTURE_PIXEL_SIZE * 3.0;
	float outer = 0.0;
	outer = max(outer, texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a);
	outer = max(outer, texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a);
	outer = max(outer, texture(TEXTURE, UV + vec2(0.0, step_size.y)).a);
	outer = max(outer, texture(TEXTURE, UV - vec2(0.0, step_size.y)).a);
	float rim = max(outer - alpha, 0.0);
	vec3 glow = mix(neon_color.rgb, vec3(1.0), rim * 0.7);
	COLOR = vec4(glow, (alpha * 0.42 + rim * 0.95) * COLOR.a);
}
