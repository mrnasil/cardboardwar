extends Node
# Wave Manager - Dalga yönetim sistemi

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal wave_timer_updated(time_remaining: float)
signal enemy_count_updated(count: int)

enum WaveState {
	WAITING, # Wave başlamadan önce bekleme
	ACTIVE, # Wave aktif
	COMPLETED # Wave tamamlandı
}

var current_wave: int = 0
var max_waves: int = 20 # Noir Arena: 20 wave
var wave_state: WaveState = WaveState.WAITING
var wave_timer: float = 0.0
var wave_duration: float = 60.0 # Wave süresi
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0

# Wave ayarları
var base_enemy_count: int = 10 # İlk wave'deki düşman sayısı
var enemy_count_per_wave: float = 1.15 # Her wave'de artış çarpanı

# Zorluk seviyesi (Danger Level)
var danger_level: int = 0 # 0-5 arası
var difficulty_increase_per_wave: float = 0.05 # Her wave'de zorluk artışı

# Elite ve Horde wave sistemi
var elite_waves: Array[int] = [] # Elite wave numaraları
var horde_waves: Array[int] = [] # Horde wave numaraları
var is_boss_wave: bool = false # Wave 20 boss wave mi?

# Spawn ayarları
var spawn_radius: float = 800.0 # Player'dan uzaklık
var spawn_delay: float = 0.3 # Her spawn arası gecikme (hızlandırıldı)

var player_ref: Node2D = null
var map_bounds: Rect2 = Rect2(-960, -1080, 1920, 2160) # Varsayılan harita sınırları

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# Pause durumunda çalışma
	if get_tree().paused:
		return
	
	if wave_state == WaveState.ACTIVE:
		wave_timer -= delta
		
		# Timer'ı 0'ın altına düşmesine izin verme
		if wave_timer < 0.0:
			wave_timer = 0.0
		
		# Timer güncellemesi
		wave_timer_updated.emit(wave_timer)
		
		# Enemy sayısını güncelle
		update_enemy_count()
		
		# Wave tamamlanma kontrolü
		check_wave_completion()

func start_wave(wave_number: int) -> void:
	current_wave = wave_number
	wave_state = WaveState.ACTIVE
	
	# Tüm sayımları sıfırla
	wave_timer = 0.0
	enemies_to_spawn = 0
	enemies_spawned = 0
	enemies_alive = 0
	is_boss_wave = false
	
	# Spawn queue'yu temizle
	if has_node("/root/SpawnManager"):
		var spawn_mgr = get_node("/root/SpawnManager")
		spawn_mgr.clear_queue()
	
	# Wave süresini hesapla (Noir Arena mantığı)
	# Wave 1: 20s
	# Wave 2-8: +5s artış (25, 30, 35, 40, 45, 50, 55)
	# Wave 9-19: 60s
	# Wave 20: 90s
	if wave_number == 1:
		wave_duration = 20.0
	elif wave_number <= 8:
		wave_duration = 20.0 + (wave_number - 1) * 5.0
	elif wave_number < 20:
		wave_duration = 60.0
	else: # Wave 20
		wave_duration = 90.0
		is_boss_wave = true
	
	wave_timer = wave_duration
	
	# Timer'ın başlangıç değerini UI'a gönder (hemen emit et)
	# Oyun paused olsa bile sinyal emit edilmeli
	wave_timer_updated.emit(wave_timer)
	
	# Düşman sayısını hesapla
	enemies_to_spawn = int(base_enemy_count * pow(enemy_count_per_wave, wave_number - 1))
	
	# Danger level'ı Global'den al
	if has_node("/root/Global"):
		var global = get_node("/root/Global")
		danger_level = global.selected_difficulty
	
	# Elite ve Horde wave'leri hesapla (sadece ilk wave'de)
	if wave_number == 1:
		calculate_elite_horde_waves()
	
	# Wave başladı sinyali
	wave_started.emit(wave_number)
	
	# Düşman spawn'ını başlat
	start_enemy_spawning(wave_number)

func start_enemy_spawning(wave_num: int) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		push_error("WaveManager: Player referansı yok!")
		return
	
	# Boss wave kontrolü
	if is_boss_wave:
		spawn_boss_wave()
		return
	
	# Elite veya Horde wave kontrolü
	var is_elite = wave_num in elite_waves
	var is_horde = wave_num in horde_waves
	
	# Enemy scene'lerini yükle
	var enemy_scenes = get_enemy_scenes()
	if enemy_scenes.is_empty():
		push_error("WaveManager: Enemy scene'leri bulunamadı!")
		return
	
	# Elite/Horde wave için düşman sayısını artır
	var enemy_multiplier = 1.0
	if is_elite:
		enemy_multiplier = 1.5 # Elite wave'de %50 daha fazla düşman
	elif is_horde:
		enemy_multiplier = 2.0 # Horde wave'de 2x düşman
	
	# Spawn pozisyonlarını hesapla ve queue'ya ekle
	var adjusted_enemy_count = int(enemies_to_spawn * enemy_multiplier)
	
	for i in range(adjusted_enemy_count):
		var spawn_position = get_random_spawn_position()
		var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
		var delay = i * spawn_delay
		
		if has_node("/root/SpawnManager"):
			var spawn_mgr = get_node("/root/SpawnManager")
			var difficulty = 1.0 + (wave_num - 1) * difficulty_increase_per_wave
			spawn_mgr.queue_spawn(enemy_scene, spawn_position, delay, wave_num, difficulty)
		else:
			# SpawnManager yoksa direkt spawn et
			var enemy = spawn_enemy_immediate(enemy_scene, spawn_position)
			if enemy:
				var difficulty = 1.0 + (wave_num - 1) * difficulty_increase_per_wave
				_scale_enemy_to_difficulty(enemy, wave_num, difficulty)
		
		enemies_spawned += 1
	
func get_enemy_scenes() -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	
	# Enemy scene'lerini yükle
	var enemy_paths = [
		"res://scenes/unit/enemy/enemy_chaser_slow.tscn", # Player'a koşar
		"res://scenes/unit/enemy/enemy_wanderer.tscn", # Random haritada yürür
		"res://scenes/unit/enemy/enemy_shooter.tscn", # Ateş eder
		"res://scenes/unit/enemy/enemy_splitter.tscn", # Bölünebilir
		"res://scenes/unit/enemy/enemy_charger.tscn",
		"res://scenes/unit/enemy/enemy_shooter.tscn"
	]
	
	for path in enemy_paths:
		if ResourceLoader.exists(path):
			var scene = load(path) as PackedScene
			if scene:
				scenes.append(scene)
	
	return scenes

func get_random_spawn_position() -> Vector2:
	if not player_ref or not is_instance_valid(player_ref):
		return Vector2.ZERO
	
	# Harita sınırları geçerli mi kontrol et
	if map_bounds.size.x <= 0 or map_bounds.size.y <= 0:
		push_error("WaveManager: Geçersiz harita sınırları! Player pozisyonu kullanılıyor.")
		return player_ref.global_position + Vector2.RIGHT.rotated(randf() * TAU) * spawn_radius
	
	# Harita sınırları içinde tamamen rastgele pozisyon
	# Düşmanlar harita kenarına gelebilir - margin yok
	var spawn_margin = 50.0 # Düşman yarıçapı kadar pay bırak
	var min_x = map_bounds.position.x + spawn_margin
	var max_x = map_bounds.position.x + map_bounds.size.x - spawn_margin
	var min_y = map_bounds.position.y + spawn_margin
	var max_y = map_bounds.position.y + map_bounds.size.y - spawn_margin
	
	# %70 şansla tamamen rastgele harita içinde pozisyon (kenarlara da gelebilir)
	# %30 şansla player'dan uzakta spawn
	if randf() < 0.7:
		# Tamamen rastgele harita içinde pozisyon - kenarlara da gelebilir
		var random_x = randf_range(min_x, max_x)
		var random_y = randf_range(min_y, max_y)
		return Vector2(random_x, random_y)
	else:
		# Player'dan belirli mesafede spawn (opsiyonel)
		var max_attempts = 10
		for attempt in range(max_attempts):
			var angle = randf() * TAU
			var distance = spawn_radius + randf_range(-100, 100)
			var candidate_pos = player_ref.global_position + Vector2.RIGHT.rotated(angle) * distance
			
			# Harita sınırları içinde mi kontrol et
			if candidate_pos.x >= min_x and candidate_pos.x <= max_x and \
			   candidate_pos.y >= min_y and candidate_pos.y <= max_y:
				return candidate_pos
	
	# Fallback: Harita içinde tamamen rastgele bir pozisyon döndür
	if max_x > min_x and max_y > min_y:
		var random_x = randf_range(min_x, max_x)
		var random_y = randf_range(min_y, max_y)
		return Vector2(random_x, random_y)
	else:
		# Harita çok küçükse, player pozisyonuna yakın bir yer döndür
		return player_ref.global_position + Vector2.RIGHT.rotated(randf() * TAU) * 300.0

func spawn_enemy_immediate(scene: PackedScene, position: Vector2) -> Enemy:
	if not scene:
		return null
	
	var enemy = scene.instantiate() as Enemy
	if enemy:
		enemy.global_position = position
		get_tree().current_scene.add_child(enemy)
	
	return enemy

func _scale_enemy_to_difficulty(enemy: Enemy, wave_number: int, difficulty: float) -> void:
	if not enemy or not enemy.stats:
		return
	
	# Wave numarası ve zorluk seviyesine göre düşman stats'larını ölçekle
	# Her wave için %10 artış, zorluk seviyesi ile çarpılıyor
	var wave_multiplier = 1.0 + (wave_number - 1) * 0.05
	var difficulty_multiplier = difficulty
	
	var total_multiplier = wave_multiplier * difficulty_multiplier
	
	# Base stats'ları al
	var base_health = enemy.stats.health
	var base_damage = enemy.stats.damage
	var base_speed = enemy.stats.speed
	
	# Stats'ı güncelle
	enemy.stats.health = int(base_health * total_multiplier)
	enemy.stats.damage = int(base_damage * total_multiplier)
	enemy.stats.speed = int(base_speed * (1.0 + (wave_number - 1) * 0.05)) # Hız daha az artar
	
	# Health component'i güncelle
	if enemy.health_component:
		enemy.health_component.setup(enemy.stats)

func update_enemy_count() -> void:
	if has_node("/root/EnemyManager"):
		var enemy_mgr = get_node("/root/EnemyManager")
		enemies_alive = enemy_mgr.get_active_enemy_count()
		enemy_count_updated.emit(enemies_alive)

func check_wave_completion() -> void:
	# Wave tamamlanma koşulları:
	# 1. Timer sıfıra ulaştı (düşmanlar ölse de ölmese de wave tamamlanır)
	# Noir Arena mantığı: Süre bittiğinde wave tamamlanır, kalan düşmanlar otomatik temizlenir
	var should_complete = false
	
	# Timer bitti mi?
	if wave_timer <= 0.0:
		# Süre doldu, wave tamamlanır (düşmanlar ölse de ölmese de)
		should_complete = true
	
	if should_complete and wave_state == WaveState.ACTIVE:
		# Kalan materyalleri (Cardboard) topla ve çantaya at
		_collect_remaining_materials_to_bag()

		# Kalan düşmanları temizle
		if enemies_alive > 0:
			if has_node("/root/EnemyManager"):
				var enemy_mgr = get_node("/root/EnemyManager")
				enemy_mgr.clear_all_enemies()
			enemies_alive = 0
		
		complete_wave()

func complete_wave() -> void:
	wave_state = WaveState.COMPLETED
	wave_completed.emit(current_wave)
	
	# Kısa bir bekleme sonrası bir sonraki wave'e geçilebilir
	# (Shop sistemi eklendiğinde burada shop açılacak)

func set_player(player: Node2D) -> void:
	player_ref = player

func set_map_bounds(bounds: Rect2) -> void:
	map_bounds = bounds

func get_current_wave() -> int:
	return current_wave

func get_wave_timer() -> float:
	return wave_timer

func get_enemies_alive() -> int:
	return enemies_alive

func get_wave_state() -> WaveState:
	return wave_state

func calculate_elite_horde_waves() -> void:
	elite_waves.clear()
	horde_waves.clear()
	
	# Danger 0-1: Elite/Horde wave yok
	if danger_level <= 1:
		return
	
	# Danger 2-3: 1 tane (wave 11-12)
	# Danger 4-5: 3 tane (wave 11-12, 14-15, 17-18)
	var challenging_wave_count = 1 if danger_level <= 3 else 3
	
	# İlk challenging wave: 11 veya 12
	var first_wave = 11 if randi() % 2 == 0 else 12
	var wave_type = _get_challenging_wave_type() # %40 Horde, %60 Elite
	if wave_type == "horde":
		horde_waves.append(first_wave)
	else:
		elite_waves.append(first_wave)
	
	# İkinci ve üçüncü challenging wave (sadece Danger 4-5)
	if challenging_wave_count >= 2:
		var second_wave = 14 if randi() % 2 == 0 else 15
		wave_type = _get_challenging_wave_type()
		if wave_type == "horde":
			horde_waves.append(second_wave)
		else:
			elite_waves.append(second_wave)
	
	if challenging_wave_count >= 3:
		# Üçüncü wave her zaman Elite (wave 17-18)
		var third_wave = 17 if randi() % 2 == 0 else 18
		elite_waves.append(third_wave)

func _get_challenging_wave_type() -> String:
	# %40 Horde, %60 Elite
	if randf() < 0.4:
		return "horde"
	return "elite"

func spawn_boss_wave() -> void:
	# Boss wave spawn (Wave 20)
	# TODO: Boss scene'lerini ekle
	# Şimdilik normal düşman spawn'ı yap
	start_enemy_spawning(20)

func reset() -> void:
	current_wave = 0
	wave_state = WaveState.WAITING
	wave_timer = 0.0
	enemies_to_spawn = 0
	enemies_spawned = 0
	enemies_alive = 0
	danger_level = 0
	elite_waves.clear()
	horde_waves.clear()
	is_boss_wave = false

func _collect_remaining_materials_to_bag() -> void:
	if not player_ref or not is_instance_valid(player_ref):
		return
		
	# Sahnedeki tüm Coin/Cardboard objelerini bul
	if not is_inside_tree():
		return
		
	var coins = get_tree().get_nodes_in_group("cardboard")
	if coins.is_empty():
		# Grup yoksa recursive ara (fallback)
		_collect_materials_recursive(get_tree().current_scene)
	else:
		for coin in coins:
			if is_instance_valid(coin):
				if coin.get("cardboard_value"):
					if "material_bag" in player_ref:
						player_ref.material_bag += coin.cardboard_value
				coin.queue_free()

func _collect_materials_recursive(node: Node) -> void:
	if not node: return
	
	for child in node.get_children():
		# Cardboard check: coin.gd scriptine sahip mi?
		if child.has_method("collect_cardboard") and child is Area2D:
			if child.get("cardboard_value"):
				if player_ref and "material_bag" in player_ref:
					player_ref.material_bag += child.cardboard_value
			child.queue_free()
		else:
			if child.get_child_count() > 0:
				_collect_materials_recursive(child)
