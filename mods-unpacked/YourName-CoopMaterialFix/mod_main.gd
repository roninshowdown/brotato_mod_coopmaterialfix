extends Node

const MOD_DIR_NAME := "YourName-CoopMaterialFix"
const LOG_NAME := "YourName-CoopMaterialFix:Main"

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


func _ready() -> void:
	ModLoaderLog.info("Ready", LOG_NAME)
