shader_type spatial;
// Procedural mountain stone in world space: no texture tiling, strata bands, a snow line
// and a fine bump. Shared by the exterior and the caves.
uniform vec3 low_color : source_color = vec3(0.44, 0.52, 0.41);
uniform vec3 high_color : source_color = vec3(0.72, 0.74, 0.67);
uniform vec3 snow_color : source_color = vec3(0.93, 0.96, 0.98);
uniform float base_height = 500.0;
uniform float snow_line = 1550.0;
uniform float bump = 0.55;
uniform float gold_veins : hint_range(0.0, 1.0) = 0.0;
uniform vec3 gold_color : source_color = vec3(0.95, 0.72, 0.22);

varying vec3 wpos;
varying vec3 wnormal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p, int octaves) {
	float amplitude = 0.5;
	float total = 0.0;
	for (int i = 0; i < octaves; i++) {
		total += amplitude * vnoise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float broad = fbm(wpos * 0.012, 4);
	float fine = fbm(wpos * 0.45, 3);
	float strata = sin(wpos.y * 0.22 + broad * 7.0) * 0.5 + 0.5;
	float altitude = clamp((wpos.y - base_height) / 2200.0, 0.0, 1.0);
	vec3 rock = mix(low_color, high_color, clamp(broad * 1.2 + strata * 0.18 + altitude * 0.6, 0.0, 1.0));
	rock *= 0.82 + 0.36 * fine;
	float snow = smoothstep(snow_line - 120.0, snow_line + 140.0, wpos.y + broad * 260.0);
	snow *= smoothstep(0.30, 0.72, wnormal.y + 0.25 * broad);
	ALBEDO = mix(rock, snow_color, snow);
	ROUGHNESS = mix(0.96, 0.75, snow);
	// Optional veins of gold through carved stone.
	float vein = smoothstep(0.60, 0.65, fbm(wpos * vec3(0.07, 0.05, 0.07), 3)) * gold_veins;
	ALBEDO = mix(ALBEDO, gold_color, vein);
	ROUGHNESS = mix(ROUGHNESS, 0.35, vein);
	METALLIC = vein * 0.6;
	EMISSION = gold_color * vein * 0.12;
	float step_size = 0.3;
	float h0 = fbm(wpos * 1.6, 3);
	vec3 grad = vec3(fbm((wpos + vec3(step_size, 0, 0)) * 1.6, 3) - h0,
					 fbm((wpos + vec3(0, step_size, 0)) * 1.6, 3) - h0,
					 fbm((wpos + vec3(0, 0, step_size)) * 1.6, 3) - h0) / step_size;
	vec3 world_normal = normalize(wnormal - bump * (grad - dot(grad, wnormal) * wnormal));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
}
