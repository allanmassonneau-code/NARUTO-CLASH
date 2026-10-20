class_name Technique
extends RefCounted
## One technique of the design bible, scripted. Subclasses override:
##   configure(a)  - frame data / range / animation of the AbilityData built
##                   for it (defaults come from its rank and tags);
##   cast(t)       - what happens when the cast comes out (t: Tk API).
## Recasts, objects, marks and resources are opened from cast() through Tk.

var id: StringName
var jutsu: JutsuData


func configure(_a: AbilityData) -> void:
	pass


func cast(_t: Tk) -> void:
	pass
