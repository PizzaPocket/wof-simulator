extends RefCounted
## Root-fixed soft appendages: restrained idle flow and damped turn follow-through.
var skeleton: Skeleton3D
var chains: Array[Dictionary] = []
var elapsed := 0.0
var previous_yaw := 0.0
var initialized := false

func setup(rig: Skeleton3D, source: Array) -> void:
	skeleton=rig
	for entry in source:
		var bones:Array[int]=[]
		var rests:Array[Quaternion]=[]
		for name in entry.bones:
			var index:=rig.find_bone(name)
			bones.append(index)
			rests.append(rig.get_bone_rest(index).basis.orthonormalized().get_rotation_quaternion())
		chains.append({"bones":bones,"rests":rests,"side":entry.side,"angle":Vector3.ZERO,"velocity":Vector3.ZERO})

func reset() -> void:
	initialized=false
	for chain in chains:
		chain.angle=Vector3.ZERO;chain.velocity=Vector3.ZERO
		for index in chain.bones:skeleton.reset_bone_pose(index)

func update(delta:float, body:CharacterBody3D) -> void:
	if delta<=0 or not skeleton:return
	var dt:=minf(delta,.033)
	elapsed+=dt
	var head:=skeleton.find_bone("head")
	var yaw:float=body.visual.rotation.y+skeleton.get_bone_global_pose(head).basis.get_euler().y
	var turn_rate:=clampf(angle_difference(previous_yaw,yaw)/dt,-2.5,2.5) if initialized else 0.0
	previous_yaw=yaw;initialized=true
	var speed:=minf(Vector2(body.velocity.x,body.velocity.z).length(),18.0)
	for chain in chains:
		var phase:=0.0 if chain.side=="L" else 1.25
		var target:=Vector3.ZERO
		for i in range(3):
			var amplitude:float=[.007,.016,.029][i]
			target[i]=sin(elapsed*.86+phase-float(i)*.34)*amplitude-clampf(turn_rate*.018,-.045,.045)*(float(i)+1)/3.0
			var stiffness:float=lerpf(42.,24.,float(i)/2.)
			chain.velocity[i]+=((target[i]-chain.angle[i])*stiffness-2.*sqrt(stiffness)*.92*chain.velocity[i])*dt
			chain.angle[i]+=chain.velocity[i]*dt
			var pitch:float=sin(elapsed*.67+phase-float(i)*.42)*amplitude*.42-speed*.00055*(float(i)+1)/3.
			skeleton.set_bone_pose_rotation(chain.bones[i],chain.rests[i]*Quaternion(Vector3.FORWARD,chain.angle[i])*Quaternion(Vector3.RIGHT,pitch))
