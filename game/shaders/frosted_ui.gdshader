shader_type canvas_item;
// Frosted glass for HUD cards over the 3D scene: the scene behind is blurred and washed with a
// white tint, so the card stays readable without being a solid block. The shape and the soft
// edge come from the StyleBoxFlat drawn with this material; its shadow (low alpha) is left alone.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 6.0) = 2.6;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.64);

vec3 blurred(vec2 uv, vec2 px) {
	vec3 sum = vec3(0.0);
	float total = 0.0;
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			float weight = 1.0 / (1.0 + float(i * i + j * j));
			sum += textureLod(screen_texture, uv + vec2(float(i), float(j)) * px * 3.0, blur_lod).rgb * weight;
			total += weight;
		}
	}
	return sum / total;
}

void fragment() {
	vec4 base = COLOR;
	float body = smoothstep(0.5, 0.9, base.a);
	vec3 frosted = mix(blurred(SCREEN_UV, SCREEN_PIXEL_SIZE), tint.rgb, tint.a);
	COLOR = vec4(mix(base.rgb, frosted, body), base.a);
}
