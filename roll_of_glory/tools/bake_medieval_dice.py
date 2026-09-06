"""Bake the authored Blender materials to a Godot/glTF-compatible texture set."""

from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[1]
TEXTURE_DIR = PROJECT_ROOT.parent / "art/blender/dark_wood/baked_textures"
OUTPUT_GLB = PROJECT_ROOT / "assets/models/dark_wood/medieval_dice_v2.glb"
TEXTURE_SIZE = 2048


def is_dice_part(obj: bpy.types.Object) -> bool:
    return obj.type in {"MESH", "CURVE"} and not obj.name.startswith("Studio •")


def make_image(name: str, colorspace: str) -> bpy.types.Image:
    old = bpy.data.images.get(name)
    if old:
        bpy.data.images.remove(old)
    image = bpy.data.images.new(name, width=TEXTURE_SIZE, height=TEXTURE_SIZE)
    image.colorspace_settings.name = colorspace
    return image


def set_bake_target(materials: list[bpy.types.Material], image: bpy.types.Image) -> None:
    for material in materials:
        material.use_nodes = True
        nodes = material.node_tree.nodes
        target = nodes.get("GAME_BAKE_TARGET") or nodes.new("ShaderNodeTexImage")
        target.name = "GAME_BAKE_TARGET"
        target.label = "Game bake target"
        target.image = image
        nodes.active = target
        target.select = True


def save_image(image: bpy.types.Image, filename: str) -> None:
    image.filepath_raw = str(TEXTURE_DIR / filename)
    image.file_format = "PNG"
    image.save()
    print(f"Saved {image.filepath_raw}")


dice_parts = [obj for obj in bpy.context.scene.objects if is_dice_part(obj)]
if not dice_parts:
    raise RuntimeError("No dice geometry was found in the source scene")

bpy.ops.object.select_all(action="DESELECT")
for obj in dice_parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = dice_parts[0]
bpy.ops.object.convert(target="MESH")
dice_parts = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"]

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

# Build a single atlas UV shared by every material slot.
while die.data.uv_layers:
    die.data.uv_layers.remove(die.data.uv_layers[0])
die.data.uv_layers.new(name="GameUV")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=0.785398, island_margin=0.006)
bpy.ops.object.mode_set(mode="OBJECT")

materials = [slot.material for slot in die.material_slots if slot.material]
TEXTURE_DIR.mkdir(parents=True, exist_ok=True)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 8
scene.render.image_settings.file_format = "PNG"
scene.render.bake.margin = 12
scene.render.bake.use_clear = True
scene.render.bake.use_selected_to_active = False

albedo = make_image("MedievalDiceV2_Albedo", "sRGB")
set_bake_target(materials, albedo)
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
bpy.ops.object.bake(type="DIFFUSE")
save_image(albedo, "medieval_dice_v2_albedo.png")

roughness = make_image("MedievalDiceV2_Roughness", "Non-Color")
set_bake_target(materials, roughness)
bpy.ops.object.bake(type="ROUGHNESS")
save_image(roughness, "medieval_dice_v2_roughness.png")

normal = make_image("MedievalDiceV2_Normal", "Non-Color")
set_bake_target(materials, normal)
scene.render.bake.normal_space = "TANGENT"
bpy.ops.object.bake(type="NORMAL")
save_image(normal, "medieval_dice_v2_normal.png")

ao = make_image("MedievalDiceV2_AO", "Non-Color")
set_bake_target(materials, ao)
bpy.ops.object.bake(type="AO")
save_image(ao, "medieval_dice_v2_ao.png")

# Convert the Blender-specific shader graphs to the portable subset understood
# by glTF and Godot. Material assignments remain intact, but all slots sample the
# same atlas using the newly generated GameUV coordinates.
for material in materials:
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    color_node = nodes.new("ShaderNodeTexImage")
    color_node.image = albedo
    rough_node = nodes.new("ShaderNodeTexImage")
    rough_node.image = roughness
    rough_node.image.colorspace_settings.name = "Non-Color"
    normal_node = nodes.new("ShaderNodeTexImage")
    normal_node.image = normal
    normal_node.image.colorspace_settings.name = "Non-Color"
    normal_map = nodes.new("ShaderNodeNormalMap")
    material.node_tree.links.new(color_node.outputs["Color"], shader.inputs["Base Color"])
    material.node_tree.links.new(rough_node.outputs["Color"], shader.inputs["Roughness"])
    material.node_tree.links.new(normal_node.outputs["Color"], normal_map.inputs["Color"])
    material.node_tree.links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])

# Restore metalness by material role; the visible color/roughness variation is
# already contained in the baked atlases.
for material in materials:
    shader = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    lower_name = material.name.lower()
    shader.inputs["Metallic"].default_value = 0.78 if "brass" in lower_name else 0.0

bpy.ops.object.select_all(action="DESELECT")
die.select_set(True)
bpy.context.view_layer.objects.active = die
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT_GLB),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_cameras=False,
    export_lights=False,
)

print(f"Exported {OUTPUT_GLB}")
print(f"Dimensions: {tuple(round(value, 4) for value in die.dimensions)}")
print(f"Polygons: {len(die.data.polygons)}")
