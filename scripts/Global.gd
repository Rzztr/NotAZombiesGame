extends Node

var sensitivity : float =  .005
var controller_sensitivity : float =  .010

var score: int = 0

@rpc("any_peer", "call_local")
func add_score(amount: int) -> void:
	score += amount

@rpc("any_peer", "call_local")
func reset_score() -> void:
	score = 0

func spend_score(amount: int) -> bool:
	if score >= amount:
		score -= amount
		return true
	return false
