"""Build a six-face royal iron die, bake its shaders and export a game asset."""
from pathlib import Path
from math import pi, cos, sin
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/models/black_iron'
SOURCE = ROOT.parent / 'art/blender/black_iron'
BAKED = SOURCE / 'baked_textures'
PREVIEW = ROOT.parent / 'art/previews/black_iron_royal.png'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(exist_ok=True)
BAKED.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def material(name, dark, light, metal):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    n, links = m.node_tree.nodes, m.node_tree.links
    p = next(x for x in n if x.type == 'BSDF_PRINCIPLED')
    p.inputs['Metallic'].default_value = metal
    p.inputs['Roughness'].default_value = .43
    noise = n.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 95
    noise.inputs['Detail'].default_value = 3
    ramp = n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color = (*dark, 1)
    ramp.color_ramp.elements[1].color = (*light, 1)
    links.new(noise.outputs['Fac'], ramp.inputs[0])
    links.new(ramp.outputs['Color'], p.inputs['Base Color'])
    bump = n.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value = .22
    bump.inputs['Distance'].default_value = .007
    links.new(noise.outputs['Fac'], bump.inputs['Height'])
    links.new(bump.outputs[0], p.inputs['Normal'])
    return m

iron = material('Blackened forged iron', (.014,.018,.023), (.075,.082,.09), .8)
gold = material('Antique gold', (.20,.09,.018), (.62,.38,.10), .85)

def active(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

bpy.ops.mesh.primitive_cube_add(size=1)
body = bpy.context.object
body.name = 'Royal iron shell'
body.data.materials.append(iron)
bevel = body.modifiers.new('Rounded worn edges', 'BEVEL')
bevel.width = .075
bevel.segments = 5
bpy.ops.object.modifier_apply(modifier=bevel.name)

# Blender Z-up converts to Godot Y-up: match DiceActor3D.FACE_NORMALS.
faces = {1:(1,0,0), 2:(0,-1,0), 3:(0,0,-1), 4:(0,0,1), 5:(0,1,0), 6:(-1,0,0)}
layouts = {1:[(0,0)],2:[(-1,-1),(1,1)],3:[(-1,-1),(0,0),(1,1)],
           4:[(-1,-1),(-1,1),(1,-1),(1,1)],
           5:[(-1,-1),(-1,1),(0,0),(1,-1),(1,1)],
           6:[(-1,-1),(-1,0),(-1,1),(1,-1),(1,0),(1,1)]}

def curve(name, coords, radius, mat, cyclic=False):
    data = bpy.data.curves.new(name, 'CURVE')
    data.dimensions = '3D'
    data.bevel_depth = radius
    data.bevel_resolution = 2
    s = data.splines.new('POLY')
    s.points.add(len(coords)-1)
    for p, co in zip(s.points, coords): p.co = (*co,1)
    s.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(mat)
    return obj

for value, direction in faces.items():
    normal = Vector(direction)
    u = Vector((0,1,0)) if abs(normal.x)>.5 else Vector((1,0,0))
    v = normal.cross(u)
    def point(x,y,z=.501): return u*x+v*y+normal*z
    for x,y in layouts[value]:
        center = point(x*.215,y*.215,.505)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=.086, location=center)
        cutter = bpy.context.object
        active(body)
        mod = body.modifiers.new('Recess', 'BOOLEAN')
        mod.operation = 'DIFFERENCE'
        mod.object = cutter
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=point(x*.215,y*.215,.445))
        pip = bpy.context.object
        pip.name = f'Face {value} recessed gold pip'
        pip.rotation_euler = normal.to_track_quat('Z','Y').to_euler()
        pip.scale = (.063,.063,.012)
        pip.data.materials.append(gold)
    border=[]
    for cx,cy,a in [(.365,.365,0),(-.365,.365,90),(-.365,-.365,180),(.365,-.365,270)]:
        for i in range(9):
            t=(a+i*90/8)*pi/180
            border.append(point(cx+.042*cos(t),cy+.042*sin(t)))
    curve(f'Face {value} gold border',border,.005,gold,True)
    for sx,sy in [(-1,-1),(-1,1),(1,-1),(1,1)]:
        # Three small raised almond leaves and a stem at each corner.
        base = Vector((sx*.35,sy*.35))
        inward=Vector((-sx,-sy)).normalized()
        side=Vector((-inward.y,inward.x))
        curve('Gold sprig stem',[point(*base),point(*(base+inward*.072))],.003,gold)
        for offset in [-.7,0,.7]:
            axis=(inward+side*offset).normalized()
            perp=Vector((-axis.y,axis.x))
            start=base+inward*.012
            verts=[point(*start,.504),point(*(start+axis*.06),.504)]
            for k in range(12):
                t=2*pi*k/12
                xy=start+axis*(.03+.03*cos(t))+perp*(.010*sin(t))
                verts.append(point(*xy,.508+.006*sin(pi*k/12)))
            tris=[(0,2+k,2+(k+1)%12) for k in range(12)]
            tris += [(1,2+(k+1)%12,2+k) for k in range(12)]
            mesh=bpy.data.meshes.new('Leaf')
            mesh.from_pydata(verts,[],tris)
            obj=bpy.data.objects.new('Gold leaf',mesh)
            bpy.context.collection.objects.link(obj)
            mesh.materials.append(gold)

bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active=body
bpy.ops.object.convert(target='MESH')
bpy.ops.object.join()
die=bpy.context.object
die.name='BlackIronDie'
bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
for p in die.data.polygons: p.use_smooth=True
weighted=die.modifiers.new('Face normals','WEIGHTED_NORMAL')
bpy.ops.object.modifier_apply(modifier=weighted.name)
if not die.data.uv_layers: die.data.uv_layers.new()
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(island_margin=.003)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'black_iron_royal.blend'))

scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=16
scene.render.bake.margin=8
materials=list({slot.material for slot in die.material_slots if slot.material})
textures={}
for kind in ['albedo','roughness','normal']:
    img=bpy.data.images.new('Royal_'+kind,2048,2048)
    img.colorspace_settings.name='sRGB' if kind=='albedo' else 'Non-Color'
    for m in materials:
        node=m.node_tree.nodes.new('ShaderNodeTexImage')
        node.image=img
        m.node_tree.nodes.active=node
    scene.render.bake.use_pass_direct=False
    scene.render.bake.use_pass_indirect=False
    scene.render.bake.use_pass_color=True
    bpy.ops.object.bake(type={'albedo':'DIFFUSE','roughness':'ROUGHNESS','normal':'NORMAL'}[kind])
    img.filepath_raw=str(BAKED/(kind+'.png'))
    img.file_format='PNG'
    img.save()
    textures[kind]=img
for m in materials:
    metal=.85 if m==gold else .8
    nodes=m.node_tree.nodes
    nodes.clear()
    p=nodes.new('ShaderNodeBsdfPrincipled')
    p.inputs['Metallic'].default_value=metal
    output=nodes.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(p.outputs[0],output.inputs['Surface'])
    for kind,img in textures.items():
        tex=nodes.new('ShaderNodeTexImage')
        tex.image=img
        if kind=='normal':
            bump=nodes.new('ShaderNodeNormalMap')
            m.node_tree.links.new(tex.outputs['Color'],bump.inputs['Color'])
            m.node_tree.links.new(bump.outputs[0],p.inputs['Normal'])
        else:
            m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color' if kind=='albedo' else 'Roughness'])
bpy.ops.export_scene.gltf(filepath=str(OUT/'black_iron_royal.glb'),export_format='GLB',use_selection=True)

# Preview the portable baked material, with a camera showing three faces.
bpy.ops.object.camera_add(location=(1.8,-2.5,1.9))
camera=bpy.context.object
camera.rotation_euler=(-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO'
camera.data.ortho_scale=1.85
scene.camera=camera
for loc,power,size in [((1,-3,4),500,3),((-3,-1,1),350,2),((2,2,3),600,2)]:
    bpy.ops.object.light_add(type='AREA',location=loc)
    light=bpy.context.object
    light.data.energy=power
    light.data.shape='DISK'
    light.data.size=size
    light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
scene.world.color=(.15,.15,.15)
scene.render.resolution_x=900
scene.render.resolution_y=900
scene.render.resolution_percentage=100
scene.render.filepath=str(PREVIEW)
scene.cycles.samples=32
bpy.ops.render.render(write_still=True)
print('BLACK IRON COMPLETE', len(die.data.polygons))
