extends SceneTree
## Self-contained headless test runner for the dice scoring module.
##
## Run with:  godot --headless --script res://tests/test_dice_score.gd
## Exits 0 when all cases pass, 1 otherwise.

var _passed := 0
var _failed := 0
var _failures: Array[String] = []
const TurnStateScript := preload("res://scripts/game/turn_state.gd")


func _init() -> void:
	_run_all_tests()
	_print_summary()
	quit(1 if _failed > 0 else 0)


func _check(description: String, condition: bool) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		_failures.append(description)
		print("  FAIL: " + description)


func _typed(dice: Array) -> Array[int]:
	var out: Array[int] = []
	for v in dice:
		out.append(int(v))
	return out


func _check_score(description: String, dice: Array, expected_score: int, expected_has_score: bool) -> void:
	var result := DiceScoring.calculate_score(_typed(dice))
	_check("%s -> score %d (got %d)" % [description, expected_score, result.score], result.score == expected_score)
	_check("%s -> has_score %s (got %s)" % [description, expected_has_score, result.has_score], result.has_score == expected_has_score)


func _check_full(description: String, dice: Array, expected_score: int, expected_has_score: bool, expected_scored: Array, expected_remaining: Array) -> void:
	var result := DiceScoring.calculate_score(_typed(dice))
	_check("%s -> score %d (got %d)" % [description, expected_score, result.score], result.score == expected_score)
	_check("%s -> has_score %s (got %s)" % [description, expected_has_score, result.has_score], result.has_score == expected_has_score)
	_check("%s -> scored_dice %s (got %s)" % [description, expected_scored, result.scored_dice], result.scored_dice == expected_scored)
	_check("%s -> remaining_dice %s (got %s)" % [description, expected_remaining, result.remaining_dice], result.remaining_dice == expected_remaining)


func _run_all_tests() -> void:
	# --- Singles ---
	_check_score("[1]", [1], 100, true)
	_check_score("[3]", [3], 50, true)
	_check_score("[2]", [2], 0, false)
	_check_score("[4]", [4], 0, false)
	_check_score("[5]", [5], 0, false)
	_check_score("[6]", [6], 0, false)

	# --- Triples ---
	_check_score("[1,1,1]", [1, 1, 1], 1000, true)
	_check_score("[2,2,2]", [2, 2, 2], 200, true)
	_check_score("[3,3,3]", [3, 3, 3], 300, true)
	_check_score("[4,4,4]", [4, 4, 4], 400, true)
	_check_score("[5,5,5]", [5, 5, 5], 500, true)
	_check_score("[6,6,6]", [6, 6, 6], 600, true)

	# --- Straights ---
	_check_score("[1,2,3,4,5]", [1, 2, 3, 4, 5], 500, true)
	_check_score("[2,3,4,5,6]", [2, 3, 4, 5, 6], 500, true)
	_check_score("[1,2,3,4,5,6]", [1, 2, 3, 4, 5, 6], 1000, true)

	# --- Mixed ---
	_check_full("[1,1,1,3,5,6]", [1, 1, 1, 3, 5, 6], 1050, true, [1, 1, 1, 3], [5, 6])
	_check_score("[5,5,5,1,3,6]", [5, 5, 5, 1, 3, 6], 650, true)
	_check_score("[1,2,3,4,5,5]", [1, 2, 3, 4, 5, 5], 500, true)
	_check_full("[1,1,1,3,3,5]", [1, 1, 1, 3, 3, 5], 1100, true, [1, 1, 1, 3, 3], [5])

	# --- Bust ---
	_check_score("[2,4,5]", [2, 4, 5], 0, false)
	_check_score("[2,4,6]", [2, 4, 6], 0, false)
	_check_score("[4,5,6]", [4, 5, 6], 0, false)

	# --- Turn selection and banking ---
	var turn := TurnStateScript.new()
	turn.rolled_dice = _typed([1, 2, 3, 4, 6, 6])
	turn.phase = TurnStateScript.Phase.AWAITING_SELECTION
	turn.toggle_die(0)
	turn.toggle_die(1)
	_check("selection containing a non-scoring die is invalid", not turn.is_selection_valid())
	turn.toggle_die(1)
	turn.toggle_die(2)
	_check("two scoring singles are valid", turn.is_selection_valid())
	_check("selected singles score 150", turn.get_selection_result().score == 150)
	_check("committing leaves four dice", not turn.commit_selection() and turn.dice_to_roll == 4)
	_check("committing adds to turn score", turn.turn_score == 150)

	turn.rolled_dice = _typed([1, 1, 1, 3])
	turn.phase = TurnStateScript.Phase.AWAITING_SELECTION
	for index in range(4):
		turn.toggle_die(index)
	_check("using every remaining die triggers Hot Dice", turn.commit_selection())
	_check("Hot Dice restores six dice", turn.dice_to_roll == 6)

	turn.rolled_dice = _typed([3])
	turn.phase = TurnStateScript.Phase.AWAITING_SELECTION
	turn.toggle_die(0)
	var banked := turn.bank_score()
	_check("banking returns the complete turn score", banked == 1250)
	_check("banking moves turn score to total", turn.total_score == 1250 and turn.turn_score == 0)


func _print_summary() -> void:
	print("")
	print("Dice scoring tests: %d passed, %d failed, %d total" % [_passed, _failed, _passed + _failed])
	if _failed > 0:
		print("Failures:")
		for f in _failures:
			print("  - " + f)
	else:
		print("All tests passed.")
