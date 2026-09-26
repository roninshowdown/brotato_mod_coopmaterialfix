extends "res://singletons/text.gd"

# Coop Material Fix 1.3.1 - ImprovedTooltips compatibility
#
# ImprovedTooltips (_wl-ImprovedTooltips) replaces
# ItemDescription._generate_description_effects() completely and renders every
# line via EffectLine._display_special_text(), so our EffectLine._display_effect()
# hook never runs while it is active. Instead we chain onto its own text builder:
# _wl_get_effect_line() is the per-effect choke point it uses for character
# tooltips (_wl_get_character_data_desc).
#
# This script is only installed when ImprovedTooltips is loaded (see mod_main.gd),
# because the base methods it calls only exist in ImprovedTooltips's text.gd
# extension. Load order is guaranteed via optional_dependencies in manifest.json.

const CMF_IT_ONLY_YOU_SUFFIX := " (only applies to you)"
const CMF_IT_ORIGIN_CHARACTER := 0 # _wl_EffectOrigin.CHARACTER


func _wl_get_effect_line(player_index: int, effect: Effect, origin: int) -> Dictionary:
	var line: Dictionary = ._wl_get_effect_line(player_index, effect, origin)

	if origin != CMF_IT_ORIGIN_CHARACTER or effect == null:
		return line

	if effect.value < 0 and (effect.key == "gold_drops" or effect.key == "enemy_gold_drops"):
		if line.has("text") and line.text != "":
			line.text += CMF_IT_ONLY_YOU_SUFFIX

	return line
