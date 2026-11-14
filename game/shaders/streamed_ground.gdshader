shader_type spatial;
render_mode cull_disabled;
uniform sampler2D coverage : filter_nearest, repeat_disable;
uniform bool background = false;
void fragment() {
    if (background && texture(coverage, UV).r > 0.5) discard;
    ALBEDO = COLOR.rgb;
    ROUGHNESS = 1.0;
}
