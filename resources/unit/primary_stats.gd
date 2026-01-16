extends Resource
class_name PrimaryStats

# Max HP - Ölmeden önce alınabilecek hasar miktarı
@export var max_hp: float = 100.0

# HP Regeneration - Pasif iyileşme (1 HP per n seconds)
@export var hp_regeneration: float = 0.0

# Life Steal - Saldırılarda %x şans ile 1HP iyileşme
@export var life_steal: float = 0.0

# Damage - Tüm hasarları %1 artırır (her nokta için)
@export var damage: float = 0.0

# Melee Damage - Melee silahların base attack damage'ini modifiye eder
@export var melee_damage: float = 0.0

# Ranged Damage - Ranged silahların base attack damage'ini modifiye eder
@export var ranged_damage: float = 0.0

# Elemental Damage - Elemental silahların base attack damage'ini modifiye eder
@export var elemental_damage: float = 0.0

# Attack Speed - %x daha hızlı saldırı
@export var attack_speed: float = 0.0

# Crit Chance - Kritik vuruş şansı artışı
@export var crit_chance: float = 0.0

# Engineering - Yapıların gücünü artırır
@export var engineering: float = 0.0

# Range - Silah menzilini artırır
@export var weapon_range: float = 0.0

# Armor - Gelen hasarı %x azaltır
@export var armor: float = 0.0

# Dodge - Saldırıları %x şans ile kaçırma
@export var dodge: float = 0.0

# Speed - Hareket hızı %x artışı
@export var speed: float = 0.0

# Luck - Item bulma şansı ve nadirlik artışı
@export var luck: float = 0.0

# Harvesting - Wave sonunda material ve XP kazancı
@export var harvesting: float = 0.0

# Stat modifier fonksiyonları
func add_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"max_hp": max_hp += value
		"hp_regeneration": hp_regeneration += value
		"life_steal": life_steal += value
		"damage": damage += value
		"melee_damage": melee_damage += value
		"ranged_damage": ranged_damage += value
		"elemental_damage": elemental_damage += value
		"attack_speed": attack_speed += value
		"crit_chance": crit_chance += value
		"engineering": engineering += value
		"range": weapon_range += value
		"armor": armor += value
		"dodge": dodge += value
		"speed": speed += value
		"luck": luck += value
		"harvesting": harvesting += value

func set_stat(stat_name: String, value: float) -> void:
	match stat_name:
		"max_hp": max_hp = value
		"hp_regeneration": hp_regeneration = value
		"life_steal": life_steal = value
		"damage": damage = value
		"melee_damage": melee_damage = value
		"ranged_damage": ranged_damage = value
		"elemental_damage": elemental_damage = value
		"attack_speed": attack_speed = value
		"crit_chance": crit_chance = value
		"engineering": engineering = value
		"range": weapon_range = value
		"armor": armor = value
		"dodge": dodge = value
		"speed": speed = value
		"luck": luck = value
		"harvesting": harvesting = value

func get_stat(stat_name: String) -> float:
	match stat_name:
		"max_hp": return max_hp
		"hp_regeneration": return hp_regeneration
		"life_steal": return life_steal
		"damage": return damage
		"melee_damage": return melee_damage
		"ranged_damage": return ranged_damage
		"elemental_damage": return elemental_damage
		"attack_speed": return attack_speed
		"crit_chance": return crit_chance
		"engineering": return engineering
		"range": return weapon_range
		"armor": return armor
		"dodge": return dodge
		"speed": return speed
		"luck": return luck
		"harvesting": return harvesting
		_: return 0.0

# HP Regeneration hesaplama
# İlk nokta: 0.20 HP/s, sonraki her nokta: +0.089 HP/s
func get_hp_regeneration_per_second() -> float:
	if hp_regeneration <= 0.0:
		return 0.0
	if hp_regeneration <= 1.0:
		return 0.20
	return 0.20 + (hp_regeneration - 1.0) * 0.089

# Life Steal şansı (0-1 arası)
func get_life_steal_chance() -> float:
	return max(0.0, life_steal / 100.0)

# Damage multiplier (her nokta %1 artış)
func get_damage_multiplier() -> float:
	return 1.0 + (damage / 100.0)

# Attack Speed multiplier (diminishing returns ve max 12 attacks/second)
func get_attack_speed_multiplier() -> float:
	if attack_speed <= 0.0:
		# Negatif attack speed farklı hesaplanır
		return 1.0 / (1.0 + abs(attack_speed) / 100.0)
	
	# Pozitif attack speed için diminishing returns
	var multiplier = 1.0 + (attack_speed / 100.0)
	# Max 12 attacks/second limiti (weapon cooldown'a göre uygulanacak)
	return multiplier

# Crit Chance (0-1 arası, max %100)
func get_crit_chance_bonus() -> float:
	return clamp(crit_chance / 100.0, 0.0, 1.0)

# Armor damage reduction (her nokta %6.66 daha fazla hasar gerektirir)
func get_armor_damage_reduction() -> float:
	if armor <= 0.0:
		# Negatif armor hasarı artırır
		return -abs(armor) / 100.0
	
	# Her 1 armor = %6.66 daha fazla efektif HP
	# 15 armor = %100 daha fazla efektif HP = %50 damage reduction
	# Formula: damage_reduction = armor / (armor + 15)
	# Bu formül Brotato'nun armor sistemine uygun
	return armor / (armor + 15.0)

# Dodge chance (0-1 arası, max %60 normal, %70 cryptid, %90 ghost)
func get_dodge_chance() -> float:
	return clamp(dodge / 100.0, 0.0, 0.6) # Default max %60

# Speed multiplier
func get_speed_multiplier() -> float:
	if speed <= -100.0:
		return 0.0 # -100% veya daha fazla durur
	return 1.0 + (speed / 100.0)

# Range bonus
func get_range_bonus() -> float:
	return max(weapon_range, -999.0) # Minimum 25 range (weapon'da kontrol edilecek)

# Luck multiplier
func get_luck_multiplier() -> float:
	return 1.0 + (luck / 100.0)

# Harvesting bonus
func get_harvesting_bonus() -> float:
	return harvesting

# Duplicate fonksiyonu
func duplicate_stats() -> PrimaryStats:
	var new_stats = PrimaryStats.new()
	new_stats.max_hp = max_hp
	new_stats.hp_regeneration = hp_regeneration
	new_stats.life_steal = life_steal
	new_stats.damage = damage
	new_stats.melee_damage = melee_damage
	new_stats.ranged_damage = ranged_damage
	new_stats.elemental_damage = elemental_damage
	new_stats.attack_speed = attack_speed
	new_stats.crit_chance = crit_chance
	new_stats.engineering = engineering
	new_stats.weapon_range = weapon_range
	new_stats.armor = armor
	new_stats.dodge = dodge
	new_stats.speed = speed
	new_stats.luck = luck
	new_stats.harvesting = harvesting
	return new_stats
