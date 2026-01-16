extends Resource
class_name ItemBase

enum ItemType{
	WEAPON,
	UPGRADE,
	PASSIVE
}

@export var item_name:String
@export var item_icon:Texture2D
@export var item_tier:Global.UpgradeTier
@export var item_type:ItemType
@export var item_cost:int

# Primary Stats Modifiers
@export_group("Primary Stats Modifiers")
@export var max_hp_modifier: float = 0.0
@export var hp_regeneration_modifier: float = 0.0
@export var life_steal_modifier: float = 0.0
@export var damage_modifier: float = 0.0
@export var melee_damage_modifier: float = 0.0
@export var ranged_damage_modifier: float = 0.0
@export var elemental_damage_modifier: float = 0.0
@export var attack_speed_modifier: float = 0.0
@export var crit_chance_modifier: float = 0.0
@export var engineering_modifier: float = 0.0
@export var range_modifier: float = 0.0
@export var armor_modifier: float = 0.0
@export var dodge_modifier: float = 0.0
@export var speed_modifier: float = 0.0
@export var luck_modifier: float = 0.0
@export var harvesting_modifier: float = 0.0

func get_description() -> String:
	return ""

# Primary stats modifier'larını uygula
func apply_primary_stats_modifiers(player: Player) -> void:
	if not player or not player.primary_stats:
		return
	
	if max_hp_modifier != 0.0:
		player.modify_primary_stat("max_hp", max_hp_modifier)
	if hp_regeneration_modifier != 0.0:
		player.modify_primary_stat("hp_regeneration", hp_regeneration_modifier)
	if life_steal_modifier != 0.0:
		player.modify_primary_stat("life_steal", life_steal_modifier)
	if damage_modifier != 0.0:
		player.modify_primary_stat("damage", damage_modifier)
	if melee_damage_modifier != 0.0:
		player.modify_primary_stat("melee_damage", melee_damage_modifier)
	if ranged_damage_modifier != 0.0:
		player.modify_primary_stat("ranged_damage", ranged_damage_modifier)
	if elemental_damage_modifier != 0.0:
		player.modify_primary_stat("elemental_damage", elemental_damage_modifier)
	if attack_speed_modifier != 0.0:
		player.modify_primary_stat("attack_speed", attack_speed_modifier)
	if crit_chance_modifier != 0.0:
		player.modify_primary_stat("crit_chance", crit_chance_modifier)
	if engineering_modifier != 0.0:
		player.modify_primary_stat("engineering", engineering_modifier)
	if range_modifier != 0.0:
		player.modify_primary_stat("range", range_modifier)
	if armor_modifier != 0.0:
		player.modify_primary_stat("armor", armor_modifier)
	if dodge_modifier != 0.0:
		player.modify_primary_stat("dodge", dodge_modifier)
	if speed_modifier != 0.0:
		player.modify_primary_stat("speed", speed_modifier)
	if luck_modifier != 0.0:
		player.modify_primary_stat("luck", luck_modifier)
	if harvesting_modifier != 0.0:
		player.modify_primary_stat("harvesting", harvesting_modifier)
