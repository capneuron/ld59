shader_type spatial;

render_mode cull_disabled;

uniform vec3 water_color : source_color = vec3(0.15, 0.35, 0.55);
uniform vec3 edge_color : source_color = vec3(0.6, 0.8, 0.9);
uniform float edge_width : hint_range(0.01, 0.5) = 0.15;
uniform float wave_speed : hint_range(0.1, 5.0) = 1.0;
uniform float wave_amount : hint_range(0.0, 0.1) = 0.02;
uniform float edge_foam_speed : hint_range(0.1, 3.0) = 0.8;
uniform int color_levels : hint_range(2, 32) = 8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	float wave = sin(VERTEX.x * 3.0 + TIME * wave_speed) + cos(VERTEX.z * 2.0 + TIME * wave_speed * 0.7);
	VERTEX.y += wave * wave_amount;
}

void fragment() {
	// Edge detection via UV distance from center
	vec2 centered = UV * 2.0 - 1.0;
	float dist = max(abs(centered.x), abs(centered.y));

	// Animated edge foam
	float foam_line = sin(dist * 40.0 - TIME * edge_foam_speed) * 0.5 + 0.5;
	float edge_mask = smoothstep(1.0 - edge_width, 1.0, dist);
	float foam = edge_mask * step(0.6, foam_line);

	// Water color with subtle variation
	float noise = hash(floor(UV * 20.0) + floor(TIME * 2.0)) * 0.1;
	vec3 col = mix(water_color, water_color * 1.2, noise);

	// Blend edge foam
	col = mix(col, edge_color, foam * 0.7);
	col = mix(col, edge_color * 0.8, edge_mask * 0.3);

	// Quantize to match PS1 look
	float quantizer = float(color_levels - 1);
	col = floor(col * quantizer + 0.5) / quantizer;

	ALBEDO = col;
	ALPHA = 1.0 - smoothstep(0.95, 1.0, dist) * 0.3;
}
