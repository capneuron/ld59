shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 5.0) = 2.0;
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.4);

void fragment() {
	vec2 ps = SCREEN_PIXEL_SIZE;
	vec4 col = vec4(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float w = exp(-float(x * x + y * y) / (2.0 * blur_amount * blur_amount));
			col += textureLod(SCREEN_TEXTURE, SCREEN_UV + vec2(float(x), float(y)) * ps * blur_amount, 0.0) * w;
			total += w;
		}
	}
	col /= total;
	COLOR = mix(col, tint_color, tint_color.a);
}
