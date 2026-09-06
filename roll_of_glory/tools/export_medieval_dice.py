"""Prepare the authored medieval die for realtime use and export it as GLB.

Run this script by opening the source .blend in Blender background mode and
passing this file through --python. The source file is never overwritten.
"""

from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_GLB = PROJECT_ROOT / "assets/models/dark_wood/medieval_dice_v2.glb"


def is_dice_part(obj: bpy.types.Object) -> bool:
    return (
        obj.type in {"MESH", "CURVE"}
        and not obj.name.startswith("Studio •")
    )


dice_parts = [obj for obj in bpy.context.scene.objects if is_dice_part(obj)]
if not dice_parts:
    raise RuntimeError("No dice geometry was found in the source scene")

# Work only on the in-memory copy loaded by the background Blender process.
bpy.ops.object.select_all(action="DESELECT")
for obj in dice_parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = dice_parts[0]

# Curves are useful while authoring the engravings, but hundreds of individual
# curve objects are expensive in a realtime scene. Convert evaluated geometry
# to meshes, then collapse it to a single draw hierarchy.
bpy.ops.object.convert(target="MESH")
dice_parts = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]

# The source die is three Blender units wide. Export it as a one-unit die so it
# matches the collision body and visual scale used by dice_3d.gd.
for obj in dice_parts:
    obj.location = obj.location / 3.0
    obj.scale = obj.scale / 3.0
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

bpy.context.view_layer.objects.active = dice_parts[0]
bpy.ops.object.join()
die = bpy.context.active_object
die.name = "MedievalDiceV2"

bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

OUTPUT_GLB.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_extras=False,
    export_cameras=False,
    export_lights=False,
)

print(f"Exported {OUTPUT_GLB}")
print(f"Dimensions: {tuple(round(value, 4) for value in die.dimensions)}")
print(f"Polygons: {len(die.data.polygons)}")
