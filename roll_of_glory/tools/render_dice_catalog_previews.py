"""Render every selectable die with identical catalog framing and lighting."""

from math import radians
from pathlib import Path

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[1]
PREVIEW_DIR = PROJECT_ROOT / "assets/ui/dice_previews"
PREVIEWS = {
    PROJECT_ROOT / "assets/models/dark_wood/medieval_dice_v2.glb": PREVIEW_DIR / "dark_wood.png",
    PROJECT_ROOT / "assets/models/black_iron/black_iron_royal.glb": PREVIEW_DIR / "black_iron_royal.png",
}


def look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def create_studio() -> None:
    bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.54))
    plane = bpy.context.object
    plane.name = "Catalog tabletop"
    material = bpy.data.materials.new("Catalog dark walnut")
    material.diffuse_color = (0.026, 0.014, 0.008, 1.0)
    material.roughness = 0.88
    plane.data.materials.append(material)

    lights = [
        ((-2.8, -3.4, 4.6), 720, (1.0, 0.68, 0.38), 3.4),
        ((3.2, -1.0, 2.5), 330, (0.48, 0.58, 0.72), 2.7),
        ((1.2, 3.0, 3.5), 480, (1.0, 0.48, 0.20), 2.5),
    ]
    for location, energy, color, size in lights:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        look_at(light, Vector((0, 0, 0)))

    bpy.ops.object.camera_add(location=(2.7, -4.2, 2.75))
    camera = bpy.context.object
    camera.name = "Catalog camera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 1.72
    camera.data.lens = 58
    look_at(camera, Vector((0, 0, 0.02)))
    bpy.context.scene.camera = camera


def normalize_die() -> bpy.types.Object:
    meshes = [obj for obj in bpy.context.view_layer.objects if obj.type == "MESH"]
    # The studio plane has not been created yet, so every mesh belongs to the die.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    die = bpy.context.object
    die.name = "Catalog die"

    corners = [die.matrix_world @ Vector(corner) for corner in die.bound_box]
    minimum = Vector((min(p.x for p in corners), min(p.y for p in corners), min(p.z for p in corners)))
    maximum = Vector((max(p.x for p in corners), max(p.y for p in corners), max(p.z for p in corners)))
    size = maximum - minimum
    center = (minimum + maximum) * 0.5
    die.location -= center
    die.scale *= 1.0 / max(size)
    bpy.context.view_layer.update()
    die.rotation_euler = (radians(13), radians(-18), radians(38))
    return die


def render_preview(model_path: Path, output_path: Path) -> None:
    reset_scene()
    bpy.ops.import_scene.gltf(filepath=str(model_path))
    normalize_die()
    create_studio()

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.render.filepath = str(output_path)
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.world.color = (0.009, 0.006, 0.004)
    bpy.ops.render.render(write_still=True)
    print(f"Rendered {output_path}")


PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
for model, output in PREVIEWS.items():
    render_preview(model, output)
