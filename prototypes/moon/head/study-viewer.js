(function(){
  window.mountStudy = async function(THREE, container, options) {
    const scene = new THREE.Scene(); scene.background = new THREE.Color(0x252a30);
    const renderer = new THREE.WebGLRenderer({antialias:true,preserveDrawingBuffer:true});
    renderer.setSize(container.clientWidth,container.clientHeight);renderer.setPixelRatio(1);
    renderer.outputEncoding=THREE.sRGBEncoding;container.appendChild(renderer.domElement);
    renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=.85;
    const aspect=container.clientWidth/container.clientHeight;
    const perspective=new THREE.PerspectiveCamera(20,aspect,.01,100);
    const orthographic=new THREE.OrthographicCamera(-1,1,1,-1,.01,100);
    let camera=perspective;
    scene.add(new THREE.HemisphereLight(0xdbe9ff,0x4c4035,.7));
    const key=new THREE.DirectionalLight(0xfff1dd,1.3);key.position.set(-3,4,5);scene.add(key);
    const fill=new THREE.DirectionalLight(0xb4d4ff,.45);fill.position.set(3,1,-4);scene.add(fill);
    const gltf=await new Promise((ok,no)=>new THREE.GLTFLoader().load(options.glbUrl,ok,undefined,no));
    if(options.foundation){
      let length=1.4007073898,centre=-.5;
      gltf.scene.traverse(o=>{if(o.userData.comparison_length){length=o.userData.comparison_length;centre=o.userData.comparison_centre;}});
      const box=new THREE.Box3().setFromObject(gltf.scene);
      const scale=length/(box.max.x-box.min.x);
      gltf.scene.scale.setScalar(scale);
      gltf.scene.position.x=centre-(box.min.x+box.max.x)*.5*scale;
    }
    scene.add(gltf.scene);
    const skull=gltf.scene.getObjectByName('SkullFrame');
    const jaw=gltf.scene.getObjectByName('JawFrame');
    const jawRest=jaw ? jaw.rotation.z : 0;
    const lids=[];gltf.scene.traverse(o=>{if(o.morphTargetDictionary&&o.morphTargetDictionary.Blink1!==undefined)lids.push(o);});
    const originals=new Map();const diagnostic={eye:new THREE.MeshBasicMaterial({color:0x176cff,side:THREE.DoubleSide}),upper:new THREE.MeshBasicMaterial({color:0xe64b43,side:THREE.DoubleSide}),lower:new THREE.MeshBasicMaterial({color:0xffdb30,side:THREE.DoubleSide}),skin:new THREE.MeshBasicMaterial({color:0xaaaaaa,side:THREE.DoubleSide})};
    Object.values(diagnostic).forEach(m=>m.morphTargets=true);
    gltf.scene.traverse(o=>{if(o.isMesh)originals.set(o,o.material);});
    const render=()=>renderer.render(scene,camera);
    let angle=0,currentPose={};
    const api={dispose(){gltf.scene.traverse(o=>{if(o.geometry)o.geometry.dispose();});for(const m of new Set(originals.values()))m.dispose();Object.values(diagnostic).forEach(m=>m.dispose());renderer.dispose();renderer.forceContextLoss();},raycast(x,y){const ray=new THREE.Raycaster();ray.setFromCamera(new THREE.Vector2(x/container.clientWidth*2-1,1-y/container.clientHeight*2),camera);return ray.intersectObjects(gltf.scene.children,true).slice(0,10).map(h=>({name:h.object.name,point:h.point.toArray()}));},shot(cam,target,pose,fov){
      currentPose=pose;
      angle=Math.atan2(cam[0]-target[0],cam[2]-target[2]);
      for(const [o,m] of originals)o.material=pose.debugEye?(o.name.startsWith('Seated')?diagnostic.eye:o.name.startsWith('Upper')?diagnostic.upper:o.name.startsWith('Lower')?diagnostic.lower:diagnostic.skin):m;
      camera=pose.orthographic||pose.ortho_scale?orthographic:perspective;
      if(camera===orthographic){
        const distance=new THREE.Vector3(...cam).distanceTo(new THREE.Vector3(...target));
        const height=pose.ortho_scale||2*distance*Math.tan((fov||20)*Math.PI/360);
        camera.left=-height*aspect/2;camera.right=height*aspect/2;camera.top=height/2;camera.bottom=-height/2;
      }
      camera.position.fromArray(cam);camera.fov=fov||20;camera.lookAt(new THREE.Vector3(...target));camera.updateProjectionMatrix();
      if(skull){
        skull.rotation.z=pose.reference ? (skull.userData.reference_tilt_degrees||34.11)*Math.PI/180 : 0;
        skull.position.set(pose.reference?.304:0,pose.reference?.028:0,0);
      }
      if(jaw)jaw.rotation.z=jawRest+(pose.jaw||0)*Math.PI/180;
      const q=Math.max(0,Math.min(1,pose.blink||0))*3;
      for(const lid of lids){
        const weights=q<1?[q,0,0]:q<2?[2-q,q-1,0]:[0,3-q,q-2];
        ['Blink1','Blink2','Blink3'].forEach((name,i)=>lid.morphTargetInfluences[lid.morphTargetDictionary[name]]=weights[i]);
      }
      if(!options.foundation)gltf.scene.scale.z=pose.width||1;
      render();
    }};
    api.shot([0,.1,5],[-.4,.0,0],{},20);
    if(options.interactive){
      let down=false,last=0;
      renderer.domElement.addEventListener('pointerdown',e=>{down=true;last=e.clientX;renderer.domElement.setPointerCapture(e.pointerId);});
      renderer.domElement.addEventListener('pointerup',()=>down=false);
      renderer.domElement.addEventListener('pointermove',e=>{if(!down)return;angle+=(e.clientX-last)*.008;last=e.clientX;api.shot([-.5+Math.sin(angle)*4,.25,Math.cos(angle)*4],[-.5,.0,0],currentPose,24);});
      renderer.domElement.addEventListener('wheel',e=>{e.preventDefault();camera.position.multiplyScalar(e.deltaY>0?1.08:.92);render();},{passive:false});
    }
    return api;
  };
  window.mountFoundation=(THREE,container,options)=>window.mountStudy(THREE,container,{...options,foundation:true});
})();
