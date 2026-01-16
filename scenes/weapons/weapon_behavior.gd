extends Node2D
class_name WeaponBehavior

@export var weapon: Weapon

var critical := false

func _ready() -> void:
	# Eğer weapon set edilmemişse, parent'ı Weapon olarak ayarla
	if not weapon:
		var parent = get_parent()
		if parent is Weapon:
			weapon = parent as Weapon

func execute_attack() -> void:
	pass

func apply_life_steal() -> void:
	# Life steal'i weapon'dan sonra uygula
	if Global.player and Global.player.has_method("try_life_steal"):
		Global.player.try_life_steal()
	
func get_damage() -> float:
	if not weapon or not weapon.data or not weapon.data.stats:
		return 0.0
	
	if not Global.player or not Global.player.primary_stats:
		return 0.0
	
	var base_damage = weapon.data.stats.damage
	
	# Primary stats'a göre damage type'ı belirle
	var damage_type_multiplier = 1.0
	if weapon.data.type == ItemWeapon.WeaponType.MELEE:
		# Melee damage bonusu
		damage_type_multiplier = 1.0 + (Global.player.primary_stats.melee_damage / 100.0)
	elif weapon.data.type == ItemWeapon.WeaponType.RANGE:
		# Ranged damage bonusu
		damage_type_multiplier = 1.0 + (Global.player.primary_stats.ranged_damage / 100.0)
	
	# Elemental damage kontrolü (weapon class MAGE ise)
	if weapon.data.weapon_class == ItemWeapon.WeaponClass.MAGE:
		damage_type_multiplier = 1.0 + (Global.player.primary_stats.elemental_damage / 100.0)
	
	# Base damage'ı type multiplier ile çarp
	base_damage *= damage_type_multiplier
	
	# Global damage multiplier (her nokta %1 artış)
	var global_damage_multiplier = Global.player.primary_stats.get_damage_multiplier()
	base_damage *= global_damage_multiplier
	
	# Minimum damage 1
	base_damage = max(1.0, base_damage)
	
	# Class bonuslarından crit chance bonusunu al
	var total_crit_chance = weapon.data.stats.crit_chance
	
	# Primary stats crit chance bonusu
	total_crit_chance += Global.player.primary_stats.get_crit_chance_bonus()
	
	# Negatif crit chance durumunda base crit chance'tan çıkar
	if Global.player.primary_stats.crit_chance < 0.0:
		total_crit_chance = max(0.0, total_crit_chance + (Global.player.primary_stats.crit_chance / 100.0))
	
	# Class bonusları
	if Global.player and Global.player.class_bonuses:
		var class_bonuses = Global.player.class_bonuses
		if class_bonuses.has(weapon.data.weapon_class):
			var bonuses = class_bonuses[weapon.data.weapon_class]
			total_crit_chance += bonuses.get("crit_chance", 0.0)
	
	# Crit chance max %100
	total_crit_chance = min(1.0, total_crit_chance)
	
	# Crit kontrolü
	if Global.get_chance_sucess(total_crit_chance):
		critical = true
		base_damage = ceil(base_damage * weapon.data.stats.crit_damage)
	
	# Minimum damage 1
	base_damage = max(1.0, base_damage)
	
	return base_damage
