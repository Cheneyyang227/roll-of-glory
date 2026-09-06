extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame

	assert(game._should_ai_bank(100, 1), "AI should protect any score with one die left")
	assert(not game._should_ai_bank(150, 2), "AI may risk two dice for a small score")
	assert(game._should_ai_bank(200, 2), "AI should bank 200 with two dice left")
	assert(not game._should_ai_bank(500, 5), "AI may continue with five dice and 500 points")
	assert(game._should_ai_bank(600, 5), "AI should bank 600 with five dice left")
	assert(not game._should_ai_bank(700, 0), "Hot Dice may continue below its threshold")
	assert(game._should_ai_bank(800, 0), "Hot Dice should bank at its threshold")

	game.ai_state.total_score = 4900
	assert(game._should_ai_bank(100, 6), "AI should bank a winning score")

	print("AI decision tests passed")
	quit(0)
