class_name TurnState
extends RefCounted
## Pure data and rules for one local player's turn.

enum Phase {
	READY_TO_ROLL,
	AWAITING_SELECTION,
	BUST,
}

var total_score: int = 0
var turn_score: int = 0
var dice_to_roll: int = 6
var rolled_dice: Array[int] = []
var selected_indices: Array[int] = []
var phase: Phase = Phase.READY_TO_ROLL


func roll_dice(rng: RandomNumberGenerator) -> DiceScoreResult:
	assert(phase == Phase.READY_TO_ROLL, "Dice can only be rolled while ready")
	var values: Array[int] = []
	for i in range(dice_to_roll):
		values.append(rng.randi_range(1, 6))
	return apply_rolled_dice(values)


func apply_rolled_dice(values: Array[int]) -> DiceScoreResult:
	assert(phase == Phase.READY_TO_ROLL, "Dice can only be resolved while ready")
	rolled_dice = values.duplicate()
	selected_indices.clear()
	var result := DiceScoring.calculate_score(rolled_dice)
	if result.has_score:
		phase = Phase.AWAITING_SELECTION
	else:
		turn_score = 0
		phase = Phase.BUST
	return result


func toggle_die(index: int) -> void:
	if phase != Phase.AWAITING_SELECTION or index < 0 or index >= rolled_dice.size():
		return
	if selected_indices.has(index):
		selected_indices.erase(index)
	else:
		selected_indices.append(index)
		selected_indices.sort()


func get_selected_dice() -> Array[int]:
	var values: Array[int] = []
	for index in selected_indices:
		values.append(rolled_dice[index])
	return values


func get_selection_result() -> DiceScoreResult:
	return DiceScoring.calculate_score(get_selected_dice())


func is_selection_valid() -> bool:
	if selected_indices.is_empty():
		return false
	var result := get_selection_result()
	return result.has_score and result.remaining_dice.is_empty()


## Locks the selected scoring dice and returns true when Hot Dice was reached.
func commit_selection() -> bool:
	assert(is_selection_valid(), "Only a fully scoring selection can be committed")
	turn_score += get_selection_result().score
	var remaining_count := rolled_dice.size() - selected_indices.size()
	var hot_dice := remaining_count == 0
	dice_to_roll = 6 if hot_dice else remaining_count
	rolled_dice.clear()
	selected_indices.clear()
	phase = Phase.READY_TO_ROLL
	return hot_dice


func bank_score() -> int:
	commit_selection()
	var banked := turn_score
	total_score += banked
	turn_score = 0
	dice_to_roll = 6
	return banked


func start_next_turn() -> void:
	turn_score = 0
	dice_to_roll = 6
	rolled_dice.clear()
	selected_indices.clear()
	phase = Phase.READY_TO_ROLL
