class_name DiceScoring
extends RefCounted
## Dice scoring algorithm.
##
## Given up to six 6-sided dice, [method calculate_score] finds the highest
## total reachable by combining legal scoring patterns — triples, singles and
## straights — where every die is used by at most one pattern. It does not
## generate new dice or decide turns; it only reports score and which dice were
## consumed vs. left over (an empty [member DiceScoreResult.remaining_dice] lets
## the game layer trigger Hot Dice).

## Returns the best-scoring result for [param dice] (values 1..6, up to 6 dice).
static func calculate_score(dice: Array[int]) -> DiceScoreResult:
	var result := DiceScoreResult.new()
	var counts := _count_dice(dice)
	var patterns := _build_patterns()

	var best := _search(counts, patterns, {})
	result.score = int(best[0])
	var used: Array = best[1]

	# Reconstruct scored/remaining dice in the original input order. Dice of the
	# same value are indistinguishable, so consuming by value count is exact.
	var remaining_used := used.duplicate()
	for value in dice:
		if value >= 1 and value <= 6 and int(remaining_used[value]) > 0:
			remaining_used[value] = int(remaining_used[value]) - 1
			result.scored_dice.append(value)
		else:
			result.remaining_dice.append(value)

	result.has_score = _has_scoring_pattern(counts, patterns)
	return result


## Builds counts[1..6] (index 0 unused) from the input dice.
static func _count_dice(dice: Array[int]) -> Array:
	var counts: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for value in dice:
		if value >= 1 and value <= 6:
			counts[value] += 1
	return counts


## Builds the list of scoring patterns, each as {"delta": Array, "score": int},
## where "delta" is a size-7 count vector of dice the pattern consumes.
static func _build_patterns() -> Array:
	var patterns := []

	# Singles: 1 = 100, 3 = 50. (2/4/5/6 score 0 and are never a pattern.)
	patterns.append(_make_pattern(_delta_for([1]), 100))
	patterns.append(_make_pattern(_delta_for([3]), 50))

	# Triples: 111 = 1000, otherwise face value * 100.
	for v in range(1, 7):
		var score := 1000 if v == 1 else v * 100
		patterns.append(_make_pattern(_delta_for([v, v, v]), score))

	# Straights.
	patterns.append(_make_pattern(_delta_for([1, 2, 3, 4, 5]), 500))
	patterns.append(_make_pattern(_delta_for([2, 3, 4, 5, 6]), 500))
	patterns.append(_make_pattern(_delta_for([1, 2, 3, 4, 5, 6]), 1000))

	return patterns


## Maximum-covering DFS over count vectors. Returns [best_score, best_used],
## where best_used is a size-7 count vector of the dice consumed by the best
## solution for this state. Memoized on the count vector.
static func _search(counts: Array, patterns: Array, memo: Dictionary) -> Array:
	var key := _key_of(counts)
	if memo.has(key):
		return memo[key]

	var best_score := 0
	var best_used: Array = [0, 0, 0, 0, 0, 0, 0]

	for pattern in patterns:
		var delta: Array = pattern["delta"]
		if _fits(counts, delta):
			var next := _subtract(counts, delta)
			var sub: Array = _search(next, patterns, memo)
			var total: int = int(pattern["score"]) + int(sub[0])
			if total > best_score:
				best_score = total
				best_used = _add_arrays(delta, sub[1])

	var result: Array = [best_score, best_used]
	memo[key] = result
	return result


static func _fits(counts: Array, delta: Array) -> bool:
	for i in range(1, 7):
		if int(counts[i]) < int(delta[i]):
			return false
	return true


static func _subtract(counts: Array, delta: Array) -> Array:
	var out: Array[int] = []
	for i in range(7):
		out.append(int(counts[i]) - int(delta[i]))
	return out


static func _add_arrays(a: Array, b: Array) -> Array:
	var out: Array[int] = []
	for i in range(7):
		out.append(int(a[i]) + int(b[i]))
	return out


static func _key_of(counts: Array) -> String:
	return "%d,%d,%d,%d,%d,%d" % [
		int(counts[1]), int(counts[2]), int(counts[3]),
		int(counts[4]), int(counts[5]), int(counts[6]),
	]


static func _make_pattern(delta: Array, score: int) -> Dictionary:
	return {"delta": delta, "score": score}


static func _delta_for(values: Array) -> Array:
	var delta: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for v in values:
		delta[v] += 1
	return delta


## True iff at least one scoring pattern fits the dice (decoupled from score).
static func _has_scoring_pattern(counts: Array, patterns: Array) -> bool:
	for pattern in patterns:
		if _fits(counts, pattern["delta"]):
			return true
	return false
