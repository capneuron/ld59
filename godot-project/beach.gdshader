shader_type spatial;

render_mode cull_disabled;

uniform vec3 sand_color : source_color = vec3(0.82, 0.72, 0.55);
uniform vec3 wet_color : source_color = vec3(0.6, 0.52, 0.38);
uniform float wet_edge : hint_range(0.0, 1.0) = 0.85;
uniform float wet_width : hint_range(0.01, 0.3) = 0.12;
uniform float wave_speed : hint_range(0.1, 3.0) = 0.6;
uniform float fade_start : hint_range(0.0, 1.0) = 0.0;
uniform float fade_end : hint_range(0.0, 0.5) = 0.3;
uniform float grain_scale : hint_range(5.0, 80.0) = 30.0;
uniform float grain_strength : hint_range(0.0, 0.15) = 0.06;
uniform int color_levels : hint_range(2, 32) = 8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Sand grain noise
	float grain = hash(floor(UV * grain_scale)) * grain_strength;

	// Wet sand near one edge (animated tide)
	float dist = UV.y;
	float tide = sin(TIME * wave_speed) * 0.03;
	float wet = smoothstep(wet_edge - wet_width + tide, wet_edge + tide, dist);

	vec3 col = mix(sand_color, wet_color, wet) + grain;

	// Quantize to PS1 palette
	float quantizer = float(color_levels - 1);
	col = floor(col * quantizer + 0.5) / quantizer;

	// Opposite side fades to transparent
	ALPHA = smoothstep(fade_start, fade_end, dist);

	ALBEDO = col;
}
