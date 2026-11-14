"""Encode the shared final skull-frame mouth profiles into construction stations.
Run with Blender's Python; requires the ordinary Clay numpy/scipy dependencies.
"""
from pathlib import Path
import sys,json,re
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'cache/clay-python'),str(ROOT/'prototypes/clay/head')]
sys.argv=['remap_mouth_frame']
import build_head as H
import numpy as np
from scipy.optimize import root
from scipy.interpolate import PchipInterpolator
p=ROOT/'prototypes/clay/head/head_design.json';d=json.loads(p.read_text())
frame=d['mouth']['frame'];origin=np.array(frame['origin_yz']);forward=H.norm(frame['forward_yz']);up=H.norm(frame['up_yz'])
def source(yz):
 y,z=yz
 def residual(q):
  oz,oy=q;final=H.compact_head_points(np.array([[0,oy,float(H.snout_z(H.premaxilla_z(np.array(oz),np.array(oy))))]]))[0]
  return [final[1]-y,final[2]-z]
 sol=root(residual,[z+max(z-1.6,0)*.7,y-.05 if z>1.65 else y]);assert sol.success,(yz,sol.message)
 return [float(sol.x[0]),float(sol.x[1])]
def encode(points):
 values=[source(origin-forward*u+up*h) for u,h in points]
 values.sort(reverse=True)
 return [[round(z,7),round(y,7)] for z,y in values]
lip=d['lip_line']['frame_profile_uh'];profile=encode(lip)
# Preserve the back continuation hidden under the seam's terminal S return.
profile += [[1.39,1.72],[1.36,1.79]];profile.sort(reverse=True)
front_y=float(PchipInterpolator(*np.array(profile)[::-1].T)(2.017))
profile=[row for row in profile if row[0]<2.017];profile.insert(0,[2.017,front_y])
d['lip_line']['profile_zy']=profile
d['lip_line']['finished_profile_zy']=[[float((origin-forward*u+up*h)[1]),float((origin-forward*u+up*h)[0])] for u,h in lip]
d['lip_line']['why']='Shared skull-frame contour: a broad rounded first depression of 0.022 normal to the skull, a gentle middle rise, a shallower posterior depression, then the rear cheek hook and forward return into the ear. Both jaw beds and teeth use the same frame.'
us=np.linspace(-.12,.70,45)
b=d['lower_jaw']['bones']
b['resculpt_rim_zy']=encode([[float(u),frame['lower_rim_normal']] for u in us])
bottom=PchipInterpolator(*np.array(b['frame_underside_uh']).T)
b['resculpt_bottom_zy']=encode([[float(u),float(bottom(u))] for u in us])
d['mouth']['upper_bed_profile_zy']=encode([[float(u),frame['upper_bed_normal']] for u in us])
d['mouth']['floor_profile']=sorted(encode([[float(u),frame['lower_floor_normal']] for u in us]))
for name,h in [('upper',frame['upper_bed_normal']),('lower',frame['lower_floor_normal'])]:
 d['mouth'][name+'_u_source_z']=[[float(u),source(origin-forward*u+up*h)[0]] for u in us]
# Aim fire through the same skull-aligned oral corridor from its posterior end.
fire_points=[origin-forward*.35+up*(-.005),origin+forward*.04+up*(-.005)]
d['mouth']['fire_origin']=[[0.,*source(point)[::-1]] for point in fire_points]
stations=[]
for z in [1.43,1.56,1.72]:
    y=origin[0]+.75*(origin[1]-z)-.0125
    oz,oy=source([y,z]);stations.append([oz,oy,.11,.09])
d['mouth']['throat']['stations']=sorted(stations)
# The weld's lower edge follows the resculpted underside into the throat.
body_path=ROOT/'prototypes/clay/body/body_design.json';body=json.loads(body_path.read_text());cl=body['anatomy']['head_weld']['cheek_line']
allowance=body['anatomy']['head_weld'].get('lateral_fillet_forward',.055)
low=[]
for u in [.22,.28,.34,.40,.46]:
 z,y=source(origin-forward*u+up*float(bottom(u)))
 low.append([round(z-.012+allowance,6),round(y+.004,6)])
# Retain only the existing terminal cheek/ear S, below which the underside is fitted.
low=sorted(low,key=lambda row:row[1]);last=low[-1][1]
cl['zy']=[[1.78,1.10]]+low+[row for row in cl['zy'] if row[1]>max(last,1.59)]
def replace(text,key,value):
 start=text.index('"'+key+'":')+len(key)+3
 while text[start].isspace():start+=1
 _,length=json.JSONDecoder().raw_decode(text[start:]);v=json.dumps(value,indent=2);v=re.sub(r'\[\s*([-+\d.eE]+(?:,\s*[-+\d.eE]+)*)\s*\]',lambda m:'['+re.sub(r'\s+',' ',m[1])+']',v).replace('\n','\n  ')
 return text[:start]+v+text[start+length:]
text=p.read_text()
for key in ['mouth','lip_line','lower_jaw']:text=replace(text,key,d[key])
p.write_text(text);body_path.write_text(replace(body_path.read_text(),'cheek_line',cl))
print('Encoded skull-frame lip, palate, jaw rim, underside and floor; cheek lower weld',cl['zy'][:6])

# Runtime aim follows this same sculpt frame; keep its source in the posterior
# cavity while directing the jet through the middle of the opened gape.
(ROOT/'game/data/fire_breath.json').write_text(json.dumps({'up_model':[0.,*up.tolist()],'normal_slope':.25,'why':'Aim from the posterior mouth through the middle of the open gape using the sculpt skull frame.'},indent=2)+'\n')
