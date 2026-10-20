extends Node
## Local probe: the creator's Visage tab.

func _ready() -> void:
	var c := CharacterCreator.open(self)
	await get_tree().process_frame
	c._clan = &""
	c._with_clan = false
	c._avatar = SSAvatars.complete({"seed": 3, "sex": "Female", "facepaint": "MI_CHR_FacePaint_Kiba", "facepaint_color": SSAvatars.colour_ids("FacePaint")[0]})
	c._step = CharacterCreator.Step.LOOK
	c._look_tab = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 1
	c._refresh()
	c._rebuild_content()
	c._look_changed()