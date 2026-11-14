shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.3, 0.2, 0.12, 1.0);
uniform bool is_leather = false;
varying vec3 rest_point;
void vertex() { rest_point = VERTEX; }
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float grain(vec3 p) {
    vec3 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f);
    return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
               mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void fragment() {
    float broad = grain(rest_point * 75.0);
    float fine = grain(rest_point * (is_leather ? 1700.0 : 2600.0));
    ALBEDO = base_color.rgb * (0.94 + broad * 0.08 + fine * 0.035);
    ROUGHNESS = is_leather ? 0.75 + fine * 0.16 : 0.94;
    SPECULAR = is_leather ? 0.28 : 0.16;
    // Submillimetre grain is secondary to the sculpted folds and stitched seams.
    float height = fine * (is_leather ? 0.00010 : 0.000045);
    vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
    vec3 n = normalize(NORMAL), rx = cross(dy,n), ry = cross(n,dx);
    float det = dot(dx,rx);
    vec3 bump = abs(det)*n - sign(det)*(dFdx(height)*rx + dFdy(height)*ry);
    if (dot(bump,bump)>1e-20) NORMAL = normalize(bump);
}
