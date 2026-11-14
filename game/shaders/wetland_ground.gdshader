shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying vec3 point;
void vertex(){ point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 float grain=sin(point.x*39.+sin(point.z*47.))*sin(point.y*57.+point.z*41.);
 float broad=sin(point.x*.9+sin(point.z*1.4))*sin(point.z*.8+point.y*2.);
 ALBEDO=pow(COLOR.rgb,vec3(2.2))*(.96+.035*broad+.018*grain);
 ROUGHNESS=.94; SPECULAR=.16;
}
