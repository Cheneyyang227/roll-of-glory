class_name DiceBoard3D
extends Node3D

signal roll_finished(values: Array[int])
signal die_clicked(index: int)

const DiceActor := preload("res://scripts/game/dice_3d.gd")

@onready var dice_root: Node3D = %DiceRoot
var dice: Array[DiceActor3D] = []
var rolling := false
var dice_style: int = DiceActor3D.VisualStyle.DARK_WOOD


func throw_dice(count: int) -> void:
	if rolling:
		return
	clear_dice()
	rolling = true
	for index in range(count):
		var die := DiceActor.new() as DiceActor3D
		die.setup(index, dice_style)
		die.clicked.connect(_on_die_clicked)
		dice_root.add_child(die)
		dice.append(die)
		var spawn := Vector3(-3.1 + index * 0.72, 4.2 + index * 0.13, 1.6 + randf_range(-0.35, 0.35))
		var impulse := Vector3(randf_range(1.2, 2.8), randf_range(-0.2, 0.45), randf_range(-3.3, -1.8))
		var spin := Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12))
		die.throw_from(spawn, impulse, spin)

	await get_tree().create_timer(2.8).timeout
	var values: Array[int] = []
	for die in dice:
		die.freeze = true
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO
		values.append(die.get_top_value())
	rolling = false
	roll_finished.emit(values)


func set_die_selected(index: int, selected: bool) -> void:
	if index >= 0 and index < dice.size():
		dice[index].set_selected(selected)


func clear_dice() -> void:
	for die in dice:
		if is_instance_valid(die):
			die.queue_free()
	dice.clear()


func _on_die_clicked(index: int) -> void:
	die_clicked.emit(index)
