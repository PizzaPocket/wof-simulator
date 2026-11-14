"""Translate the original viewer's material rules into a Godot spatial shader.

Clay's pattern/color expressions stay verbatim. An optional Umber palette, iris
and scar variant is layered on the same material. Godot-specific changes are the
attribute inputs, material outputs, derivative normal, and renderer color space.
"""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
def generate():
    source=(ROOT/'prototypes/clay/head/head-viewer.js').read_text()
    helpers=source.split('const GLSL = `',1)[1].split('`;',1)[0]
    helpers=re.sub(r'    varying[^\n]*\n','',helpers)
    helpers=re.sub(r'    uniform[^\n]*\n','',helpers)
    fragment=source.split('          vec3 dark = srgb',1)[1].split('          #ifdef CLAY',1)[0]
    fragment='vec3 dark = srgb'+fragment
    fragment=fragment.replace('vec3 col = orange;', """if (umber_variant) {
              dark = srgb(vec3(83.0, 51.0, 38.0));
              line = srgb(vec3(47.0, 31.0, 24.0));
              orange = srgb(vec3(143.0, 94.0, 66.0));
              cream = srgb(vec3(189.0, 155.0, 114.0));
          }
          vec3 col = orange;""")
    fragment=fragment.replace('srgb(vec3(232.0, 128.0, 70.0))', '(umber_variant ? srgb(vec3(142.0, 99.0, 65.0)) : srgb(vec3(232.0, 128.0, 70.0)))')
    fragment=fragment.replace('srgb(vec3(246.0, 168.0, 106.0))', '(umber_variant ? srgb(vec3(183.0, 143.0, 98.0)) : srgb(vec3(246.0, 168.0, 106.0)))')
    prefix='''// Ported from prototypes/clay/head/head-viewer.js; regenerate with tools/port_clay_shader.py.
    shader_type spatial;
    render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
    uniform float neckScale = 2.0;
    uniform vec2 neckBlend = vec2(0.48, 0.75);
    uniform vec2 bodySpacing = vec2(0.065, 0.06);
    uniform vec2 limbSpacing = vec2(0.07, 0.075);
    uniform vec3 limbStart[6];
    uniform vec3 limbEnd[6];
    uniform float limbOffset[6];
    uniform bool clay_mode = false;
    uniform bool umber_variant = false;
    uniform bool bump_enabled = true;
    uniform float bump_depth = 0.003;
    varying vec3 vObj;
    varying float vPart;
    varying vec3 vAB;
    varying float modelScale;
    void vertex() {
        vPart = CUSTOM0.x;
        vAB = CUSTOM0.yzw;
        vObj = CUSTOM1.xyz;
        modelScale = length(MODEL_MATRIX[0].xyz);
    }
    '''
    suffix='''
        if (umber_variant) {
            if (isP(6.0) > 0.5) {
                vec3 eye_center=vec3(sign(vObj.x)*0.15214467,1.69209337,1.68664968);
                vec3 n=normalize(vObj-eye_center);
                // Both pupils aim partly forward, not straight out to each side.
                vec3 gaze=normalize(vec3(sign(vObj.x)*0.86,0.025,0.51));
                vec3 horizontal=normalize(cross(vec3(0.,1.,0.),gaze));
                vec3 vertical=normalize(cross(gaze,horizontal));
                vec2 q=vec2(dot(n,horizontal),dot(n,vertical));
                float front=step(0.0,dot(n,gaze));
                float iris=(1.-smoothstep(.48,.53,length(q)))*front;
                // Soft upright oval, neither a circular dot nor a narrow slit.
                float pupil=(1.-smoothstep(.92,1.06,length(q/vec2(.145,.285))))*front;
                col=srgb(vec3(230.,220.,196.));
                col=mix(col,srgb(vec3(193.,147.,65.)),iris);
                col=mix(col,vec3(.009,.007,.005),pupil);
                rough=.13;
            }
            // Rest-space scar follows the skinned roof across the top of the snout.
            float scar = (1.0 - smoothstep(0.007, 0.014, abs(vObj.z - 1.925 - vObj.x * 0.24)))
                * step(1.46, vObj.y) * (1.0 - smoothstep(0.12, 0.16, abs(vObj.x)))
                * max(isP(1.0), max(isP(10.0), isP(13.0)));
            col = mix(col, srgb(vec3(190.0, 150.0, 123.0)), scar * 0.92);
        }
        if (clay_mode) {
            col = srgb(vec3(190.0, 180.0, 170.0)); groove = 0.0; rough = 0.7;
        }
        // Forward+/Mobile shade in linear space; Compatibility shades in sRGB.
        // Convert the original linear palette exactly once for the active renderer.
        vec3 srgb_output = mix(col * 12.92, 1.055 * pow(max(col, vec3(0.0)), vec3(1.0/2.4)) - 0.055, step(vec3(0.0031308), col));
        ALBEDO = OUTPUT_IS_SRGB ? srgb_output : col;
        ROUGHNESS = rough;
        METALLIC = 0.0;
        SPECULAR = 0.5;
        if (!clay_mode && isP(25.0) > 0.5) {
            EMISSION = ALBEDO * 0.4;
        }
        if (bump_enabled && !clay_mode) {
            // Derivative surface gradient: same recessed-scale relief as the viewer.
            vec3 dx = dFdx(VERTEX), dy = dFdy(VERTEX);
            vec3 base_normal = normalize(NORMAL);
            vec3 r1 = cross(dy, base_normal), r2 = cross(base_normal, dx);
            float determinant = dot(dx, r1);
            float height = -groove * bump_depth * modelScale;
            vec3 gradient = sign(determinant) * (dFdx(height) * r1 + dFdy(height) * r2);
            vec3 perturbed = abs(determinant) * base_normal - gradient;
            if (dot(perturbed, perturbed) > 1e-16) NORMAL = normalize(perturbed);
        }
    }
    '''
    (ROOT/'game/shaders/clay.gdshader').write_text(prefix+helpers+'\nvoid fragment() {\n'+fragment+suffix)
    print('Ported original Clay material rules to game/shaders/clay.gdshader')


if __name__ == "__main__":
    generate()
