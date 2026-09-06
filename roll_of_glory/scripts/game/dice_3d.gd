class_name DiceActor3D
extends RigidBody3D

signal clicked(index: int)
const MEDIEVAL_DICE_MODEL := preload("res://assets/models/dark_wood/medieval_dice_v2.glb")
const BLACK_IRON_MODEL := preload("res://assets/models/black_iron/black_iron_royal.glb")

enum VisualStyle {
	DARK_WOOD,
	BLACK_IRON,
}

const FACE_NORMALS: Array[Vector3] = [
	Vector3.ZERO,
	Vector3.RIGHT,
	Vector3.BACK,
	Vector3.DOWN,
	Vector3.UP,
	Vector3.FORWARD,
	Vector3.LEFT,
]

var die_index: int = -1
var _selection_frame: Node3D


func setup(index: int, visual_style: int = VisualStyle.DARK_WOOD) -> void:
	die_index = index
	mass = 0.42
	gravity_scale = 1.35
	linear_damp = 0.18
	angular_damp = 0.16
	can_sleep = true
	input_ray_pickable = true

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.82, 0.82, 0.82)
	collision.shape = shape
	add_child(collision)

	var model_scene: PackedScene = BLACK_IRON_MODEL if visual_style == VisualStyle.BLACK_IRON else MEDIEVAL_DICE_MODEL
	var dice_model := model_scene.instantiate()
	dice_model.name = "BlackIronDie" if visual_style == VisualStyle.BLACK_IRON else "MedievalWoodDie"
	dice_model.scale = Vector3.ONE * 0.8
	add_child(dice_model)
	_add_selection_frame()
	input_event.connect(_on_input_event)


func throw_from(spawn_position: Vector3, impulse: Vector3, spin: Vector3) -> void:
	position = spawn_position
	rotation = Vector3(randf_range(-PI, PI), randf_range(-PI, PI), randf_range(-PI, PI))
	linear_velocity = impulse
	angular_velocity = spin


func get_top_value() -> int:
	var best_value := 1
	var best_dot := -1.0
	for value in range(1, 7):
		var world_normal: Vector3 = global_transform.basis * FACE_NORMALS[value]
		var alignment := world_normal.normalized().dot(Vector3.UP)
		if alignment > best_dot:
			best_dot = alignment
			best_value = value
	return best_value


func set_selected(selected: bool) -> void:
	_selection_frame.visible = selected


func _add_selection_frame() -> void:
	_selection_frame = Node3D.new()
	_selection_frame.name = "RedSelectionFrame"
	_selection_frame.visible = false
	add_child(_selection_frame)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d51f19")
	material.emission_enabled = true
	material.emission = Color("ff211b")
	material.emission_energy_multiplier = 2.2
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var edge := 0.424
	var thickness := 0.032
	for y in [-edge, edge]:
		for z in [-edge, edge]:
			_add_frame_bar(Vector3(0, y, z), Vector3(0.88, thickness, thickness), material)
	for x in [-edge, edge]:
		for z in [-edge, edge]:
			_add_frame_bar(Vector3(x, 0, z), Vector3(thickness, 0.88, thickness), material)
	for x in [-edge, edge]:
		for y in [-edge, edge]:
			_add_frame_bar(Vector3(x, y, 0), Vector3(thickness, thickness, 0.88), material)


func _add_frame_bar(bar_position: Vector3, bar_size: Vector3, material: Material) -> void:
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = bar_size
	bar.mesh = mesh
	bar.material_override = material
	bar.position = bar_position
	_selection_frame.add_child(bar)


func _on_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if freeze and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(die_index)
