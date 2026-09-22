extends "res://main.gd"

# Coop Material Fix 1.3.0
#
# Source ids are deliberately local to this mod:
#   OTHER   = generic/direct world material source
#   ENEMY   = enemy loot
#   NEUTRAL = trees / neutral units / player-requested material spawns
#
# We track composition because the 50-material cap can merge different sources into
# one blob, and bonus-gold can carry those mixed materials into the next wave.

const CMF_SOURCE_OTHER := 0
const CMF_SOURCE_ENEMY := 1
const CMF_SOURCE_NEUTRAL := 2
const CMF_SOURCE_COUNT := 3

var _cmf_pending_source := CMF_SOURCE_OTHER
var _cmf_adjust_world_drop_value := false

# instance_id -> [other, enemy, neutral]
var _cmf_gold_sources := {}

# Composition of RunData.bonus_gold (uncollected materials carried to a later wave).
var _cmf_bonus_sources := [0, 0, 0]


func _cmf_fix_active() -> bool:
	return (
		RunData.is_coop_run
		and RunData.get_player_count() > 1
		and bool(RunData.call("_cmf_has_any_personal_material_penalty"))
	)


func _cmf_source_from_entity_type(entity_type: int) -> int:
	if entity_type == EntityType.ENEMY:
		return CMF_SOURCE_ENEMY
	if entity_type == EntityType.NEUTRAL:
		return CMF_SOURCE_NEUTRAL
	return CMF_SOURCE_OTHER


# These two wrappers give spawn_gold() a reliable source without changing the
# game's public spawn_gold(value, pos, spread) signature.
func spawn_loot(unit: Unit, entity_type: int, args: Entity.DieArgs) -> void:
	if not _cmf_fix_active():
		.spawn_loot(unit, entity_type, args)
		return

	var old_source := _cmf_pending_source
	var old_adjust := _cmf_adjust_world_drop_value
	_cmf_pending_source = _cmf_source_from_entity_type(entity_type)
	_cmf_adjust_world_drop_value = true

	.spawn_loot(unit, entity_type, args)

	_cmf_pending_source = old_source
	_cmf_adjust_world_drop_value = old_adjust


func on_player_wanted_to_spawn_gold(value: int, pos: Vector2, spread: int) -> void:
	if not _cmf_fix_active():
		.on_player_wanted_to_spawn_gold(value, pos, spread)
		return

	var old_source := _cmf_pending_source
	var old_adjust := _cmf_adjust_world_drop_value
	_cmf_pending_source = CMF_SOURCE_NEUTRAL
	_cmf_adjust_world_drop_value = true

	.on_player_wanted_to_spawn_gold(value, pos, spread)

	_cmf_pending_source = old_source
	_cmf_adjust_world_drop_value = old_adjust


# Vanilla averages gold_drops / enemy_gold_drops over the party in this method.
# During ACTUAL world-drop creation, temporarily remove only the negative
# CHARACTER-owned part from that shared average. All other modifiers remain.
#
# Important: get_gold_value() is also used by a direct harvesting calculation.
# _cmf_adjust_world_drop_value keeps that non-drop call completely vanilla.
func get_gold_value(
	entity_type: int,
	args: Entity.DieArgs,
	base_value: float,
	unit: Unit = null
) -> float:
	if not _cmf_fix_active() or not _cmf_adjust_world_drop_value:
		return .get_gold_value(entity_type, args, base_value, unit)

	var saved := []

	for player_index in RunData.get_player_count():
		var effects: Dictionary = RunData.get_player_effects(player_index)

		var general_penalty := float(
			RunData.call("_cmf_get_personal_penalty", Keys.gold_drops_hash, player_index)
		)
		if general_penalty < 0.0:
			saved.push_back([effects, Keys.gold_drops_hash, effects[Keys.gold_drops_hash]])
			# penalty is negative; subtracting it restores the non-personal portion.
			effects[Keys.gold_drops_hash] = float(effects[Keys.gold_drops_hash]) - general_penalty

		if entity_type == EntityType.ENEMY:
			var enemy_penalty := float(
				RunData.call("_cmf_get_personal_penalty", Keys.enemy_gold_drops_hash, player_index)
			)
			if enemy_penalty < 0.0:
				saved.push_back([effects, Keys.enemy_gold_drops_hash, effects[Keys.enemy_gold_drops_hash]])
				effects[Keys.enemy_gold_drops_hash] = float(effects[Keys.enemy_gold_drops_hash]) - enemy_penalty

	var result := .get_gold_value(entity_type, args, base_value, unit)

	for entry in saved:
		entry[0][entry[1]] = entry[2]

	return result


# Re-expresses vanilla spawn_gold with source bookkeeping added.
# Solo / unaffected co-op delegates straight to vanilla.
func spawn_gold(value: float, pos: Vector2, spread: int) -> void:
	if not _cmf_fix_active():
		.spawn_gold(value, pos, spread)
		return

	var source := _cmf_pending_source
	var value_floored := int(value)
	var residual_chance := value - value_floored
	var spawn_count := value_floored
	if Utils.get_chance_success(residual_chance):
		spawn_count += 1

	for _i in range(spawn_count):
		# At the on-ground cap, vanilla adds one material to a random existing blob.
		if _active_golds.size() >= MAX_GOLDS:
			var merged_gold = Utils.get_rand_element(_active_golds)
			merged_gold.value += Gold.INITIAL_VALUE
			merged_gold.scale = Vector2(
				min(merged_gold.scale.x + Gold.INITIAL_VALUE * 0.05, Gold.MAX_SIZE),
				min(merged_gold.scale.y + Gold.INITIAL_VALUE * 0.05, Gold.MAX_SIZE)
			)
			_cmf_add_source(merged_gold, source, int(Gold.INITIAL_VALUE))
			continue

		var gold = get_node_from_pool(_gold_pool_id, _materials_container)
		if gold == null:
			gold = gold_scene.instance()
			_materials_container.call_deferred("add_child", gold)
			var _error = gold.connect("picked_up", self, "on_gold_picked_up")
			_error = gold.connect("picked_up", _effects_manager, "on_gold_picked_up")
			_error = gold.connect("picked_up", _floating_text_manager, "on_gold_picked_up")
			yield(gold, "ready")

		# A pooled node is a new logical material blob: never retain its old source.
		_cmf_reset_gold_sources(gold)

		# The node's current value is the value created by this spawn iteration
		# (normally Gold.INITIAL_VALUE == 1).
		_cmf_add_source(gold, source, int(gold.value))

		# Uncollected bonus materials are attached to the next newly spawned blob.
		if RunData.bonus_gold > 0:
			_cmf_sync_bonus_sources()

			var gold_value := int(gold.value)
			var bonus_to_add := int(min(gold.value, RunData.bonus_gold))
			var bonus_part: Array = _cmf_take_bonus_sources(bonus_to_add)

			gold.value += bonus_to_add
			_cmf_add_source_vector(gold, bonus_part)

			gold.boosted = 2
			gold.scale.x = 1.25
			gold.scale.y = 1.25
			RunData.remove_bonus_gold(gold_value)

			# remove_bonus_gold() is authoritative. Keep bookkeeping aligned if
			# another mod changes bonus-gold behavior.
			_cmf_sync_bonus_sources()

		gold.set_texture(gold_sprites.pick_random())
		gold.already_picked_up = false

		var dist = rand_range(50, 100 + spread)
		var push_back_destination = ZoneService.get_rand_pos_in_area(pos, dist, 0)
		gold.drop(pos, rand_range(0, 2 * PI), push_back_destination)
		_active_golds.push_back(gold)

		for player in _get_shuffled_live_players():
			var instant_gold_attracting = RunData.get_player_effect(
				Keys.instant_gold_attracting_hash,
				player.player_index
			)
			if instant_gold_attracting != 0 and randf() < instant_gold_attracting / 100.0:
				if (
					RunData.get_player_effect_bool(
						Keys.stat_has_lootworm_hash,
						player.player_index
					)
					and _entity_spawner.lootworms[player.player_index] != null
				):
					gold.attracted_by = _entity_spawner.lootworms[player.player_index]
				else:
					gold.attracted_by = player
				gold.set_physics_process(true)
				break

	emit_signal("gold_spawned")


func on_gold_picked_up(gold: Node, player_index: int) -> void:
	if gold.already_picked_up:
		.on_gold_picked_up(gold, player_index)
		return

	var gold_id := gold.get_instance_id()
	var original_value := int(gold.value)
	var sources: Array = _cmf_get_gold_sources(gold, original_value)

	# Normal player pickup: let vanilla calculate picker bonuses and round-robin
	# shares, while RunData captures only that final add_gold/add_xp block.
	if _cmf_fix_active() and player_index >= 0:
		RunData.call("_cmf_begin_material_pickup", sources)
		.on_gold_picked_up(gold, player_index)
		RunData.call("_cmf_end_material_pickup")
		_cmf_gold_sources.erase(gold_id)
		return

	# End-of-wave bagging: retain the composition that actually lands in
	# RunData.bonus_gold. If Builder consumes it immediately, stored_delta is 0,
	# so nothing is carried into the next wave.
	if _cmf_fix_active() and player_index < 0 and _cleaning_up:
		var before_bonus := int(RunData.bonus_gold)
		.on_gold_picked_up(gold, player_index)
		var stored_delta := max(0, int(RunData.bonus_gold) - before_bonus)

		if stored_delta > 0:
			var stored_sources: Array = _cmf_scale_sources_to_total(sources, stored_delta)
			_cmf_add_bonus_source_vector(stored_sources)
			_cmf_sync_bonus_sources()

		_cmf_gold_sources.erase(gold_id)
		return

	.on_gold_picked_up(gold, player_index)
	_cmf_gold_sources.erase(gold_id)


# The optimized cleanup path converts all floor materials into one scalar and
# bypasses on_gold_picked_up(), losing their source identity. Temporarily force
# the normal <=50-node bagging path only while this fix is active. The setting
# is restored immediately after the parent has passed the cleanup branch.
#
# This also leaves Builder's own conversion logic fully vanilla; the only change
# is that teammate penalties no longer removed those materials at spawn time.
func clean_up_room() -> void:
	if not _cmf_fix_active() or not ProgressData.settings.optimize_end_waves:
		.clean_up_room()
		return

	var old_optimize = ProgressData.settings.optimize_end_waves
	ProgressData.settings.optimize_end_waves = false
	.clean_up_room()
	ProgressData.settings.optimize_end_waves = old_optimize


func _cmf_empty_sources() -> Array:
	return [0, 0, 0]


func _cmf_reset_gold_sources(gold: Node) -> void:
	_cmf_gold_sources[gold.get_instance_id()] = _cmf_empty_sources()


func _cmf_get_gold_sources(gold: Node, fallback_total: int) -> Array:
	var gold_id := gold.get_instance_id()
	if _cmf_gold_sources.has(gold_id):
		var known: Array = _cmf_gold_sources[gold_id].duplicate()
		return _cmf_scale_sources_to_total(known, fallback_total)

	# Unknown/custom material source: fail safe as OTHER. General personal
	# penalties still work; enemy-only penalties are never applied by guesswork.
	return [fallback_total, 0, 0]


func _cmf_add_source(gold: Node, source: int, amount: int) -> void:
	if amount <= 0:
		return

	var gold_id := gold.get_instance_id()
	if not _cmf_gold_sources.has(gold_id):
		_cmf_gold_sources[gold_id] = _cmf_empty_sources()

	var sources: Array = _cmf_gold_sources[gold_id]
	sources[source] += amount
	_cmf_gold_sources[gold_id] = sources


func _cmf_add_source_vector(gold: Node, part: Array) -> void:
	for source in range(CMF_SOURCE_COUNT):
		_cmf_add_source(gold, source, int(part[source]))


func _cmf_add_bonus_source_vector(part: Array) -> void:
	for source in range(CMF_SOURCE_COUNT):
		_cmf_bonus_sources[source] += int(part[source])


func _cmf_sources_total(sources: Array) -> int:
	var total := 0
	for source in range(CMF_SOURCE_COUNT):
		total += int(sources[source])
	return total


func _cmf_scale_sources_to_total(sources: Array, target_total: int) -> Array:
	var result: Array = _cmf_empty_sources()
	if target_total <= 0:
		return result

	var current_total := _cmf_sources_total(sources)
	if current_total <= 0:
		result[CMF_SOURCE_OTHER] = target_total
		return result

	# Largest-remainder integer scaling keeps the sum exact and avoids steadily
	# biasing one source when a mixed blob is resized by outside behavior.
	var fractions := []
	var assigned := 0

	for source in range(CMF_SOURCE_COUNT):
		var exact := float(sources[source]) * float(target_total) / float(current_total)
		var base := int(floor(exact))
		result[source] = base
		assigned += base
		fractions.push_back([exact - base, source])

	fractions.sort_custom(self, "_cmf_sort_fraction_desc")

	var remaining := target_total - assigned
	for i in range(remaining):
		result[int(fractions[i % fractions.size()][1])] += 1

	return result


func _cmf_sort_fraction_desc(a, b) -> bool:
	return float(a[0]) > float(b[0])


func _cmf_sync_bonus_sources() -> void:
	var scalar_total := int(RunData.bonus_gold)
	var tracked_total := _cmf_sources_total(_cmf_bonus_sources)

	if tracked_total == scalar_total:
		return

	if tracked_total < scalar_total:
		# Unknown bonus materials from another mod / an old save are classified
		# as OTHER rather than guessed to be enemy drops.
		_cmf_bonus_sources[CMF_SOURCE_OTHER] += scalar_total - tracked_total
		return

	_cmf_bonus_sources = _cmf_scale_sources_to_total(_cmf_bonus_sources, scalar_total)


func _cmf_take_bonus_sources(amount: int) -> Array:
	_cmf_sync_bonus_sources()

	var result: Array = _cmf_empty_sources()
	if amount <= 0:
		return result

	var available := _cmf_sources_total(_cmf_bonus_sources)
	var to_take := min(amount, available)

	if to_take > 0:
		result = _cmf_scale_sources_to_total(_cmf_bonus_sources, to_take)

		for source in range(CMF_SOURCE_COUNT):
			_cmf_bonus_sources[source] -= int(result[source])

	# If scalar bonus somehow exceeds tracked composition, fill unknown as OTHER.
	if amount > to_take:
		result[CMF_SOURCE_OTHER] += amount - to_take

	return result
