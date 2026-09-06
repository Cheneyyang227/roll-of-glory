extends SceneTree
## Headless smoke test for the real 3D throw-to-scoring pipeline.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game._start_ai_match()
	game._on_roll_pressed()
	await create_timer(3.2).timeout

	var values: Array[int] = game.state.rolled_dice
	var valid_count := values.size() == 6
	var valid_faces := true
	for value in values:
		valid_faces = valid_faces and value >= 1 and value <= 6

	if valid_count and valid_faces:
		print("3D roll smoke test passed: ", values)
		quit(0)
	else:
		printerr("3D roll smoke test failed: ", values)
		quit(1)
