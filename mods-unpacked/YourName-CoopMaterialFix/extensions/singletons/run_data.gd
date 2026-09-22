extends "res://singletons/run_data.gd"

# Coop Material Fix 1.3.0
#
# Main removes only negative CHARACTER-owned material-drop effects from the
# shared world-drop calculation. This extension then applies that removed
# penalty to the affected player's own final material/XP share.
#
# Capture strategy: Main brackets every material pickup with
# _cmf_begin_material_pickup / _cmf_end_material_pickup. Everything the game
# distributes inside that window is captured by player index and re-added at
# the end with each player's personal multiplier applied. No assumptions about
# call order are needed.
#
# Signatures: add_gold / add_xp overrides match the vanilla signatures exactly
# (value, player_index). Base calls always pass the exact argument count.

const CMF_SOURCE_OTHER := 0
const CMF_SOURCE_ENEMY := 1
const CMF_SOURCE_NEUTRAL := 2
const CMF_SOURCE_COUNT := 3

var _cmf_pickup_context := false
var _cmf_pickup_sources := [1, 0, 0]
var _cmf_gold_batch := []
var _cmf_xp_batch := []

# Fractional material payout carried per player. With a 50% penalty, repeated
# one-material shares become 0,1,0,1... (or 1,0... depending prior carry)
# instead of truncating every single pickup to zero.
var _cmf_player_carry := [0.0, 0.0, 0.0, 0.0]


func _cmf_begin_material_pickup(sources: Array) -> void:
	if not is_coop_run or get_player_count() <= 1:
		return

	_cmf_pickup_sources = _cmf_normalize_source_array(sources)

	var count := get_player_count()
	_cmf_gold_batch = []
	_cmf_xp_batch = []
	_cmf_gold_batch.resize(count)
	_cmf_xp_batch.resize(count)
	for i in range(count):
		_cmf_gold_batch[i] = 0
		_cmf_xp_batch[i] = 0

	_cmf_pickup_context = true


func _cmf_end_material_pickup() -> void:
	if not _cmf_pickup_context:
		return

	_cmf_pickup_context = false

	var count := get_player_count()
	var gold_to_give: Array = _cmf_gold_batch.duplicate()
	var xp_to_give: Array = _cmf_xp_batch.duplicate()

	for player_index in range(count):
		var baseline := int(_cmf_gold_batch[player_index])
		if baseline <= 0:
			continue

		# Vanilla material pickups create a matching material and XP share for
		# each player individually. If another mod breaks that invariant for
		# this specific player, leave their gold/XP untouched instead of
		# reinterpreting the result (checked per player, not as batch totals,
		# so one mismatched player can never affect the others).
		if int(_cmf_xp_batch[player_index]) != baseline:
			continue

		var multiplier := _cmf_get_pickup_multiplier(player_index)
		if multiplier >= 0.999999:
			continue

		var exact: float = float(baseline) * multiplier + _cmf_player_carry[player_index]
		var final_value := int(floor(exact + 0.000001))

		_cmf_player_carry[player_index] = exact - float(final_value)
		gold_to_give[player_index] = final_value
		xp_to_give[player_index] = final_value

	ModLoaderLog.info("CMF pickup gold=%s xp=%s" % [str(gold_to_give), str(xp_to_give)], "CMF")

	for i in range(count):
		.add_gold(int(gold_to_give[i]), i)
		.add_xp(int(xp_to_give[i]), i)


func add_gold(value: int, player_index: int) -> void:
	if _cmf_pickup_context and player_index >= 0 and player_index < _cmf_gold_batch.size():
		_cmf_gold_batch[player_index] += value
		return

	.add_gold(value, player_index)


func add_xp(value: int, player_index: int) -> void:
	if _cmf_pickup_context and player_index >= 0 and player_index < _cmf_xp_batch.size():
		_cmf_xp_batch[player_index] += value
		return

	.add_xp(value, player_index)


func _cmf_get_pickup_multiplier(player_index: int) -> float:
	var total_sources := 0.0
	for source in range(CMF_SOURCE_COUNT):
		total_sources += float(_cmf_pickup_sources[source])

	if total_sources <= 0.0:
		return 1.0

	var multiplier := 0.0
	for source in range(CMF_SOURCE_COUNT):
		var source_amount := float(_cmf_pickup_sources[source])
		if source_amount <= 0.0:
			continue

		var source_fraction := source_amount / total_sources
		multiplier += source_fraction * _cmf_get_personal_multiplier(player_index, source)

	return clamp(multiplier, 0.0, 1.0)


# Returns only the negative material-drop effect authored on the player's
# CHARACTER. Positive effects and non-character effects stay in vanilla's
# shared calculation.
func _cmf_get_personal_penalty(effect_key_hash: int, player_index: int) -> float:
	if player_index < 0 or player_index >= get_player_count():
		return 0.0

	var character = get_player_character(player_index)
	if character == null or character.effects == null:
		return 0.0

	var key_name := ""
	if effect_key_hash == Keys.gold_drops_hash:
		key_name = "gold_drops"
	elif effect_key_hash == Keys.enemy_gold_drops_hash:
		key_name = "enemy_gold_drops"
	else:
		return 0.0

	var penalty := 0.0
	for effect in character.effects:
		if effect == null:
			continue

		var matches: bool = effect.key_hash == effect_key_hash
		if not matches and effect.key == key_name:
			matches = true

		if matches and float(effect.value) < 0.0:
			penalty += float(effect.value)

	return penalty


func _cmf_has_any_personal_material_penalty() -> bool:
	for player_index in range(get_player_count()):
		if _cmf_get_personal_penalty(Keys.gold_drops_hash, player_index) < 0.0:
			return true
		if _cmf_get_personal_penalty(Keys.enemy_gold_drops_hash, player_index) < 0.0:
			return true

	return false


func _cmf_effect_value_as_float(value) -> float:
	if typeof(value) == TYPE_REAL or typeof(value) == TYPE_INT:
		return float(value)

	return 0.0


# Average of all effects that remain SHARED after removing each player's
# personal character penalty. This mirrors Main.get_gold_value().
func _cmf_get_shared_effect(source: int) -> float:
	var count := get_player_count()
	if count <= 0:
		return 0.0

	var total := 0.0
	for player_index in range(count):
		var general := _cmf_effect_value_as_float(get_player_effect(Keys.gold_drops_hash, player_index))
		general -= _cmf_get_personal_penalty(Keys.gold_drops_hash, player_index)
		total += general

		if source == CMF_SOURCE_ENEMY:
			var enemy := _cmf_effect_value_as_float(get_player_effect(Keys.enemy_gold_drops_hash, player_index))
			enemy -= _cmf_get_personal_penalty(Keys.enemy_gold_drops_hash, player_index)
			total += enemy
		elif source == CMF_SOURCE_NEUTRAL:
			# neutral_gold_drops is intentionally NOT localized by this mod.
			total += _cmf_effect_value_as_float(get_player_effect(Keys.neutral_gold_drops_hash, player_index))

	return total / float(count)


func _cmf_get_personal_multiplier(player_index: int, source: int) -> float:
	var general_penalty := _cmf_get_personal_penalty(
		Keys.gold_drops_hash,
		player_index
	)

	var source_penalty := 0.0
	if source == CMF_SOURCE_ENEMY:
		source_penalty = _cmf_get_personal_penalty(
			Keys.enemy_gold_drops_hash,
			player_index
		)

	var personal_penalty := general_penalty + source_penalty
	if personal_penalty >= 0.0:
		return 1.0

	var shared_effect := _cmf_get_shared_effect(source)

	# Main.get_gold_value first applies the co-op material factor, then the
	# drop-rate effect, then floors the result at 50% of original base_value.
	var coop_base := 1.0 + float(CoopService.get_coop_materials_factor())

	var spawned_factor := coop_base * (1.0 + shared_effect / 100.0)
	spawned_factor = max(spawned_factor, 0.5)

	var personal_factor := coop_base * (
		1.0 + (shared_effect + personal_penalty) / 100.0
	)
	personal_factor = max(personal_factor, 0.5)

	if spawned_factor <= 0.0:
		return 1.0

	return clamp(personal_factor / spawned_factor, 0.0, 1.0)


func _cmf_normalize_source_array(sources: Array) -> Array:
	var result := [0, 0, 0]

	for source in range(min(CMF_SOURCE_COUNT, sources.size())):
		result[source] = max(0, int(sources[source]))

	if result[0] + result[1] + result[2] <= 0:
		result[CMF_SOURCE_OTHER] = 1

	return result
