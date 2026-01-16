extends Node
# Object Pooling sistemi - Enemy ve FloatingText için
# Not: class_name kaldırıldı - autoload singleton ile çakışmayı önlemek için
# OPTIMIZE.md'ye göre: 5-10x CPU kazancı


var enemy_pools: Dictionary = {} # scene_path -> Array[Enemy]
var floating_text_pool: Array[FloatingText] = []
var cardboard_pool: Array[Cardboard] = []
var tape_pool: Array[Tape] = []

# Enemy collision değerlerini saklamak için (pool'dan çıkarırken geri yüklemek için)
var enemy_collision_data: Dictionary = {} # enemy.get_instance_id() -> {node_path: {layer: int, mask: int}}

@export var max_pool_size_per_type := 100 # Her tip için cap
@export var floating_text_pool_size := 50
@export var cardboard_pool_size := 100
@export var tape_pool_size := 50

var floating_text_scene: PackedScene
var cardboard_scene: PackedScene
var tape_scene: PackedScene

func _ready() -> void:
	floating_text_scene = Global.FLOATING_TEXT_SCENE
	cardboard_scene = preload("res://scenes/ui/coin.tscn")
	tape_scene = preload("res://scenes/ui/tape.tscn")

# Enemy Pooling
func get_enemy(scene: PackedScene) -> Enemy:
	if not scene:
		return null
		
	var path = scene.resource_path
	if enemy_pools.has(path) and enemy_pools[path].size() > 0:
		var enemy = enemy_pools[path].pop_back()
		if is_instance_valid(enemy):
			enemy.reset_enemy()
			enemy.visible = true
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
			# Collision'ları tekrar aktif et
			var enemy_id = enemy.get_instance_id()
			_enable_collision_objects(enemy, enemy_id, enemy)
			
			# Re-register with EnemyManager if possible
			if has_node("/root/EnemyManager"):
				get_node("/root/EnemyManager").register_enemy(enemy)
				
			return enemy
	
	# Pool'da yoksa veya geçersizse yeni oluştur
	var new_enemy = scene.instantiate() as Enemy
	if new_enemy:
		new_enemy.set_meta("scene_path", path)
	return new_enemy

func _enable_collision_objects(node: Node, enemy_id: int, enemy_root: Node) -> void:
	if node is CollisionObject2D:
		# Node'un enemy root'a göre relative path'ini al
		var node_path = enemy_root.get_path_to(node)
		var path_str = str(node_path)
		# Kaydedilmiş collision değerlerini geri yükle
		if enemy_id in enemy_collision_data and path_str in enemy_collision_data[enemy_id]:
			var data = enemy_collision_data[enemy_id][path_str]
			node.set_collision_layer(data.layer)
			node.set_collision_mask(data.mask)
		else:
			# Eğer kayıt yoksa, scene'deki default değerleri kullan (zaten ayarlı)
			pass
	
	# Tüm child node'ları da kontrol et
	for child in node.get_children():
		_enable_collision_objects(child, enemy_id, enemy_root)

func return_enemy(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	
	var path = enemy.get_meta("scene_path", "")
	if path == "":
		enemy.queue_free()
		return
		
	# Physics callback sırasında node kaldırılamaz, call_deferred kullan
	var parent = enemy.get_parent()
	if parent:
		parent.call_deferred("remove_child", enemy)
	
	if not enemy_pools.has(path):
		enemy_pools[path] = []
		
	if enemy_pools[path].size() >= max_pool_size_per_type:
		# Enemy free edilmeden önce collision data'yı temizle
		var enemy_id = enemy.get_instance_id()
		if enemy_id in enemy_collision_data:
			enemy_collision_data.erase(enemy_id)
		enemy.queue_free()
		return
	
	call_deferred("_disable_enemy_for_pool", enemy)
	enemy_pools[path].append(enemy)

func _disable_enemy_for_pool(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	
	# Enemy'yi parent'ından çıkar (eğer hala varsa)
	var parent = enemy.get_parent()
	if parent:
		parent.remove_child(enemy)
	
	enemy.visible = false
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Tüm Area2D ve CollisionObject2D'leri devre dışı bırak ve değerlerini kaydet
	var enemy_id = enemy.get_instance_id()
	enemy_collision_data[enemy_id] = {}
	_disable_collision_objects(enemy, enemy_id, enemy)

func _disable_collision_objects(node: Node, enemy_id: int, enemy_root: Node) -> void:
	if node is CollisionObject2D:
		# Node'un enemy root'a göre relative path'ini al
		var node_path = enemy_root.get_path_to(node)
		var path_str = str(node_path)
		# Mevcut collision değerlerini kaydet
		enemy_collision_data[enemy_id][path_str] = {
			"layer": node.collision_layer,
			"mask": node.collision_mask
		}
		# Collision'ları devre dışı bırak
		node.set_collision_layer(0)
		node.set_collision_mask(0)
	
	# Tüm child node'ları da kontrol et
	for child in node.get_children():
		_disable_collision_objects(child, enemy_id, enemy_root)

# FloatingText Pooling
func get_floating_text() -> FloatingText:
	if floating_text_pool.size() > 0:
		var text = floating_text_pool.pop_back()
		text.visible = true
		text.process_mode = Node.PROCESS_MODE_INHERIT
		return text
	
	if floating_text_scene:
		return floating_text_scene.instantiate() as FloatingText
	return null

func return_floating_text(text: FloatingText) -> void:
	if not is_instance_valid(text):
		return
	
	if floating_text_pool.size() >= floating_text_pool_size:
		text.queue_free()
		return
	
	text.visible = false
	text.process_mode = Node.PROCESS_MODE_DISABLED
	text.modulate.a = 1.0
	text.scale = Vector2.ZERO
	floating_text_pool.append(text)

# Cardboard Pooling
func get_cardboard() -> Cardboard:
	if cardboard_pool.size() > 0:
		var cardboard = cardboard_pool.pop_back()
		if not is_instance_valid(cardboard):
			if cardboard_scene:
				return cardboard_scene.instantiate() as Cardboard
			return null
		
		cardboard.visible = true
		cardboard.process_mode = Node.PROCESS_MODE_INHERIT
		if cardboard.sprite:
			cardboard.sprite.visible = true
		return cardboard
	
	if cardboard_scene:
		return cardboard_scene.instantiate() as Cardboard
	return null

func return_cardboard(cardboard: Cardboard) -> void:
	if not is_instance_valid(cardboard):
		return
	
	# Cardboard'ı parent'ından çıkar (eğer varsa) - deferred olarak
	var parent = cardboard.get_parent()
	if parent:
		parent.call_deferred("remove_child", cardboard)
	
	if cardboard_pool.size() >= cardboard_pool_size:
		cardboard.queue_free()
		return
	
	cardboard.visible = false
	cardboard.process_mode = Node.PROCESS_MODE_DISABLED
	cardboard.is_collecting = false
	cardboard_pool.append(cardboard)

# Tape Pooling
func get_tape() -> Tape:
	if tape_pool.size() > 0:
		var tape = tape_pool.pop_back()
		if not is_instance_valid(tape):
			if tape_scene:
				return tape_scene.instantiate() as Tape
			return null
		
		tape.visible = true
		tape.process_mode = Node.PROCESS_MODE_INHERIT
		if tape.sprite:
			tape.sprite.visible = true
		return tape
	
	if tape_scene:
		return tape_scene.instantiate() as Tape
	return null

func return_tape(tape: Tape) -> void:
	if not is_instance_valid(tape):
		return
	
	# Tape'i parent'ından çıkar (eğer varsa) - deferred olarak
	var parent = tape.get_parent()
	if parent:
		parent.call_deferred("remove_child", tape)
	
	if tape_pool.size() >= tape_pool_size:
		tape.queue_free()
		return
	
	tape.visible = false
	tape.process_mode = Node.PROCESS_MODE_DISABLED
	tape.is_collecting = false
	if tape.sprite:
		tape.sprite.visible = true
	tape_pool.append(tape)

func _exit_tree() -> void:
	# Clean up pools to prevent memory leaks
	for pool in enemy_pools.values():
		for enemy in pool:
			if is_instance_valid(enemy):
				enemy.queue_free()
	enemy_pools.clear()
	enemy_collision_data.clear()
	
	for text in floating_text_pool:
		if is_instance_valid(text):
			text.queue_free()
	floating_text_pool.clear()
	
	for cardboard in cardboard_pool:
		if is_instance_valid(cardboard):
			cardboard.queue_free()
	cardboard_pool.clear()
	
	for tape in tape_pool:
		if is_instance_valid(tape):
			tape.queue_free()
	tape_pool.clear()
