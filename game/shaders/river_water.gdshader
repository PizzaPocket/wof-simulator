shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Opaque, texture-free ripples. No screen reads, extra meshes or reflection pass.
uniform vec3 water_color : source_color = vec3(0.27, 0.40, 0.32);
uniform vec3 sky_tint : source_color = vec3(0.60, 0.72, 0.72);
uniform float ripple_strength : hint_range(0.0, 0.4) = 0.025;
uniform float flow_speed : hint_range(0.0, 1.0) = 0.3;
uniform float marsh_enabled = 0.0;
uniform vec3 marsh_color : source_color = vec3(0.47, 0.52, 0.27);
uniform vec3 algae_color : source_color = vec3(0.61, 0.62, 0.31);
uniform vec3 silt_color : source_color = vec3(0.40, 0.42, 0.21);
uniform float shallow_depth_m = 0.45;
uniform float open_depth_m = 1.3;
varying vec2 water_position;
varying float bed_depth;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 cell=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);
}

void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	bed_depth=COLOR.r;
}

void fragment() {
	vec2 p = water_position;
	float t = TIME * flow_speed;
	vec2 d1 = vec2(0.38, 0.925);
	vec2 d2 = vec2(-0.71, 0.704);
	float drift1 = sin(dot(p, vec2(0.13, -0.09)) + t * 0.4);
	float drift2 = sin(dot(p, vec2(0.07, 0.11)) - t * 0.3);
	float a = dot(p, d1) * 2.1 - t * 2.4 + 5.0 * drift1;
	float b = dot(p, d2) * 3.7 - t * 1.6 + 4.0 * drift2;
	// Fade fine detail as pixels cover more water, avoiding distant shimmer.
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float fine = 1.0 - smoothstep(0.15, 1.2, footprint);
	float patches = 0.65 + 0.35 * drift2;
	float marsh=marsh_enabled*(1.0-smoothstep(shallow_depth_m,open_depth_m,bed_depth*7.0));
	vec2 slope = ripple_strength * mix(1.0,0.22,marsh) * fine * patches * (d1 * cos(a) + 0.25 * d2 * cos(b));
	vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	float grazing = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float variation = 0.008 * (drift1 + drift2) + fine * 0.008 * sin(a + 0.3 * sin(b));
	vec3 depth_color=mix(vec3(.25,.31,.18),vec3(.095,.18,.145),smoothstep(.01,.65,bed_depth));
	// Broad irregular mats and fine mottling, with silt between them. The
	// opaque shallow surface belongs to the sedge marsh, not the river channel.
	float mats=noise(p*.19+vec2(noise(p*.04),noise(p*.04+13.0))*2.6);
	float flecks=noise(p*2.7);
	float algae=smoothstep(.43,.70,mats+flecks*.14);
	vec3 stagnant=mix(silt_color,marsh_color,smoothstep(.15,.60,mats));
	stagnant=mix(stagnant,algae_color,algae*.65)*(0.95+flecks*.10);
	depth_color=mix(depth_color+vec3(variation),stagnant,marsh);
	ALBEDO = mix(depth_color, sky_tint, grazing * mix(0.15,0.025,marsh));
	ROUGHNESS = mix(0.48,0.88,marsh);
	SPECULAR = mix(0.35,0.12,marsh);
}
