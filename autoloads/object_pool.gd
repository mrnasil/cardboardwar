extends Node
# Object Pooling sistemi - Enemy ve FloatingText için
# Not: class_name kaldırıldı - autoload singleton ile çakışmayı önlemek için
# OPTIMIZE.md'ye göre: 5-10x CPU kazancı

const Cardboard = preload("res://scenes/ui/coin.gd")
const Tape = preload("res://scenes/ui/tape.gd")

var enemy_pool: Array[Enemy] = []
var floating_text_pool: Array[FloatingText] = []
var cardboard_pool: Array[Cardboard] = []
var tape_pool: Array[Tape] = []

# Enemy collision değerlerini saklamak için (pool'dan çıkarırken geri yüklemek için)
var enemy_collision_data: Dictionary = {}  # enemy.get_instance_id() -> {node_path: {layer: int, mask: int}}

@export var max_pool_size := 500  # Enemy cap
@export var floating_text_pool_size := 50
@export var cardboard_pool_size := 100
@export var tape_pool_size := 50

var enemy_scene: PackedScene
var floating_text_scene: PackedScene
var cardboard_scene: PackedScene
var tape_scene: PackedScene

func _ready() -> void:
	floating_text_scene = Global.FLOATING_TEXT_SCENE
	cardboard_scene = preload("res://scenes/ui/coin.tscn")
	tape_scene = preload("res://scenes/ui/tape.tscn")

func set_enemy_scene(scene: PackedScene) -> void:
	enemy_scene = scene

# Enemy Pooling
func get_enemy() -> Enemy:
	if enemy_pool.size() > 0:
		var enemy = enemy_pool.pop_back()
		if not is_instance_valid(enemy):
			# Geçersiz enemy, yeni bir tane oluştur
			if enemy_scene:
				return enemy_scene.instantiate() as Enemy
			return null
		
		enemy.visible = true
		enemy.process_mode = Node.PROCESS_MODE_INHERIT
		# Collision'ları tekrar aktif et
		var enemy_id = enemy.get_instance_id()
		_enable_collision_objects(enemy, enemy_id, enemy)
		return enemy
	
	if enemy_scene:
		return enemy_scene.instantiate() as Enemy
	return null

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
	
	if enemy_pool.size() >= max_pool_size:
		# Enemy free edilmeden önce collision data'yı temizle
		var enemy_id = enemy.get_instance_id()
		if enemy_id in enemy_collision_data:
			enemy_collision_data.erase(enemy_id)
		enemy.queue_free()
		return
	
	# Physics callback sırasında disable edilemez, call_deferred kullan
	# Tüm disable işlemlerini deferred olarak yap
	# call_deferred StringName bekliyor, bu yüzden metod adını string olarak veriyoruz
	call_deferred("_disable_enemy_for_pool", enemy)
	enemy_pool.append(enemy)

func _disable_enemy_for_pool(enemy: Enemy) -> void:
	if not is_instance_valid(enemy):
		return
	
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
	
	if tape_pool.size() >= tape_pool_size:
		tape.queue_free()
		return
	
	tape.visible = false
	tape.process_mode = Node.PROCESS_MODE_DISABLED
	tape.is_collecting = false
	if tape.sprite:
		tape.sprite.visible = true
	tape_pool.append(tape)
