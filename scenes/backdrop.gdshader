shader_type canvas_item;
// Dim, grimy back room behind the machine: a warm pool of light from above,
// dark corners, dusty pixel grain and slow-moving scanlines.

uniform vec3 base = vec3(0.07, 0.045, 0.045);
uniform vec3 glow = vec3(0.32, 0.12, 0.08);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5, 0.18));
	vec3 col = mix(glow, base, smoothstep(0.0, 0.75, d));
	// Chunky grain.
	vec2 cell = floor(FRAGCOORD.xy / 6.0);
	col += (hash(cell + floor(TIME * 6.0)) - 0.5) * 0.025;
	// Scanlines.
	col *= 0.92 + 0.08 * sin(FRAGCOORD.y * 0.8 + TIME * 2.0);
	// Vignette.
	col *= 1.0 - 0.55 * smoothstep(0.35, 0.95, distance(uv, vec2(0.5)));
	COLOR = vec4(col, 1.0);
}
