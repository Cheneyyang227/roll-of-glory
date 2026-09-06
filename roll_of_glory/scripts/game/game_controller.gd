extends Control

const TurnStateModel := preload("res://scripts/game/turn_state.gd")
const TARGET_SCORE := 5000
const AI_BANK_THRESHOLDS := {
	1: 100,
	2: 200,
	3: 300,
	4: 450,
	5: 600,
	6: 800,
}

enum Actor { PLAYER, COMPUTER }

@onready var dice_board: DiceBoard3D = %DiceBoard3D
@onready var main_menu: Control = %MainMenu
@onready var header: Control = %Header
@onready var bottom_hud: Control = %BottomHud
@onready var result_overlay: Control = %ResultOverlay
@onready var player_score_label: Label = %PlayerScoreLabel
@onready var computer_score_label: Label = %ComputerScoreLabel
@onready var computer_turn_label: Label = %ComputerTurnLabel
@onready var turn_score_label: Label = %TurnScoreLabel
@onready var status_label: Label = %StatusLabel
@onready var selection_label: Label = %SelectionLabel
@onready var roll_button: Button = %RollButton
@onready var continue_button: Button = %ContinueButton
@onready var bank_button: Button = %BankButton
@onready var versus_ai_button: Button = %VersusAIButton
@onready var dice_style_button: Button = %DiceStyleButton
@onready var main_settings_button: Button = %MainSettingsButton
@onready var main_exit_game_button: Button = %MainExitGameButton
@onready var dice_selection_overlay: Control = %DiceSelectionOverlay
@onready var dark_wood_card: PanelContainer = %DarkWoodCard
@onready var black_iron_card: PanelContainer = %BlackIronCard
@onready var dark_wood_preview_button: TextureButton = %DarkWoodPreviewButton
@onready var black_iron_preview_button: TextureButton = %BlackIronPreviewButton
@onready var selected_dice_label: Label = %SelectedDiceLabel
@onready var confirm_dice_button: Button = %ConfirmDiceButton
@onready var result_label: Label = %ResultLabel
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton
@onready var pause_menu: Control = %PauseMenu
@onready var pause_panel: Control = $PauseMenu/Center/PausePanel
@onready var settings_panel: Control = %SettingsPanel
@onready var controls_overlay: Control = %ControlsOverlay
@onready var continue_game_button: Button = %ContinueGameButton
@onready var settings_button: Button = %SettingsButton
@onready var return_to_main_menu_button: Button = %ReturnToMainMenuButton
@onready var exit_game_button: Button = %ExitGameButton
@onready var back_from_settings_button: Button = %BackFromSettingsButton
@onready var master_volume_slider: HSlider = %MasterVolumeSlider
@onready var fullscreen_toggle: CheckButton = %FullscreenToggle

var state := TurnStateModel.new() # Kept as the public player state for tests/tools.
var ai_state := TurnStateModel.new()
var current_actor := Actor.PLAYER
var match_running := false
var selected_dice_style := DiceActor3D.VisualStyle.DARK_WOOD
var settings_opened_from_main_menu := false
const DICE_STYLE_NAMES := ["深色木骰", "黑铁王室骰"]


func _ready() -> void:
	roll_button.pressed.connect(_on_roll_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	versus_ai_button.pressed.connect(_start_ai_match)
	main_settings_button.pressed.connect(_open_main_settings)
	dice_style_button.pressed.connect(_open_dice_selection)
	main_exit_game_button.pressed.connect(_exit_game)
	dark_wood_preview_button.pressed.connect(_select_dark_wood)
	black_iron_preview_button.pressed.connect(_select_black_iron)
	confirm_dice_button.pressed.connect(_close_dice_selection)
	restart_button.pressed.connect(_start_ai_match)
	menu_button.pressed.connect(_return_to_menu)
	continue_game_button.pressed.connect(_close_pause_menu)
	settings_button.pressed.connect(_open_settings)
	return_to_main_menu_button.pressed.connect(_return_to_menu)
	exit_game_button.pressed.connect(_exit_game)
	back_from_settings_button.pressed.connect(_close_settings)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	dice_board.roll_finished.connect(_on_roll_finished)
	dice_board.die_clicked.connect(_on_die_toggled)
	_apply_button_styles()
	fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_show_main_menu()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE and dice_selection_overlay.visible:
		_close_dice_selection()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE and settings_opened_from_main_menu:
		_close_settings()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE and match_running:
		if controls_overlay.visible:
			_close_controls_overlay()
		elif settings_panel.visible:
			_close_settings()
		elif pause_menu.visible:
			_close_pause_menu()
		else:
			_open_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_T and match_running and not pause_menu.visible:
		if controls_overlay.visible:
			_close_controls_overlay()
		else:
			_open_controls_overlay()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused or not match_running or current_actor != Actor.PLAYER:
		return
	if event.keycode == KEY_F and state.phase == TurnStateModel.Phase.AWAITING_SELECTION and state.is_selection_valid():
		_on_continue_pressed()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_Q and state.phase == TurnStateModel.Phase.AWAITING_SELECTION and state.is_selection_valid():
		_on_bank_pressed()
		get_viewport().set_input_as_handled()


func _start_ai_match() -> void:
	get_tree().paused = false
	state = TurnStateModel.new()
	ai_state = TurnStateModel.new()
	current_actor = Actor.PLAYER
	match_running = true
	main_menu.visible = false
	dice_selection_overlay.visible = false
	result_overlay.visible = false
	pause_menu.visible = false
	controls_overlay.visible = false
	header.visible = true
	bottom_hud.visible = true
	dice_board.clear_dice()
	status_label.text = "你的回合：投出六枚骰子"
	_refresh()


func _show_main_menu() -> void:
	get_tree().paused = false
	match_running = false
	main_menu.visible = true
	dice_selection_overlay.visible = false
	header.visible = false
	bottom_hud.visible = false
	result_overlay.visible = false
	pause_menu.visible = false
	controls_overlay.visible = false
	settings_opened_from_main_menu = false
	dice_board.clear_dice()


func _return_to_menu() -> void:
	_show_main_menu()


func _on_roll_pressed() -> void:
	if not match_running or current_actor != Actor.PLAYER or dice_board.rolling:
		return
	if state.phase == TurnStateModel.Phase.BUST:
		_begin_ai_turn()
		return
	_throw_for_current_actor()


func _throw_for_current_actor() -> void:
	var active := _active_state()
	roll_button.disabled = true
	status_label.text = "你正在投掷……" if current_actor == Actor.PLAYER else "电脑正在投掷……"
	dice_board.throw_dice(active.dice_to_roll)
	_refresh()


func _on_roll_finished(values: Array[int]) -> void:
	if not match_running:
		return
	var active := _active_state()
	var result := active.apply_rolled_dice(values)
	if current_actor == Actor.PLAYER:
		if result.has_score:
			status_label.text = "点击计分骰；F 保留并重投，Q 收分结束回合"
		else:
			status_label.text = "爆骰！本回合分数尽失，轮到电脑"
			await get_tree().create_timer(1.0, false).timeout
			_begin_ai_turn()
		_refresh()
	else:
		await _resolve_ai_roll(result)


func _on_die_toggled(index: int) -> void:
	if not match_running or current_actor != Actor.PLAYER or dice_board.rolling:
		return
	state.toggle_die(index)
	dice_board.set_die_selected(index, state.selected_indices.has(index))
	_refresh()


## F: lock selected scoring dice, then immediately throw the remaining dice.
func _on_continue_pressed() -> void:
	if current_actor != Actor.PLAYER or not state.is_selection_valid():
		return
	var hot_dice := state.commit_selection()
	status_label.text = "全部计分，Hot Dice！重新投六枚" if hot_dice else "得分已保留，重投剩余骰子"
	dice_board.clear_dice()
	_refresh()
	await get_tree().create_timer(0.25, false).timeout
	_throw_for_current_actor()


## Q: include the current valid selection, bank the turn, and pass to the AI.
func _on_bank_pressed() -> void:
	if current_actor != Actor.PLAYER or not state.is_selection_valid():
		return
	var banked := state.bank_score()
	status_label.text = "你收入 %d 分" % banked
	dice_board.clear_dice()
	_refresh()
	if _check_match_end():
		return
	await get_tree().create_timer(0.75, false).timeout
	_begin_ai_turn()


func _begin_ai_turn() -> void:
	if not match_running:
		return
	state.start_next_turn()
	current_actor = Actor.COMPUTER
	ai_state.start_next_turn()
	dice_board.clear_dice()
	status_label.text = "电脑的回合"
	_refresh()
	await get_tree().create_timer(0.65, false).timeout
	_throw_for_current_actor()


func _resolve_ai_roll(result: DiceScoreResult) -> void:
	if not result.has_score:
		status_label.text = "电脑爆骰，本回合没有得分"
		await get_tree().create_timer(1.0, false).timeout
		_begin_player_turn()
		return

	# The AI takes the scorer's best combination.
	var needed: Array[int] = result.scored_dice.duplicate()
	for index in range(ai_state.rolled_dice.size()):
		var value: int = ai_state.rolled_dice[index]
		var needed_index := needed.find(value)
		if needed_index >= 0:
			ai_state.toggle_die(index)
			dice_board.set_die_selected(index, true)
			needed.remove_at(needed_index)
	status_label.text = "电脑选择了 %d 分" % ai_state.get_selection_result().score
	_refresh()
	await get_tree().create_timer(0.85, false).timeout

	var projected_score := ai_state.turn_score + ai_state.get_selection_result().score
	var remaining_after_selection := ai_state.rolled_dice.size() - ai_state.selected_indices.size()
	var should_bank := _should_ai_bank(projected_score, remaining_after_selection)
	if should_bank:
		var banked := ai_state.bank_score()
		status_label.text = "电脑选择 Q，收入 %d 分" % banked
		dice_board.clear_dice()
		_refresh()
		if _check_match_end():
			return
		await get_tree().create_timer(0.8, false).timeout
		_begin_player_turn()
	else:
		var hot_dice := ai_state.commit_selection()
		status_label.text = "电脑选择 F，触发 Hot Dice" if hot_dice else "电脑选择 F，继续投掷 %d 颗骰子" % ai_state.dice_to_roll
		dice_board.clear_dice()
		_refresh()
		await get_tree().create_timer(0.55, false).timeout
		_throw_for_current_actor()


func _should_ai_bank(projected_score: int, remaining_after_selection: int) -> bool:
	if ai_state.total_score + projected_score >= TARGET_SCORE:
		return true
	var next_roll_count := 6 if remaining_after_selection == 0 else remaining_after_selection
	var threshold: int = AI_BANK_THRESHOLDS.get(next_roll_count, 450)
	return projected_score >= threshold


func _begin_player_turn() -> void:
	if not match_running:
		return
	ai_state.start_next_turn()
	current_actor = Actor.PLAYER
	state.start_next_turn()
	dice_board.clear_dice()
	status_label.text = "你的回合：投出六枚骰子"
	_refresh()


func _check_match_end() -> bool:
	if state.total_score < TARGET_SCORE and ai_state.total_score < TARGET_SCORE:
		return false
	match_running = false
	result_overlay.visible = true
	result_label.text = "你赢得了赌局" if state.total_score >= TARGET_SCORE else "电脑赢得了赌局"
	status_label.text = "赌局结束"
	_refresh()
	return true


func _active_state() -> TurnState:
	return state if current_actor == Actor.PLAYER else ai_state


func _refresh() -> void:
	player_score_label.text = "你  %d / %d" % [state.total_score, TARGET_SCORE]
	computer_score_label.text = "电脑  %d / %d" % [ai_state.total_score, TARGET_SCORE]
	turn_score_label.text = "本回合  +%d" % state.turn_score
	computer_turn_label.text = "本回合  +%d" % ai_state.turn_score

	var player_can_choose := match_running and current_actor == Actor.PLAYER and state.phase == TurnStateModel.Phase.AWAITING_SELECTION
	var valid := state.is_selection_valid() if player_can_choose else false
	var selected_score := state.get_selection_result().score if player_can_choose and not state.selected_indices.is_empty() else 0
	selection_label.text = "已选择：+%d" % selected_score if current_actor == Actor.PLAYER else "电脑正在思考……"
	selection_label.modulate = Color("ffe07a") if valid else Color("c99b31")

	roll_button.visible = match_running and current_actor == Actor.PLAYER and state.phase != TurnStateModel.Phase.AWAITING_SELECTION
	roll_button.disabled = dice_board.rolling
	roll_button.text = "开始电脑回合" if state.phase == TurnStateModel.Phase.BUST else "掷 %d 枚骰子" % state.dice_to_roll
	continue_button.visible = player_can_choose
	bank_button.visible = player_can_choose
	continue_button.disabled = not valid
	bank_button.disabled = not valid
	continue_button.text = "[ F ]  计入 +%d，重投剩余骰子" % selected_score
	bank_button.text = "[ Q ]  结算 %d 分并结束回合" % (state.turn_score + selected_score)


func _apply_button_styles() -> void:
	for button in [roll_button, continue_button, bank_button, versus_ai_button, main_settings_button, dice_style_button, main_exit_game_button, confirm_dice_button, restart_button, menu_button, continue_game_button, settings_button, return_to_main_menu_button, exit_game_button, back_from_settings_button]:
		button.add_theme_stylebox_override("normal", _button_style(Color("5b1718"), Color("bd9454"), 2))
		button.add_theme_stylebox_override("hover", _button_style(Color("7a2524"), Color("e0bd75"), 3))
		button.add_theme_stylebox_override("pressed", _button_style(Color("351011"), Color("8b6937"), 2))
		button.add_theme_stylebox_override("disabled", _button_style(Color("332b25"), Color("62584b"), 1))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", Color("f1dfb5"))
		button.add_theme_color_override("font_hover_color", Color("fff1c8"))
		button.add_theme_color_override("font_disabled_color", Color("897f70"))


func _button_style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.65)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _open_dice_selection() -> void:
	dice_selection_overlay.visible = true
	_refresh_dice_selection()


func _close_dice_selection() -> void:
	dice_selection_overlay.visible = false
	dice_style_button.grab_focus()


func _select_dark_wood() -> void:
	_set_dice_style(DiceActor3D.VisualStyle.DARK_WOOD)


func _select_black_iron() -> void:
	_set_dice_style(DiceActor3D.VisualStyle.BLACK_IRON)


func _set_dice_style(style: int) -> void:
	selected_dice_style = style
	dice_board.dice_style = style
	_refresh_dice_selection()


func _refresh_dice_selection() -> void:
	selected_dice_label.text = "当前选择：%s" % DICE_STYLE_NAMES[selected_dice_style]
	dark_wood_card.add_theme_stylebox_override("panel", _dice_card_style(selected_dice_style == DiceActor3D.VisualStyle.DARK_WOOD))
	black_iron_card.add_theme_stylebox_override("panel", _dice_card_style(selected_dice_style == DiceActor3D.VisualStyle.BLACK_IRON))


func _dice_card_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("3a2619e8") if selected else Color("17100be0")
	style.border_color = Color("f0bd45") if selected else Color("705630")
	style.set_border_width_all(4 if selected else 1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 10
	return style


func _open_pause_menu() -> void:
	settings_opened_from_main_menu = false
	pause_panel.visible = true
	settings_panel.visible = false
	pause_menu.visible = true
	get_tree().paused = true
	continue_game_button.grab_focus()


func _close_pause_menu() -> void:
	pause_menu.visible = false
	settings_panel.visible = false
	pause_panel.visible = true
	get_tree().paused = false


func _open_settings() -> void:
	settings_opened_from_main_menu = false
	pause_panel.visible = false
	settings_panel.visible = true
	back_from_settings_button.grab_focus()


func _close_settings() -> void:
	settings_panel.visible = false
	if settings_opened_from_main_menu:
		settings_opened_from_main_menu = false
		pause_menu.visible = false
		get_tree().paused = false
		main_menu.visible = true
		main_settings_button.grab_focus()
		return
	pause_panel.visible = true
	continue_game_button.grab_focus()


func _open_main_settings() -> void:
	settings_opened_from_main_menu = true
	main_menu.visible = false
	pause_panel.visible = false
	settings_panel.visible = true
	pause_menu.visible = true
	get_tree().paused = true
	back_from_settings_button.grab_focus()


func _open_controls_overlay() -> void:
	controls_overlay.visible = true
	get_tree().paused = true


func _close_controls_overlay() -> void:
	controls_overlay.visible = false
	get_tree().paused = false


func _on_master_volume_changed(value: float) -> void:
	var normalized := maxf(value / 100.0, 0.001)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(normalized))


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _exit_game() -> void:
	get_tree().quit()
