extends Node

# Shop Signals
signal shop_updated(items)
signal reroll_price_updated(price)
signal wallet_updated(current_cardboard)

# Item Pools
var all_items: Array[ItemBase] = []
var all_weapons: Array[ItemBase] = []
var available_items_pool: Array[ItemBase] = [] # Based on checks

# Shop State
var current_wave: int = 1
var reroll_count: int = 0
var max_shop_slots: int = 4
var current_shop_items: Array = [] # Contains Dictionary with {item, price, locked}
var locked_indices: Array[int] = []

# Base Parameters
const REROLL_BASE_PRICE = 20 # Can be adjusted
# Noir Arena Wiki: First Reroll Price: Rounddown(Wave Number * 0.75) + Reroll Increase

func _ready() -> void:
	_load_all_items()

func _load_all_items() -> void:
	# Recursively find all resources in res://resources/items/
	_scan_dir_for_items("res://resources/items/")
	print("ShopManager: Loaded ", all_items.size(), " items and ", all_weapons.size(), " weapons.")

func _scan_dir_for_items(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				if file_name != "." and file_name != "..":
					_scan_dir_for_items(path + "/" + file_name)
			else:
				# Export edilmiş build'lerde .tres dosyaları .tres.remap haline gelir
				var full_path = path + "/" + file_name
				var actual_res_path = full_path.replace(".remap", "")
				
				if actual_res_path.ends_with(".tres") or actual_res_path.ends_with(".res"):
					var resource = load(actual_res_path)
					if resource is ItemBase:
						_add_item_to_pools(resource)
			file_name = dir.get_next()
	else:
		print("ShopManager: Failed to open directory ", path)

func _add_item_to_pools(item: ItemBase) -> void:
	if item.item_type == ItemBase.ItemType.WEAPON:
		all_weapons.append(item)
	else:
		all_items.append(item)

func initialize_shop(wave: int) -> void:
	current_wave = wave
	reroll_count = 0
	
	# Keep locked items, clear others
	var old_shop_items = current_shop_items.duplicate()
	current_shop_items.clear()
	
	# Re-construct based on previous locks if they exist
	var slots_to_fill = max_shop_slots
	
	for i in range(old_shop_items.size()):
		if old_shop_items[i].get("locked", false):
			current_shop_items.append(old_shop_items[i])
			slots_to_fill -= 1
	
	# Fill remaining slots
	for i in range(slots_to_fill):
		var new_item_data = _generate_random_shop_item()
		current_shop_items.append(new_item_data)
	
	emit_signal("shop_updated", current_shop_items)
	emit_signal("reroll_price_updated", get_reroll_price())
	
	if is_instance_valid(Global.player):
		emit_signal("wallet_updated", Global.player.cardboard)

func reroll_shop() -> void:
	var price = get_reroll_price()
	if not is_instance_valid(Global.player):
		return
		
	if Global.player.cardboard < price:
		return # Not enough money
	
	# Deduct money
	if Global.player.spend_cardboard(price):
		reroll_count += 1
		
		# Refresh non-locked items
		var new_list = []
		for item_data in current_shop_items:
			if item_data.get("locked", false):
				new_list.append(item_data)
			else:
				new_list.append(_generate_random_shop_item())
		
		current_shop_items = new_list
		
		emit_signal("shop_updated", current_shop_items)
		emit_signal("reroll_price_updated", get_reroll_price())
		emit_signal("wallet_updated", Global.player.cardboard)

func get_reroll_price() -> int:
	# Noir Arena Formula:
	# Reroll Increase: Rounddown(0.40 * Wave Number) (Minimum of 1)
	# First Reroll Price: Rounddown(Wave Number * 0.75) + Reroll Increase
	var reroll_increase = max(1, floor(0.40 * current_wave))
	var base_price = floor(current_wave * 0.75) + reroll_increase
	
	return int(base_price + (reroll_count * reroll_increase))

func toggle_lock(index: int) -> void:
	if index >= 0 and index < current_shop_items.size():
		var is_locked = current_shop_items[index].get("locked", false)
		current_shop_items[index]["locked"] = !is_locked
		emit_signal("shop_updated", current_shop_items)

func buy_item(index: int) -> bool:
	if index < 0 or index >= current_shop_items.size():
		return false
	
	if not is_instance_valid(Global.player):
		return false
	
	var item_data = current_shop_items[index]
	var price = item_data.price
	
	if Global.player.spend_cardboard(price):
		# Apply item to player
		var item_res = item_data.item
		item_res.apply_primary_stats_modifiers(Global.player)
		
		if item_res.item_type == ItemBase.ItemType.WEAPON:
			Global.player.add_weapon(item_res)
		
		# Remove from shop slot
		current_shop_items.remove_at(index)
		
		emit_signal("shop_updated", current_shop_items)
		emit_signal("wallet_updated", Global.player.cardboard)
		return true
		
	return false

func _generate_random_shop_item() -> Dictionary:
	# Chance for Item: 65%, Weapon: 35%
	var is_weapon = randf() < 0.35
	
	if current_wave <= 2 and randf() < 0.5:
		is_weapon = true
		
	var pool = all_weapons if is_weapon else all_items
	if pool.is_empty():
		pool = all_items if is_weapon else all_weapons # Fallback
	
	if pool.is_empty():
		return {"name": "Empty", "price": 0, "item": null}
	
	# Pick random item
	var item = pool.pick_random() as ItemBase
	
	# Calculate Price
	var price = _calculate_item_price(item)
	
	return {
		"item": item,
		"price": price,
		"locked": false,
		"name": item.item_name
	}

func _calculate_item_price(item: ItemBase) -> int:
	# Final Price = (Base_Price + Wave + (Base_Price * 0.1 * Wave))
	var base = item.item_cost
	var wave = current_wave
	var price = base + wave + (base * 0.1 * wave)
	return int(floor(price))
