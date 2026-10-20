class_name KitSignature
extends RefCounted
## Signature mechanic of a nature or clan (Braise, Vigueur, Glyphes...):
## a passive layer active on every fighter owning the kit. Override what
## you need; returning a float from on_deal / on_take replaces the damage.
##   setup(fighter)                         - define resources (fighter.kit.define_resource)
##   tick(fighter, delta)
##   on_deal(fighter, target, hit, damage)  -> float or null
##   on_take(fighter, hit, damage)          -> float or null

var kit_id: StringName


func setup(_fighter: CombatCharacter) -> void:
	pass
