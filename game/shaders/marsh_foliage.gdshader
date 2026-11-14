shader_type spatial;
render_mode cull_disabled,diffuse_burley;
varying vec3 leaf_color;
void vertex(){
 leaf_color=pow(COLOR.rgb,vec3(2.2));
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 float green=smoothstep(.01,.07,COLOR.g-COLOR.r);
 float flexible=clamp(VERTEX.y,0.,1.)*green;
 float wind=(sin(TIME*.65+p.x*.13+p.z*.09)+.35*sin(TIME*1.1+p.z*.4))*.08;
 VERTEX.x+=wind*flexible;VERTEX.z+=wind*.42*flexible;
}
void fragment(){ALBEDO=leaf_color;ROUGHNESS=.94;SPECULAR=.12;}
