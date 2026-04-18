shader_type canvas_item;

uniform sampler2D custom_texture;
uniform float cutoff: hint_range(0, 1) = 1;
uniform float smoothness: hint_range(0, 1) = 0.1;
uniform vec3 color = vec3(0, 0, 0);
uniform bool inverted = false;
uniform bool linear_fade = true;
uniform sampler2D background_texture;
uniform bool use_background_texture = false;

void fragment() {
	float alpha;
	if (!linear_fade) {
		float value = texture(custom_texture, UV).r;
		if (inverted) {
			value = 1.0 - value;
		}
		alpha = smoothstep(cutoff, cutoff + smoothness, value * (1.0 - smoothness) + smoothness);
	} else {
		alpha = 1.0 - cutoff;
	}

	if (use_background_texture) {
		vec4 bg = texture(background_texture, UV);
		COLOR = vec4(bg.rgb, alpha * bg.a);
	} else {
		COLOR = vec4(color.rgb, alpha);
	}
}