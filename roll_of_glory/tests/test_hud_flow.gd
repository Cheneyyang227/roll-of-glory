extends SceneTree


func _init() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	assert(main.main_menu.visible)
	main._open_dice_selection()
	assert(main.dice_selection_overlay.visible)
	main._select_black_iron()
	assert(main.selected_dice_style == DiceActor3D.VisualStyle.BLACK_IRON)
	assert(main.dice_board.dice_style == DiceActor3D.VisualStyle.BLACK_IRON)
	main._close_dice_selection()
	assert(not main.dice_selection_overlay.visible)

	main._open_main_settings()
	assert(main.settings_opened_from_main_menu)
	assert(main.settings_panel.visible)
	main._close_settings()
	assert(main.main_menu.visible)
	assert(not paused)

	main._start_ai_match()
	assert(main.match_running)
	assert(main.header.visible)
	assert(main.bottom_hud.visible)
	assert(not main.main_menu.visible)

	main._open_pause_menu()
	assert(paused)
	assert(main.pause_menu.visible)
	main._open_settings()
	assert(main.settings_panel.visible)
	main._close_settings()
	assert(main.pause_panel.visible)
	main._close_pause_menu()
	assert(not paused)

	main._open_controls_overlay()
	assert(paused)
	assert(main.controls_overlay.visible)
	main._close_controls_overlay()
	assert(not paused)

	print("HUD flow smoke test passed")
	quit()
