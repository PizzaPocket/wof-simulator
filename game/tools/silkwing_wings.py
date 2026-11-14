"""SilkWing-specific wing architecture traced from the official side sheet.

Forewing: three close distal arches + long trailing banana lobe.
Hindwing: one long arch + a short basal support around one broad oval lobe.
Arm and support boundaries are shared sampled curves with matching weights.
"""
import math
import numpy as np
from scipy.interpolate import CubicSpline


def bezier(a,b,c,d,t):
    return (1-t)**3*np.array(a)+3*(1-t)**2*t*np.array(b)+3*(1-t)*t*t*np.array(c)+t**3*np.array(d)


def rest_transforms(A,rig,amount=1.):
    """Exact a=1 pose frames used by tribe_dragon_motion.gd, in model space."""
    from mathutils import Vector
    root=np.array(rig['root']);elbow=np.array(rig['elbow']);wrist=np.array(rig['wrist'])
    norm=A.SK.norm
    def align(a,b):return np.array(Vector(norm(a)).rotation_difference(Vector(norm(b))).to_matrix())
    blend=amount*amount*(3-2*amount)
    upper_goal=norm(elbow-root)*(1-blend)+norm(rig['fold_upper'])*blend
    fore_goal=norm(wrist-elbow)*(1-blend)+norm(rig['fold_fore'])*blend
    upper=align(elbow-root,upper_goal)
    posed_elbow=root+upper@(elbow-root)
    fore=align(upper@(wrist-elbow),fore_goal)@upper
    posed_wrist=posed_elbow+fore@(wrist-elbow)
    source=norm(np.array(rig['digits'][0]['tip'])-wrist)
    sn=norm(np.array([0.,1.,0.])-source*source[1])
    target=norm(rig['rest_fan_leading']);hint=np.array(rig['rest_fan_normal'])
    tn=norm(hint-target*np.dot(target,hint))
    rotation=np.column_stack([target,tn,np.cross(target,tn)])@np.column_stack([source,sn,np.cross(source,sn)]).T
    from mathutils import Matrix,Quaternion
    rotation=np.array(Quaternion().slerp(Matrix(rotation.tolist()).to_quaternion(),blend).to_matrix())
    def affine(r,a,b):
        result=np.eye(4);result[:3,:3]=r;result[:3,3]=b-r@a;return result
    transforms={rig['root_bone']:affine(upper,root,root),rig['elbow_bone']:affine(fore,elbow,posed_elbow)}
    fan=affine(rotation,wrist,posed_wrist)
    for digit in rig['digits']:
        matrix=transforms[rig['root_bone']] if digit.get('attachment')=='proximal' else fan
        transforms[digit['first']]=matrix;transforms[digit['second']]=matrix
    return transforms,fan,posed_wrist,tn


def reference_controls(A,rig,digit,yz):
    _,fan,wrist,normal=rest_transforms(A,rig)
    controls=[]
    for y,z in yz:
        x=wrist[0]-(normal[1]*(y-wrist[1])+normal[2]*(z-wrist[2]))/normal[0]
        controls.append(np.linalg.solve(fan[:3,:3],np.array([x,y,z])-fan[:3,3]))
    return controls


def build(A,M):
    membrane=A.material('SilkWing blue violet membrane',A.PROFILE['wing'],.45,.08)
    support=A.material('SilkWing curved support keratin',A.PROFILE['dorsal'],.51)
    for rig in M.WING_RIG.values():
        root=np.array(rig['root']);wrist=np.array(rig['wrist']);digits=rig['digits'];side=1 if rig['side']=='L' else -1
        body_end=root+np.array(rig['web_end_offset'])
        M.wing_arm_skin(rig)
        frames={}
        for amount in [0.,.25,.5,.75,1.]:
            transforms,fan,pw,normal=rest_transforms(A,rig,amount)
            outline=np.array([pw]+[(fan[:3,:3]@np.array(d['tip'])+fan[:3,3]) if d['attachment']=='wrist' else (transforms[rig['root_bone']][:3,:3]@np.array(d['tip'])+transforms[rig['root_bone']][:3,3]) for d in digits]+[body_end])
            params=np.r_[0,np.cumsum(np.linalg.norm(np.diff(outline,axis=0),axis=1))]
            frames[amount]={'transforms':transforms,'fan':fan,'edge':CubicSpline(params,outline,bc_type='natural'),'params':params,'amount':amount}
        active=frames[0.]
        standing=frames[1.]
        standing_fan=standing['fan']
        def matrix(weights):return sum((weight*active['transforms'].get(bone,np.eye(4)) for bone,weight in weights),np.zeros((4,4)))
        def posed(p,weights):
            transform=matrix(weights);return transform[:3,:3]@np.array(p)+transform[:3,3]
        def unposed(p,weights):
            transform=matrix(weights);return np.linalg.solve(transform[:3,:3],p-transform[:3,3])
        def ray(digit,t):return posed(M.wing_ray(wrist,digit,t),M.finger_weights(digit,t))
        rig['construction']='Flat flight surface with four boundary-preserving cloth pose corrections to the traced standing curves'
        def lobe_controls(yz,a,b):
            # Transport the approved standing outline in the wing's own frame.
            # Only the body-side endpoint correction changes as the arm opens;
            # there is no separate, oversized flight outline.
            last=digits[-1] if rig['bank']=='fore' else digits[0]
            sa=standing_fan[:3,:3]@np.array(last['tip'])+standing_fan[:3,3]
            if rig['bank']=='fore':sb=body_end
            else:
                st=standing['transforms'][rig['root_bone']]
                sb=st[:3,:3]@np.array(digits[1]['tip'])+st[:3,3]
            current_fan=active['fan']
            end_local=np.linalg.solve(standing_fan[:3,:3],sb-standing_fan[:3,3])
            end_current=current_fan[:3,:3]@end_local+current_fan[:3,3]
            controls=[]
            for f,(y,z) in zip([1/3,2/3],yz):
                reference=np.array([sa[0]*(1-f)+sb[0]*f,y,z])
                local=np.linalg.solve(standing_fan[:3,:3],reference-standing_fan[:3,3])
                controls.append(current_fan[:3,:3]@local+current_fan[:3,3]+f*(b-end_current))
            return controls
        def arm_sample(u,part='full'):
            q=u if part=='full' else (.5*u if part=='distal' else .5+.5*u)
            value=q*22;i=min(21,int(value));f=value-i
            a,b=rig['arm_attachment'][i:i+2]
            return np.array(a['point'])*(1-f)+np.array(b['point'])*f,M.blend_weights(a['weights'],b['weights'],f)
        def grid(name,point):
            nonlocal active
            vertices=[];weights=[];faces=[]
            active=frames[0.]
            for i in range(46):
                for j in range(23):
                    t=i/45;u=j/22;p,w=point(t,u,j)
                    w=sorted([(bone,weight) for bone,weight in w if weight>.0001],key=lambda item:-item[1])[:4]
                    total=sum(weight for _,weight in w);w=[(bone,weight/total) for bone,weight in w]
                    vertices.append(p);weights.append(w)
                    if i and j:
                        a=(i-1)*23+j-1;b=i*23+j-1;faces.append([a,a+1,b+1,b])
            ob=A.mesh(name,vertices,faces,membrane,weights,colors=M.wing_colors(vertices,wrist,rig))
            ob.shape_key_add(name='Basis')
            for stage,amount in enumerate([.25,.5,.75,1.]):
                active=frames[amount];key=ob.shape_key_add(name='LobePose'+str(stage+1))
                for i in range(46):
                    for j in range(23):
                        index=i*23+j;p,_=point(i/45,j/22,j)
                        target=unposed(p,weights[index])
                        assert np.isfinite(target).all() and np.max(np.abs(target))<8,'Unstable cloth pose correction'
                        key.data[index].co=A.B(target)
                key.value=0
            active=frames[0.]
        for panel in range(len(digits)-1):
            left,right=digits[panel],digits[panel+1]
            different_origins=np.linalg.norm(np.array(left['origin'])-right['origin'])>.01
            def panel_point(t,u,j):
                a=ray(left,t);b=ray(right,t);p=a*(1-u)+b*u
                distal_a=ray(left,1);distal_b=ray(right,1)
                if rig['bank']=='hind':
                    controls=lobe_controls(rig['rest_main_lobe_yz'],distal_a,distal_b)
                    distal=bezier(distal_a,*controls,distal_b,u)
                else:
                    params=active['params'];distal=active['edge'](params[panel+1]*(1-u)+params[panel+2]*u)
                p+=(distal-(distal_a*(1-u)+distal_b*u))*t**3
                weights=M.blend_weights(M.finger_weights(left,t),M.finger_weights(right,t),u)
                if different_origins:
                    arm_point,arm_weights=arm_sample(u,'distal')
                    p+=(posed(arm_point,arm_weights)-(ray(left,0)*(1-u)+ray(right,0)*u))*(1-t)
                    release=np.clip(t/.25,0,1);release=release*release*(3-2*release)
                    if j not in [0,22]:weights=M.blend_weights(arm_weights,weights,release)
                return p,weights
            grid('SilkWingMembrane '+rig['bank'],panel_point)
        last=digits[-1]
        def web_point(t,u,j):
            a=ray(last,t);body=root*(1-t)+body_end*t;p=a*(1-u)+body*u
            # The unsupported-looking balloon during a power stroke came from
            # weighting half of the broad lobe to the stationary chest. Keep
            # the lobe on its support; blend to the body only in the inner web.
            body_blend=np.clip((u-.70)/.30,0,1);body_blend=body_blend*body_blend*(3-2*body_blend)
            weights=M.blend_weights(M.finger_weights(last,t),[('chest',1-t),(rig['web_end_bone'],t)],body_blend)
            arm_point,arm_weights=arm_sample(u,'full' if last['attachment']=='wrist' else 'proximal')
            p+=(posed(arm_point,arm_weights)-(ray(last,0)*(1-u)+root*u))*(1-t)
            release=np.clip(t/.25,0,1);release=release*release*(3-2*release)
            if j not in [0,22]:weights=M.blend_weights(arm_weights,weights,release)
            if last['attachment']=='wrist':
                start=ray(last,1);controls=lobe_controls(rig['rest_trailing_lobe_yz'],start,body_end)
                distal=bezier(start,*controls,body_end,u)
                p+=(distal-(start*(1-u)+body_end*u))*t**3
            return p,weights
        grid('Moon continuous axillary membrane '+rig['bank'],web_point)
        for digit in digits:
            path=[M.wing_ray(wrist,digit,t) for t in np.linspace(0,1,64)]
            proximal=digit['attachment']=='proximal'
            radii=np.interp(np.linspace(0,1,64),[0,.25,.65,1],[.027,.023,.014,.001] if proximal else [.023,.020,.012,.003])
            ob=A.tube('SilkWing basal hooked support' if proximal else 'SilkWing graceful distal arch',path,radii,support,digit['first'],sides=12)
            ob.vertex_groups.clear()
            for i,t in enumerate(np.linspace(0,1,64)):
                for bone,weight in M.finger_weights(digit,t):
                    if weight>1e-6:
                        group=ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
                        group.add(list(range(i*12,i*12+12)),float(weight),'REPLACE')
        claw=A.spline([wrist,wrist+[0,.045,.01],wrist+[0,.065,.05],wrist+[0,.04,.07]],32)
        A.tube('SilkWing arm bend hook',claw,np.interp(np.linspace(0,1,32),[0,1/3,2/3,1],[.019,.015,.008,.001]),support,rig['elbow_bone'],sides=12)
