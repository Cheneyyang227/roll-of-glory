"""Render the exported GLB for a quick material sanity check."""

from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "assets/models/dark_wood/medieval_dice_v2.glb"
OUTPUT = ROOT.parent / "art/previews/dark_wood.png"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(MODEL))

dice = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
for obj in dice:
    obj.rotation_euler = (0.20, -0.28, 0.45)

bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.55))
plane = bpy.context.object
mat = bpy.data.materials.new("Preview tabletop")
mat.diffuse_color = (0.045, 0.022, 0.012, 1.0)
mat.roughness = 0.9
plane.data.materials.append(mat)

bpy.ops.object.light_add(type="AREA", location=(-3.0, -4.0, 5.0))
key = bpy.context.object
key.data.energy = 750
key.data.shape = "DISK"
key.data.size = 4.0

bpy.ops.object.light_add(type="AREA", location=(3.0, 2.0, 2.5))
fill = bpy.context.object
fill.data.energy = 240
fill.data.color = (1.0, 0.58, 0.30)
fill.data.size = 3.0

bpy.ops.object.camera_add(location=(3.0, -4.2, 2.8))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.lens = 62
bpy.context.scene.camera = camera

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 768
scene.render.resolution_y = 768
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(OUTPUT)
scene.render.film_transparent = False
scene.world.color = (0.012, 0.008, 0.006)
bpy.ops.render.render(write_still=True)
print(f"Rendered {OUTPUT}")
