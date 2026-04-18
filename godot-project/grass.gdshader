shader_type spatial;
render_mode ambient_light_disabled, specular_disabled;

uniform vec3 ground_color = vec3(0.2, 0.451, 0.102);
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	//ALBEDO = vec3(0.0);
}

void light() {
	DIFFUSE_LIGHT = ground_color * mix(1.0 - shadow_strength, 1.0, ATTENUATION);
}
