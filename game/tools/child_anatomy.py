"""Age-correct MakeHuman anatomy and independent surface measurements.

Local requested facial edits are separate from the body reference fit. Age interpolation follows
MakeHuman apps/human.py (_setAgeVals, setAgeYears), pinned with the source assets.
Circumferences are intersections of the skin with anatomical section planes.
"""
from pathlib import Path
import numpy as np
from collections import defaultdict

def target(path, count):
    result=np.zeros((count,3))
    for line in Path(path).read_text().splitlines():
        if line and not line.startswith('#'):
            t=line.split();result[int(t[0])]=list(map(float,t[1:4]))
    return result

def age_weights(years):
    if not 1<=years<=10:raise ValueError("This child asset pipeline supports ages 1–10")
    age=(years-1)/48
    baby=max(0,1-age/0.1875)
    young=max(0,(age-.1875)*3.2)
    child=max(0,min(1,age/.1875)-young)
    return {'baby':baby,'child':child,'young':young}

def age_body(base, source, years, weight=0, muscle=0):
    result=base.copy();weights=age_weights(years)
    for stage,amount in weights.items():
        if amount==0:continue
        result+=amount*target(source/f'caucasian-male-{stage}.target',len(base))
        for muscle_stage,muscle_weight in [('minmuscle',1-muscle),('averagemuscle',muscle)]:
            for weight_stage,weight_weight in [('minweight',weight),('averageweight',1-weight)]:
                if muscle_weight*weight_weight:
                    result+=amount*muscle_weight*weight_weight*target(source/f'universal-male-{stage}-{muscle_stage}-{weight_stage}.target',len(base))
    return result

def normalize(points, body_ids, height):
    bottom=points[body_ids,1].min();scale=height/(points[body_ids,1].max()-bottom)
    result=points.copy();result[:,1]-=bottom;result*=scale
    return result,bottom,scale

def group_center(points, faces, groups, name):
    ids=sorted(set(i for fi in groups[name] for i in faces[fi]))
    return points[ids].mean(axis=0)

def triangles(faces, indices):
    return np.array([(f[0],f[i],f[i+1]) for fi in indices for f in [faces[fi]] for i in range(1,len(f)-1)],dtype=np.int32)

def section(points, tris, center, normal, limit=.3):
    normal=np.array(normal,float);normal/=np.linalg.norm(normal)
    center=np.array(center,float);dist=(points-center)@normal
    d=dist[tris];selected=tris[(d.min(axis=1)<0)&(d.max(axis=1)>0)]
    nodes={};segments=[]
    def key(v):return tuple(np.round(v,6))
    for tri in selected:
        hits=[]
        for a,b in [(tri[0],tri[1]),(tri[1],tri[2]),(tri[2],tri[0])]:
            if dist[a]*dist[b]<0:
                t=dist[a]/(dist[a]-dist[b]);hits.append(points[a]+t*(points[b]-points[a]))
        if len(hits)!=2:continue
        if np.linalg.norm((hits[0]+hits[1])*.5-center)>limit:continue
        a,b=map(key,hits);nodes[a]=hits[0];nodes[b]=hits[1];segments.append((a,b))
    adjacent=defaultdict(list)
    for a,b in segments:adjacent[a].append(b);adjacent[b].append(a)
    seen=set();loops=[]
    for first in adjacent:
        if first in seen:continue
        todo=[first];component=set()
        while todo:
            n=todo.pop()
            if n in component:continue
            component.add(n);seen.add(n);todo.extend(adjacent[n])
        if len(component)<6:continue
        verts=np.array([nodes[n] for n in component])
        lengths=[np.linalg.norm(nodes[a]-nodes[b]) for a,b in segments if a in component and b in component]
        loops.append({'circumference':float(sum(lengths)),'width':float(np.ptp(verts[:,0])),'depth':float(np.ptp(verts[:,2])),
                      'center':verts.mean(axis=0),'points':verts,'closed':all(len(adjacent[n])==2 for n in component)})
    if not loops:raise ValueError('No anatomical cross section at '+str(center))
    return min(loops,key=lambda x:np.linalg.norm(x['center']-center))

def measurements(points, tris, faces, groups):
    joint=lambda name:group_center(points,faces,groups,'joint-'+name)
    shoulder=joint('l-shoulder');elbow=joint('l-elbow');wrist=joint('l-hand')
    hip=joint('l-upper-leg');knee=joint('l-knee');ankle=joint('l-ankle')
    h=points[:,1].max()
    upper=section(points,tris,(shoulder+elbow)*.5,elbow-shoulder,limit=.13*h/1.35)
    fore=section(points,tris,elbow+(wrist-elbow)*.35,wrist-elbow,limit=.10*h/1.35)
    calf=section(points,tris,knee+(ankle-knee)*.35,ankle-knee,limit=.10*h/1.35)
    chest=section(points,tris,[0,shoulder[1]-.10*h/1.35,.025*h/1.35],[0,1,0],limit=.20*h/1.35)
    waist_options=[section(points,tris,[0,y,.025*h/1.35],[0,1,0],limit=.20*h/1.35) for y in np.linspace(hip[1]+.12*h/1.35,shoulder[1]-.16*h/1.35,5)]
    waist=min(waist_options,key=lambda v:v['circumference'])
    pelvis=section(points,tris,[0,hip[1]+.02*h/1.35,.025*h/1.35],[0,1,0],limit=.22*h/1.35)
    return {'upper_arm_girth_m':upper['circumference'],'forearm_girth_m':fore['circumference'],'calf_girth_m':calf['circumference'],
            'waist_girth_m':waist['circumference'],'hip_girth_m':pelvis['circumference'],
            'chest_width_m':chest['width'],'chest_depth_m':chest['depth'],
            'shoulder_joint_span_m':float(shoulder[0]*2),
            'upper_arm_joint_length_m':float(np.linalg.norm(elbow-shoulder)),
            'forearm_joint_length_m':float(np.linalg.norm(wrist-elbow)),
            'femur_joint_length_m':float(np.linalg.norm(knee-hip)),
            'tibia_joint_length_m':float(np.linalg.norm(ankle-knee)),
            'neck_base_height_m':float(joint('neck')[1]),'hip_joint_height_m':float(hip[1]),
            'knee_joint_height_m':float(knee[1]),'ankle_joint_height_m':float(ankle[1])}

def fit_girths(points, tris, faces, groups, weights, targets):
    """Fit measured transverse skin sections; never move bone centers or lengths.

    Anatomical source weights define the limb domains, including smooth joint
    transitions. Each fitted parameter is traceable to a measured circumference
    or torso section. The accepted head, hands and feet are not freeform warped.
    """
    initial=points.copy();body_mask=np.zeros(len(points));body_mask[list(set(i for fi in groups['body'] for i in faces[fi]))]=1
    joint=lambda n:group_center(initial,faces,groups,'joint-'+n)
    source=measurements(initial,tris,faces,groups)
    controls=[]
    for role,bones,start,end,key in [
        ('upper_arm',['upperarm01','upperarm02'],'shoulder','elbow','upper_arm_girth_m'),
        ('forearm',['lowerarm01','lowerarm02'],'elbow','hand','forearm_girth_m'),
        ('calf',['lowerleg01','lowerleg02'],'knee','ankle','calf_girth_m')]:
        for side,prefix in [('L','l-'),('R','r-')]:
            a=joint(prefix+start);b=joint(prefix+end);d=b-a
            t=np.clip(((initial-a)*d).sum(axis=1)/np.dot(d,d),0,1)
            center=a+t[:,None]*d
            influence=np.zeros(len(points))
            for bone in bones:
                for i,w in weights.get(bone+'.'+side,[]):influence[i]+=w
            controls.append((key,center,np.clip(influence,0,1)*body_mask))
    torso=np.zeros(len(points))
    for bone in ['spine01','spine02','spine03','spine04','spine05','pelvis.L','pelvis.R']:
        for i,w in weights.get(bone,[]):torso[i]+=w
    torso=np.clip(torso,0,1)*body_mask
    hip_y=joint('l-upper-leg')[1]+.02
    chest_y=joint('l-shoulder')[1]-.10*points[:,1].max()/1.35
    waist_ys=np.linspace(hip_y+.10,chest_y-.06,7)
    waist_y=min(waist_ys,key=lambda y:section(initial,tris,[0,y,.025],[0,1,0],.24)['circumference'])
    if not hip_y<waist_y<chest_y:raise ValueError('Torso station ordering is not anatomical')
    # Scale parameters are solved from surface measurements, not visual guesses.
    scales={k:1.0 for k in targets}
    def apply():
        p=initial.copy()
        for key,center,influence in controls:
            radial=initial-center
            p+=(scales[key]-1)*radial*influence[:,None]
        y=initial[:,1]
        hip_s=scales['hip_girth_m'];waist_s=scales['waist_girth_m']
        stations=[hip_y-.075,hip_y,waist_y,chest_y,chest_y+.14]
        sx=np.interp(y,stations,[1,hip_s,waist_s,scales['chest_width_m'],1])
        sz=np.interp(y,stations,[1,hip_s,waist_s,scales['chest_depth_m'],1])
        p[:,0]+=(sx-1)*initial[:,0]*torso
        p[:,2]+=(sz-1)*(initial[:,2]-.025)*torso
        return p
    history=[]
    for iteration in range(9):
        p=apply();m=measurements(p,tris,faces,groups)
        errors={k:m[k]/v-1 for k,v in targets.items()}
        history.append(errors)
        if max(abs(e) for e in errors.values())<.025:break
        for k in scales:
            scales[k]*=(targets[k]/m[k])**.80
            scales[k]=float(np.clip(scales[k],.5,1.5))
    p=apply();actual=measurements(p,tris,faces,groups)
    errors={k:actual[k]/v-1 for k,v in targets.items()}
    if max(abs(e) for e in errors.values())>.06:raise ValueError('Measured body fit did not converge: '+str(errors))
    return p,{'unfitted':source,'actual':actual,'targets':targets,'relative_errors':errors,'scales':scales,'iterations':len(history)}

def fit_lengths(points, source, scale, targets):
    """Use the source measurement landmarks and authored morphs, including joints.

    8274 is the acromial landmark, 10037 the olecranon, 10040/10548
    the elbow/wrist landmarks in MakeHuman's pinned measurement plugin.
    These external lengths are distinct from shoulder/elbow joint distances.
    """
    p=points.copy();report={}
    for key,stem,measure in [
        ('biacromial_breadth_m','shoulder-dist',lambda q:float(abs(q[8274,0])*2)),
        ('upper_arm_external_length_m','upperarm-length',lambda q:float(np.linalg.norm(q[8274]-q[10037]))),
        ('forearm_external_length_m','lowerarm-length',lambda q:float(np.linalg.norm(q[10040]-q[10548])))]:
        wanted=targets[key];before=measure(p)
        direction='incr' if wanted>before else 'decr'
        delta=target(source/f'measure-{stem}-{direction}.target',len(p))*scale
        lo,hi=0.,3.
        for _ in range(24):
            mid=(lo+hi)/2;value=measure(p+mid*delta)
            if (value<wanted)==(direction=='incr'):lo=mid
            else:hi=mid
        amount=(lo+hi)/2;p+=amount*delta
        report[key]={'before':before,'target':wanted,'after':measure(p),'source_morph':stem+'-'+direction,'amount':amount}
    return p,report

def plain_torso(points, faces, groups, weights):
    """Remove muscular relief from the torso while keeping its overall envelope.

    A low-order convex front/back surface cannot reproduce paired pectoral
    lobes, nipples, abdominal grooves or scapular ridges. Only skin vertices
    weighted to the trunk are faired; joint helper landmarks and the head stay
    untouched. This is the deliberately plain form requested for the children.
    """
    p=points.copy();body=np.zeros(len(p),bool)
    body[list(set(i for fi in groups['body'] for i in faces[fi]))]=True
    influence=np.zeros(len(p))
    for bone in ['spine01','spine02','spine03','spine04','spine05']:
        for i,w in weights.get(bone,[]):influence[i]+=w
    j=lambda n:group_center(p,faces,groups,'joint-'+n)
    unit=p[:,1].max()/1.35;low=j('l-upper-leg')[1]+.11*unit;high=j('neck')[1]-.025*unit
    middle=j('l-shoulder')[1]-.10*unit
    y=(p[:,1]-middle)/unit;x=p[:,0]/unit
    features=np.column_stack([np.ones(len(p)),y,y*y,x*x,x*x*y])
    change=np.zeros(len(p))
    def smooth(t):
        t=np.clip(t,0,1);return t*t*(3-2*t)
    blend=smooth((p[:,1]-low)/(.035*unit))*smooth((high-p[:,1])/(.035*unit))
    blend*=smooth((influence-.35)/.50)*body
    for front in [True,False]:
        side=(p[:,2]>.025*unit) if front else (p[:,2]<=.025*unit)
        sample=body&side&(influence>.85)&(p[:,1]>low)&(p[:,1]<high)
        coeff=np.linalg.lstsq(features[sample],p[sample,2],rcond=None)[0]
        # A convex transverse section has one continuous front/back plane.
        curvature=coeff[3]+coeff[4]*y
        curvature=np.minimum(curvature,-.15/unit) if front else np.maximum(curvature,.15/unit)
        z=coeff[0]+coeff[1]*y+coeff[2]*y*y+curvature*x*x
        amount=blend*side
        change+=(z-p[:,2])*amount
    p[:,2]+=change
    return p,{'method':'convex low-order trunk fairing','max_relief_removed_m':float(abs(change).max()),'vertices_faired':int(np.count_nonzero(abs(change)>1e-6))}

def child_silhouette(points,source,scale,rig,weights,style):
    """Art direction requested after the population-reference pass.

    Reduce deltoid fullness with authored source morphs, slope the clavicles,
    and reduce hands with the source hand morph while carrying the finger rig.
    """
    p=points.copy();body={i for name,items in weights.items() for i,w in items}
    for side in ['l','r']:
        p+=style['shoulder_muscle_reduction']*scale*target(source/f'{side}-upperarm-shoulder-muscle-decr.target',len(p))
    selected=lambda n:n.startswith(('clavicle.','shoulder01.','upperarm','lowerarm','wrist.','finger'))
    influence=np.zeros(len(p))
    for name,items in weights.items():
        if selected(name):
            for i,w in items:influence[i]+=w
    drop=style['shoulder_drop_m']*p[:,1].max()/1.35
    p[:,1]-=np.clip(influence,0,1)*drop
    helper=set()
    for name,definition in rig['bones'].items():
        if selected(name) and not name.startswith('clavicle.'):
            for key in ['head','tail']:helper.update(rig['joints'][definition[key]])
    for i in helper-body:p[i,1]-=drop
    def hand_length(q):
        a=q[rig['joints'][rig['bones']['wrist.L']['head']]].mean(axis=0)
        b=q[rig['joints'][rig['bones']['finger3-3.L']['tail']]].mean(axis=0)
        return float(np.linalg.norm(b-a))
    # Replace the raised deltoid dome with a continuous neck-to-arm slope.
    # Apply the same envelope to shoulder helpers, keeping the fitted girdle
    # inside the new form. The head and distal arm are outside this domain.
    neck=p[rig['joints'][rig['bones']['neck01']['head']]].mean(axis=0)[1]
    unit=p[:,1].max()/1.35
    region=(abs(p[:,0])>.055*unit)&(abs(p[:,0])<.30*unit)&(p[:,1]<neck-.010*unit)&(p[:,1]>neck-.20*unit)
    ceiling=neck-.015*unit-np.maximum(0,abs(p[:,0])-.045*unit)*style['shoulder_slope']
    p[region,1]=np.minimum(p[region,1],ceiling[region])
    before=hand_length(p);desired=before*style['hand_length_scale']
    delta=sum((scale*target(source/f'{side}-hand-scale-decr.target',len(p)) for side in ['l','r']))
    lo,hi=0.,1.
    for _ in range(24):
        mid=(lo+hi)/2
        if hand_length(p+mid*delta)>desired:lo=mid
        else:hi=mid
    amount=(lo+hi)/2;p+=amount*delta
    return p,{'shoulder_drop_m':float(drop),'shoulder_muscle_reduction':style['shoulder_muscle_reduction'],
             'hand_length_before_m':before,'hand_length_after_m':hand_length(p),'hand_morph_amount':amount,
             'why':'Gentler shoulder slope, less deltoid mass and smaller hands requested by the user.'}


def nose_shape(points, settings, height):
    """A small, local nasal edit; eyes, lips, jaw and other facial planes stay fixed."""
    if not settings:
        return points, None
    p=points.copy();unit=height/1.35
    def smooth(t):
        t=np.clip(t,0,1);return t*t*(3-2*t)
    a,b,c,d=np.array(settings['height_band_m'])*unit
    lateral0,lateral1=np.array(settings['lateral_fade_m'])*unit
    front0,front1=np.array(settings['front_fade_m'])*unit
    weight=smooth((p[:,1]-a)/(b-a))*(1-smooth((p[:,1]-c)/(d-c)))
    weight*=1-smooth((abs(p[:,0])-lateral0)/(lateral1-lateral0))
    weight*=smooth((p[:,2]-front0)/(front1-front0))
    p[:,0]*=1+(settings['width_scale']-1)*weight
    tip=np.exp(-((points[:,1]-settings['tip_height_m']*unit)/(.011*unit))**2)
    p[:,2]-=settings['projection_reduction_m']*unit*weight*tip
    return p,{'max_displacement_m':float(np.linalg.norm(p-points,axis=1).max()),
              'changed_vertices':int(np.count_nonzero(weight>1e-8)), 'settings':settings}
