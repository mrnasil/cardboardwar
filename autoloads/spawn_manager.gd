extends Node
# Staggered Spawn Manager - OPTIMIZE.md'ye göre
# Not: class_name kaldırıldı - autoload singleton ile çakışmayı önlemek için
# Waves'i frame'lere yay, spike önle

var spawn_queue: Array[Dictionary] = []  # {scene, position, delay}
var spawn_timer := 0.0
var base_spawn_delay := 0.1  # 0.1s base delay (OPTIMIZE.md)

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# Pause durumunda spawn etme
	if get_tree().paused:
		return
	
	if spawn_queue.is_empty():
		spawn_timer = 0.0  # Queue boşsa timer'ı sıfırla
		return
	
	spawn_timer += delta
	
	# İlk spawn item'ı kontrol et
	var first_item = spawn_queue[0]
	var required_delay = first_item.get("delay", 0.0)
	
	# Gerekli delay geçtiyse spawn et
	if spawn_timer >= required_delay:
		# Timer'ı bu item'ın delay'ini çıkararak güncelle (biriken delay'i koru)
		spawn_timer -= required_delay
		spawn_next()

func queue_spawn(scene: PackedScene, position: Vector2, delay: float = 0.0, wave_number: int = 1, difficulty: float = 1.0) -> void:
	spawn_queue.append({
		"scene": scene,
		"position": position,
		"delay": delay,
		"wave_number": wave_number,
		"difficulty": difficulty
	})

func clear_queue() -> void:
	spawn_queue.clear()
	spawn_timer = 0.0

func spawn_next() -> void:
	if spawn_queue.is_empty():
		return
	
	var spawn_data = spawn_queue.pop_front()
	var scene = spawn_data.get("scene") as PackedScene
	var position = spawn_data.get("position") as Vector2
	var wave_number = spawn_data.get("wave_number", 1)
	var difficulty = spawn_data.get("difficulty", 1.0)
	
	if not scene:
		return
	
	# ObjectPool kullan
	var enemy: Enemy = null
	if has_node("/root/ObjectPool"):
		var pool = get_node("/root/ObjectPool")
		enemy = pool.get_enemy()
		if not enemy:
			enemy = scene.instantiate() as Enemy
	else:
		enemy = scene.instantiate() as Enemy
	
	if enemy:
		enemy.global_position = position
		# Düşman stats'larını wave numarası ve zorluk seviyesine göre ayarla
		_scale_enemy_to_difficulty(enemy, wave_number, difficulty)
		if get_tree().current_scene:
			get_tree().current_scene.add_child(enemy)

func _scale_enemy_to_difficulty(enemy: Enemy, wave_number: int, difficulty: float) -> void:
	if not enemy or not enemy.stats:
		return
	
	# Base stats'ları al (orijinal değerler)
	var base_health = enemy.stats.health
	var base_damage = enemy.stats.damage
	var base_speed = enemy.stats.speed
	
	# Wave numarası ve zorluk seviyesine göre düşman stats'larını ölçekle
	# Her wave için %20 artış, zorluk seviyesi ile çarpılıyor
	var wave_multiplier = 1.0 + (wave_number - 1) * 0.20
	var difficulty_multiplier = difficulty
	
	var total_multiplier = wave_multiplier * difficulty_multiplier
	
	# Stats'ı güncelle
	enemy.stats.health = int(base_health * total_multiplier)
	enemy.stats.damage = base_damage * total_multiplier
	enemy.stats.speed = base_speed * (1.0 + (wave_number - 1) * 0.05)  # Hız daha az artar
	
	# Health component'i güncelle
	if enemy.health_component:
		enemy.health_component.setup(enemy.stats)

func spawn_immediate(scene: PackedScene, position: Vector2) -> Enemy:
	var enemy: Enemy = null
	if has_node("/root/ObjectPool"):
		var pool = get_node("/root/ObjectPool")
		enemy = pool.get_enemy()
		if not enemy:
			enemy = scene.instantiate() as Enemy
	else:
		enemy = scene.instantiate() as Enemy
	
	if enemy:
		enemy.global_position = position
		get_tree().current_scene.add_child(enemy)
	
	return enemy

