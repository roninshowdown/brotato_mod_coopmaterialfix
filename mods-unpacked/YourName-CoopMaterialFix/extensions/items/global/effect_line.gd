extends "res://items/global/effect_line.gd"

# Coop Material Fix 1.3.0
#
# The "(only applies to you)" label used to be attached by extending
# Effect.get_text() (res://items/global/effect.gd). That was unreliable:
# Effect resources are loaded and cached by ItemService at game boot, likely
# before this mod's _init() installs its script extensions, so already-cached
# Effect instances never picked up the extension and the label silently never
# rendered (verified: the plain "-50% materials dropped" text still rendered
# from the base, unextended script, with zero trace of this mod's code ever
# running for it).
#
# EffectLine is different: it's a UI Node instanced fresh every time a
# tooltip/description line renders (effect_line.instance(), see
# ItemDescription._generate_description_effects()), long after mods finish
# loading. Extending its _display_effect() choke point is reliable regardless
# of when the underlying Effect resource was first cached.

const CMF_ONLY_YOU_SUFFIX := " (only applies to you)"


func _display_effect(player_index: int, _effect: Effect, colored: bool = true, activate_tab: bool = true):
	._display_effect(player_index, _effect, colored, activate_tab)

	if _effect == null:
		return

	if _effect.value < 0 and (_effect.key == "gold_drops" or _effect.key == "enemy_gold_drops"):
		var owned := _cmf_is_owned_by_players_character(player_index, _effect)
		ModLoaderLog.info(
			"CMF DEBUG _display_effect key=%s value=%s player_index=%s owned=%s" % [_effect.key, _effect.value, player_index, owned],
			"CMF"
		)
		if owned and is_instance_valid(text_descr):
			text_descr.bbcode_text += CMF_ONLY_YOU_SUFFIX


# Checks the player's current item list rather than RunData.get_player_character():
# during character-select hover the game only calls RunData.add_item() to preview
# the character (current_character stays null until the pick is confirmed and the
# run actually starts), so relying on get_player_character() alone would miss the
# hover-preview case entirely. Checking items covers both preview and live gameplay,
# since RunData.add_character() also calls add_item() internally.
func _cmf_is_owned_by_players_character(player_index: int, effect: Effect) -> bool:
	if player_index < 0 or player_index == RunData.DUMMY_PLAYER_INDEX:
		return false
	if player_index >= RunData.get_player_count():
		return false

	for item in RunData.get_player_items_ref(player_index):
		if item is CharacterData and item.effects != null:
			for character_effect in item.effects:
				if character_effect == effect:
					return true

	return false
