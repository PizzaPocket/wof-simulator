// A restrained view-dependent structural-color approximation. No time cycling.
vec3 dragon_sheen(vec3 base, vec3 surface_normal, vec3 view_direction, float strength) {
	float angle = 1.0 - clamp(abs(dot(normalize(surface_normal), normalize(view_direction))), 0.0, 1.0);
	vec3 violet = vec3(0.39, 0.16, 0.68);
	vec3 teal = vec3(0.08, 0.61, 0.47);
	vec3 gold = vec3(0.76, 0.62, 0.20);
	vec3 film = mix(violet, teal, smoothstep(0.20, 0.68, angle));
	film = mix(film, gold, smoothstep(0.72, 0.98, angle) * 0.78);
	float brightness = max(dot(base, vec3(0.2126, 0.7152, 0.0722)), 0.045);
	vec3 reflected = film * brightness / max(dot(film, vec3(0.2126, 0.7152, 0.0722)), 0.10);
	return mix(base, reflected, strength * (0.30 + 0.70 * smoothstep(0.02, 0.94, angle)));
}
