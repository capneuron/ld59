shader_type spatial;
render_mode specular_disabled, cull_disabled;

uniform float shadow_strength : hint_range(0.0, 1.0) = 0.3;

varying vec3 blade_color;

void vertex() {
	blade_color = COLOR.rgb;
}

void light() {
	DIFFUSE_LIGHT = blade_color * mix(1.0 - shadow_strength, 1.0, ATTENUATION);
}
