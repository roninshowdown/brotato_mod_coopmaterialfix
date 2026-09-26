extends Node

const MOD_DIR_NAME := "HunTTer-CoopMaterialFix"
const LOG_NAME := "HunTTer-CoopMaterialFix:Main"
const IMPROVED_TOOLTIPS_ID := "_wl-ImprovedTooltips"

var mod_dir_path := ""
var extensions_dir_path := ""


func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	extensions_dir_path = mod_dir_path.plus_file("extensions")

	ModLoaderLog.info("Init", LOG_NAME)

	ModLoaderMod.install_script_extension(
		extensions_dir_path.plus_file("singletons/run_data.gd")
	)
	ModLoaderMod.install_script_extension(
		extensions_dir_path.plus_file("items/global/effect_line.gd")
	)
	ModLoaderMod.install_script_extension(
		extensions_dir_path.plus_file("main.gd")
	)

	# ImprovedTooltips bypasses EffectLine._display_effect(), so the label needs a
	# second hook into its own text builder. Checked via ModLoaderStore directly:
	# mod_data/is_loadable are final before any _init() runs, and
	# ModLoaderMod.is_mod_loaded() warns when called during _init().
	if ModLoaderStore.mod_data.has(IMPROVED_TOOLTIPS_ID) and ModLoaderStore.mod_data[IMPROVED_TOOLTIPS_ID].is_loadable:
		ModLoaderLog.info("ImprovedTooltips detected, installing tooltip label hook", LOG_NAME)
		ModLoaderMod.install_script_extension(
			extensions_dir_path.plus_file("singletons/text_improved_tooltips.gd")
		)


func _ready() -> void:
	ModLoaderLog.info("Ready", LOG_NAME)
