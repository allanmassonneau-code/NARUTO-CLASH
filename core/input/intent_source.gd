class_name IntentSource
extends Node
## Base for anything that drives a CombatCharacter (player, bot, network).

var intent: GameplayIntent = GameplayIntent.new()


## Called once per physics tick by the owning character.
func poll_intent() -> GameplayIntent:
	return intent
