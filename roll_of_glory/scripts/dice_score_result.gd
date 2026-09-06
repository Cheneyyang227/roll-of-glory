class_name DiceScoreResult
extends RefCounted
## Result of scoring a set of dice.
##
## [score] is the highest total reachable by combining legal scoring patterns
## (triples, singles, straights) with no die reused. [scored_dice] holds the
## dice consumed by that combination and [remaining_dice] the dice left over,
## both in original input order. [has_score] is true iff at least one legal
## scoring pattern exists, independent of [score].

var score: int = 0
var scored_dice: Array[int] = []
var remaining_dice: Array[int] = []
var has_score: bool = false
