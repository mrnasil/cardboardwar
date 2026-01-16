extends Node

@warning_ignore("unused_signal")
signal on_create_block_text(unit: Node2D)
@warning_ignore("unused_signal")
signal on_create_damage_text(unit: Node2D, hitbox: HitboxComponent)

const FLASH_MATERIAL = preload("uid://coi4nu8ohpgeo")
const FLOATING_TEXT_SCENE = preload("uid://cp86d6q6156la")

enum UpgradeTier {
	COMMON,
	RARE,
	EPIC,
	LEGENDARY
}

var player: Player
var has_active_game: bool = false # Yarıda kalmış oyun var mı?
var from_pause_menu: bool = false # Ayarlar menüsüne pause menüsünden mi geldik?
var endless_mode: bool = true # Sonsuz mod
var coop_mode: bool = false # Eşli mod
var selected_character: String = "" # Seçilen karakter scene yolu
var selected_difficulty: int = 0 # Seçilen zorluk seviyesi (0-5)
var selected_starting_item: Dictionary = {} # Seçilen ilk eşya

func get_chance_sucess(chance: float) -> bool:
	var random := randf_range(0, 1.0)
	if random < chance:
		return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R and event.ctrl_pressed:
		print("#####")
		get_tree().reload_current_scene()
