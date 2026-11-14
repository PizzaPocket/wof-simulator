shader_type spatial;
render_mode unshaded, cull_disabled;
// Coverage comes from the same baked heightfield as the ground. Discarding land
// avoids far-distance depth fighting between a world-sized plane and low terrain.
uniform sampler2D ocean_mask : filter_nearest, repeat_disable;
uniform vec2 terrain_size;
uniform vec4 sea_color : source_color = vec4(0.14, 0.33, 0.38, 1.0);
varying vec2 map_uv;
void vertex() {
    map_uv = VERTEX.xz / terrain_size + vec2(0.5);
}
void fragment() {
    if (all(greaterThanEqual(map_uv, vec2(0.0))) && all(lessThanEqual(map_uv, vec2(1.0)))) {
        if (texture(ocean_mask, map_uv).r < 0.5) discard;
    }
    ALBEDO = sea_color.rgb;
}
