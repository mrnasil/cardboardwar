extends Control
class_name StatsTooltip

var title_label: Label = null
var stats_container: VBoxContainer = null
var background: Panel = null

var current_data: Dictionary = {}

func _ready() -> void:
	visible = false
	# Font'ları uygula
	call_deferred("_apply_fonts")

func _apply_fonts() -> void:
	await get_tree().process_frame
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)

func show_tooltip(data: Dictionary, p_position: Vector2 = Vector2.ZERO) -> void:
	current_data = data
	_update_content()
	
	# Pozisyonu ayarla
	if p_position != Vector2.ZERO:
		global_position = p_position
		# Ekran dışına taşmaması için clamp
		var viewport_size = get_viewport().get_visible_rect().size
		global_position.x = clamp(global_position.x, 0, viewport_size.x - size.x)
		global_position.y = clamp(global_position.y, 0, viewport_size.y - size.y)
	
	visible = true

func hide_tooltip() -> void:
	visible = false
	current_data.clear()

func _update_content() -> void:
	# Node'ları bul
	if not title_label:
		title_label = get_node_or_null("VBoxContainer/TitleLabel")
	if not stats_container:
		stats_container = get_node_or_null("VBoxContainer/StatsContainer")
	
	if not title_label or not stats_container:
		return
	
	# Title'ı ayarla
	if current_data.has("title"):
		title_label.text = current_data["title"]
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		title_label.text = "Stats"
	
	# Mevcut stat label'larını temizle
	for child in stats_container.get_children():
		child.queue_free()
	
	# Stats'ları ekle
	if current_data.has("stats"):
		var stats = current_data["stats"] as Array
		for stat in stats:
			_add_stat_label(stat)
	
	# Pozisyon ve boyutu güncellemek için bir frame bekle veya anında zorla
	_rescale_tooltip()

func _rescale_tooltip() -> void:
	# İçindekilere göre boyutu ayarla
	# VBoxContainer boyutu otomatik güncellenir, parent Control'ü ona göre ayarlayalım
	if stats_container:
		# Küçük bir gecikme gerekebilir ama şimdilik doğrudan deneyelim
		await get_tree().process_frame
		if is_instance_valid(self) and is_instance_valid(stats_container):
			var new_height = stats_container.get_parent().get_combined_minimum_size().y + 40
			size.y = new_height
			
			# Boyut değiştiği için pozisyonu tekrar clample
			var viewport_size = get_viewport().get_visible_rect().size
			global_position.x = clamp(global_position.x, 0, viewport_size.x - size.x)
			global_position.y = clamp(global_position.y, 0, viewport_size.y - size.y)

func _add_stat_label(stat_data: Dictionary) -> void:
	var label = Label.new()
	label.text = stat_data.get("text", "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 220 # Sabit genişlik, değişken yükseklik
	
	# Renk ayarla (pozitif/negatif)
	var color = Color.WHITE
	if stat_data.has("color"):
		color = stat_data["color"]
	elif stat_data.has("value"):
		var value = stat_data["value"]
		if value > 0:
			color = Color(0.5, 1.0, 0.5) # Yeşil
		elif value < 0:
			color = Color(1.0, 0.5, 0.5) # Kırmızı
	
	label.modulate = color
	
	# Font uygula
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		if font_mgr.text_font:
			label.add_theme_font_override("font", font_mgr.text_font)
	
	stats_container.add_child(label)

# Player stats göster
static func create_player_stats_data(player: Player) -> Dictionary:
	if not player or not player.primary_stats:
		return {}
	
	var stats = player.primary_stats
	var stats_list: Array[Dictionary] = []
	
	# Max HP
	stats_list.append({
		"text": "Max HP: %d" % int(stats.max_hp),
		"value": stats.max_hp
	})
	
	# HP Regeneration
	if stats.hp_regeneration > 0:
		var regen_per_sec = stats.get_hp_regeneration_per_second()
		stats_list.append({
			"text": "HP Regeneration: %.2f HP/s" % regen_per_sec,
			"value": stats.hp_regeneration
		})
	
	# Life Steal
	if stats.life_steal > 0:
		stats_list.append({
			"text": "Life Steal: %.1f%%" % stats.life_steal,
			"value": stats.life_steal
		})
	
	# Damage
	if stats.damage != 0:
		var multiplier = stats.get_damage_multiplier()
		stats_list.append({
			"text": "Damage: %.1f%% (x%.2f)" % [stats.damage, multiplier],
			"value": stats.damage
		})
	
	# Melee Damage
	if stats.melee_damage != 0:
		stats_list.append({
			"text": "Melee Damage: %.1f%%" % stats.melee_damage,
			"value": stats.melee_damage
		})
	
	# Ranged Damage
	if stats.ranged_damage != 0:
		stats_list.append({
			"text": "Ranged Damage: %.1f%%" % stats.ranged_damage,
			"value": stats.ranged_damage
		})
	
	# Elemental Damage
	if stats.elemental_damage != 0:
		stats_list.append({
			"text": "Elemental Damage: %.1f%%" % stats.elemental_damage,
			"value": stats.elemental_damage
		})
	
	# Attack Speed
	if stats.attack_speed != 0:
		var multiplier = stats.get_attack_speed_multiplier()
		stats_list.append({
			"text": "Attack Speed: %.1f%% (x%.2f)" % [stats.attack_speed, multiplier],
			"value": stats.attack_speed
		})
	
	# Crit Chance
	if stats.crit_chance != 0:
		stats_list.append({
			"text": "Crit Chance: %.1f%%" % stats.crit_chance,
			"value": stats.crit_chance
		})
	
	# Engineering
	if stats.engineering != 0:
		stats_list.append({
			"text": "Engineering: %.1f" % stats.engineering,
			"value": stats.engineering
		})
	
	# Range
	if stats.weapon_range != 0:
		stats_list.append({
			"text": "Range: %.1f" % stats.weapon_range,
			"value": stats.weapon_range
		})
	
	# Armor
	if stats.armor != 0:
		var reduction = stats.get_armor_damage_reduction() * 100.0
		stats_list.append({
			"text": "Armor: %.1f (%.1f%% reduction)" % [stats.armor, reduction],
			"value": stats.armor
		})
	
	# Dodge
	if stats.dodge != 0:
		var dodge_chance = stats.get_dodge_chance() * 100.0
		stats_list.append({
			"text": "Dodge: %.1f%%" % dodge_chance,
			"value": stats.dodge
		})
	
	# Speed
	if stats.speed != 0:
		var multiplier = stats.get_speed_multiplier()
		stats_list.append({
			"text": "Speed: %.1f%% (x%.2f)" % [stats.speed, multiplier],
			"value": stats.speed
		})
	
	# Luck
	if stats.luck != 0:
		stats_list.append({
			"text": "Luck: %.1f%%" % stats.luck,
			"value": stats.luck
		})
	
	# Harvesting
	if stats.harvesting != 0:
		stats_list.append({
			"text": "Harvesting: %.1f" % stats.harvesting,
			"value": stats.harvesting
		})
	
	return {
		"title": "Player Stats",
		"stats": stats_list
	}

# Weapon stats göster
static func create_weapon_stats_data(weapon: Weapon) -> Dictionary:
	if not weapon or not weapon.data or not weapon.data.stats:
		return {}
	
	var weapon_stats = weapon.data.stats
	var stats_list: Array[Dictionary] = []
	
	# Weapon name
	var weapon_name = weapon.data.item_name if weapon.data.item_name else "Weapon"
	
	# Base damage
	stats_list.append({
		"text": "Damage: %.1f" % weapon_stats.damage,
		"value": weapon_stats.damage,
		"color": Color.WHITE
	})
	
	# Crit chance
	if weapon_stats.crit_chance > 0:
		stats_list.append({
			"text": "Crit Chance: %.1f%%" % (weapon_stats.crit_chance * 100.0),
			"value": weapon_stats.crit_chance
		})
	
	# Crit damage
	if weapon_stats.crit_damage > 1.0:
		stats_list.append({
			"text": "Crit Damage: x%.1f" % weapon_stats.crit_damage,
			"value": weapon_stats.crit_damage
		})
	
	# Range
	stats_list.append({
		"text": "Range: %.1f" % weapon_stats.max_range,
		"value": weapon_stats.max_range
	})
	
	# Cooldown
	stats_list.append({
		"text": "Cooldown: %.2fs" % weapon_stats.cooldown,
		"value": - weapon_stats.cooldown # Negatif göster (düşük cooldown iyi)
	})
	
	# Life steal
	if weapon_stats.life_steal > 0:
		stats_list.append({
			"text": "Life Steal: %.1f%%" % (weapon_stats.life_steal * 100.0),
			"value": weapon_stats.life_steal
		})
	
	# Weapon level
	if weapon.data.weapon_level > 1:
		stats_list.append({
			"text": "Level: %d" % weapon.data.weapon_level,
			"value": weapon.data.weapon_level,
			"color": Color(1.0, 1.0, 0.5) # Sarı
		})
	
	return {
		"title": weapon_name,
		"stats": stats_list
	}

# ItemWeapon resource'undan stat datası oluştur
static func create_item_weapon_stats_data(weapon_data: ItemWeapon) -> Dictionary:
	if not weapon_data or not weapon_data.stats:
		return {}
	
	var weapon_stats = weapon_data.stats
	var stats_list: Array[Dictionary] = []
	
	# Weapon name
	var weapon_name = weapon_data.item_name if weapon_data.item_name else "Weapon"
	
	# Base damage
	stats_list.append({
		"text": "Damage: %.1f" % weapon_stats.damage,
		"value": weapon_stats.damage,
		"color": Color.WHITE
	})
	
	# Crit chance
	if weapon_stats.crit_chance > 0:
		stats_list.append({
			"text": "Crit Chance: %.1f%%" % (weapon_stats.crit_chance * 100.0),
			"value": weapon_stats.crit_chance
		})
	
	# Crit damage
	if weapon_stats.crit_damage > 1.0:
		stats_list.append({
			"text": "Crit Damage: x%.1f" % weapon_stats.crit_damage,
			"value": weapon_stats.crit_damage
		})
	
	# Range
	stats_list.append({
		"text": "Range: %.1f" % weapon_stats.max_range,
		"value": weapon_stats.max_range
	})
	
	# Cooldown
	stats_list.append({
		"text": "Cooldown: %.2fs" % weapon_stats.cooldown,
		"value": - weapon_stats.cooldown # Negatif göster (düşük cooldown iyi)
	})
	
	# Accuracy
	if weapon_stats.accuracy < 1.0:
		stats_list.append({
			"text": "Accuracy: %.1f%%" % (weapon_stats.accuracy * 100.0),
			"value": weapon_stats.accuracy
		})
	
	# Weapon level
	if weapon_data.weapon_level > 1:
		stats_list.append({
			"text": "Level: %d" % weapon_data.weapon_level,
			"value": weapon_data.weapon_level,
			"color": Color(1.0, 1.0, 0.5) # Sarı
		})
	
	return {
		"title": weapon_name,
		"stats": stats_list
	}

# Item stats göster
static func create_item_stats_data(item: ItemBase) -> Dictionary:
	if not item:
		return {}
	
	var stats_list: Array[Dictionary] = []
	
	# Item modifiers
	if item.max_hp_modifier != 0:
		stats_list.append({
			"text": "Max HP: %+.1f" % item.max_hp_modifier,
			"value": item.max_hp_modifier
		})
	
	if item.hp_regeneration_modifier != 0:
		stats_list.append({
			"text": "HP Regeneration: %+.1f" % item.hp_regeneration_modifier,
			"value": item.hp_regeneration_modifier
		})
	
	if item.life_steal_modifier != 0:
		stats_list.append({
			"text": "Life Steal: %+.1f%%" % item.life_steal_modifier,
			"value": item.life_steal_modifier
		})
	
	if item.damage_modifier != 0:
		stats_list.append({
			"text": "Damage: %+.1f" % item.damage_modifier,
			"value": item.damage_modifier
		})
	
	if item.melee_damage_modifier != 0:
		stats_list.append({
			"text": "Melee Damage: %+.1f" % item.melee_damage_modifier,
			"value": item.melee_damage_modifier
		})
	
	if item.ranged_damage_modifier != 0:
		stats_list.append({
			"text": "Ranged Damage: %+.1f" % item.ranged_damage_modifier,
			"value": item.ranged_damage_modifier
		})
	
	if item.elemental_damage_modifier != 0:
		stats_list.append({
			"text": "Elemental Damage: %+.1f" % item.elemental_damage_modifier,
			"value": item.elemental_damage_modifier
		})
	
	if item.attack_speed_modifier != 0:
		stats_list.append({
			"text": "Attack Speed: %+.1f%%" % item.attack_speed_modifier,
			"value": item.attack_speed_modifier
		})
	
	if item.crit_chance_modifier != 0:
		stats_list.append({
			"text": "Crit Chance: %+.1f%%" % item.crit_chance_modifier,
			"value": item.crit_chance_modifier
		})
	
	if item.engineering_modifier != 0:
		stats_list.append({
			"text": "Engineering: %+.1f" % item.engineering_modifier,
			"value": item.engineering_modifier
		})
	
	if item.range_modifier != 0:
		stats_list.append({
			"text": "Range: %+.1f" % item.range_modifier,
			"value": item.range_modifier
		})
	
	if item.armor_modifier != 0:
		stats_list.append({
			"text": "Armor: %+.1f" % item.armor_modifier,
			"value": item.armor_modifier
		})
	
	if item.dodge_modifier != 0:
		stats_list.append({
			"text": "Dodge: %+.1f%%" % item.dodge_modifier,
			"value": item.dodge_modifier
		})
	
	if item.speed_modifier != 0:
		stats_list.append({
			"text": "Speed: %+.1f%%" % item.speed_modifier,
			"value": item.speed_modifier
		})
	
	if item.luck_modifier != 0:
		stats_list.append({
			"text": "Luck: %+.1f%%" % item.luck_modifier,
			"value": item.luck_modifier
		})
	
	if item.harvesting_modifier != 0:
		stats_list.append({
			"text": "Harvesting: %+.1f" % item.harvesting_modifier,
			"value": item.harvesting_modifier
		})
	
	# Eğer hiç stat yoksa
	if stats_list.is_empty():
		stats_list.append({
			"text": "No stat modifiers",
			"value": 0,
			"color": Color(0.7, 0.7, 0.7)
		})
	
	return {
		"title": item.item_name if item.item_name else "Item",
		"stats": stats_list
	}
