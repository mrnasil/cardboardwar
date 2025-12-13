extends Node
# Wave Manager - Dalga yönetim sistemi

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal wave_timer_updated(time_remaining: float)
signal enemy_count_updated(count: int)

enum WaveState {
	WAITING,    # Wave başlamadan önce bekleme
	ACTIVE,     # Wave aktif
	COMPLETED   # Wave tamamlandı
}

var current_wave: int = 0
var wave_state: WaveState = WaveState.WAITING
var wave_timer: float = 0.0
var wave_duration: float = 60.0  # Varsayılan 60 saniye (20-90 arası olabilir)
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0

# Wave ayarları
var base_enemy_count: int = 10  # İlk wave'deki düşman sayısı
var enemy_count_per_wave: float = 1.5  # Her wave'de artış çarpanı
var min_wave_duration: float = 20.0
var max_wave_duration: float = 90.0
var wave_duration_increase: float = 2.0  # Her wave'de süre artışı

# Zorluk seviyesi
var difficulty_level: int = 1  # Başlangıç zorluk seviyesi
var difficulty_increase_per_wave: float = 0.1  # Her wave'de zorluk artışı

# Spawn ayarları
var spawn_radius: float = 800.0  # Player'dan uzaklık
var spawn_delay: float = 0.2  # Her spawn arası gecikme

var player_ref: Node2D = null
var map_bounds: Rect2 = Rect2(-960, -1080, 1920, 2160)  # Varsayılan harita sınırları

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	# Pause durumunda çalışma
	if get_tree().paused:
		return
	
	if wave_state == WaveState.ACTIVE:
		wave_timer -= delta
		
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
	
	# Spawn queue'yu temizle
	if has_node("/root/SpawnManager"):
		var spawn_mgr = get_node("/root/SpawnManager")
		spawn_mgr.clear_queue()
	
	# Wave süresini hesapla (20-90 saniye arası, wave'e göre artar)
	wave_duration = clamp(
		min_wave_duration + (wave_number - 1) * wave_duration_increase,
		min_wave_duration,
		max_wave_duration
	)
	wave_timer = wave_duration
	
	# Timer'ın başlangıç değerini UI'a gönder (hemen emit et)
	# Oyun paused olsa bile sinyal emit edilmeli
	wave_timer_updated.emit(wave_timer)
	
	# Düşman sayısını hesapla
	enemies_to_spawn = int(base_enemy_count * pow(enemy_count_per_wave, wave_number - 1))
	
	# Zorluk seviyesini hesapla (wave numarasına göre)
	difficulty_level = 1.0 + (wave_number - 1) * difficulty_increase_per_wave
	
	# Wave başladı sinyali
	wave_started.emit(wave_number)
	
	# Düşman spawn'ını başlat
	start_enemy_spawning(wave_number)

func start_enemy_spawning(wave_num: int) -> void:
	if not player_ref or not is_instance_valid(player_ref):
		push_error("WaveManager: Player referansı yok!")
		return
	
	# Enemy scene'lerini yükle
	var enemy_scenes = get_enemy_scenes()
	if enemy_scenes.is_empty():
		push_error("WaveManager: Enemy scene'leri bulunamadı!")
		return
	
	# Spawn pozisyonlarını hesapla ve queue'ya ekle
	for i in range(enemies_to_spawn):
		var spawn_position = get_random_spawn_position()
		var enemy_scene = enemy_scenes[randi() % enemy_scenes.size()]
		var delay = i * spawn_delay
		
		if has_node("/root/SpawnManager"):
			var spawn_mgr = get_node("/root/SpawnManager")
			spawn_mgr.queue_spawn(enemy_scene, spawn_position, delay, wave_num, difficulty_level)
		else:
			# SpawnManager yoksa direkt spawn et
			var enemy = spawn_enemy_immediate(enemy_scene, spawn_position)
			if enemy:
				_scale_enemy_to_difficulty(enemy, wave_num, difficulty_level)
		
		enemies_spawned += 1

func get_enemy_scenes() -> Array[PackedScene]:
	var scenes: Array[PackedScene] = []
	
	# Enemy scene'lerini yükle
	var enemy_paths = [
		"res://scenes/unit/enemy/enemy_chaser_slow.tscn",
		"res://scenes/unit/enemy/enemy_chaser_mid.tscn",
		"res://scenes/unit/enemy/enemy_chaser_fast.tscn",
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
	var min_x = map_bounds.position.x
	var max_x = map_bounds.position.x + map_bounds.size.x
	var min_y = map_bounds.position.y
	var max_y = map_bounds.position.y + map_bounds.size.y
	
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
	# Her wave için %20 artış, zorluk seviyesi ile çarpılıyor
	var wave_multiplier = 1.0 + (wave_number - 1) * 0.20
	var difficulty_multiplier = difficulty
	
	var total_multiplier = wave_multiplier * difficulty_multiplier
	
	# Base stats'ları al
	var base_health = enemy.stats.health
	var base_damage = enemy.stats.damage
	var base_speed = enemy.stats.speed
	
	# Stats'ı güncelle
	enemy.stats.health = int(base_health * total_multiplier)
	enemy.stats.damage = base_damage * total_multiplier
	enemy.stats.speed = base_speed * (1.0 + (wave_number - 1) * 0.05)  # Hız daha az artar
	
	# Health component'i güncelle
	if enemy.health_component:
		enemy.health_component.setup(enemy.stats)

func update_enemy_count() -> void:
	if has_node("/root/EnemyManager"):
		var enemy_mgr = get_node("/root/EnemyManager")
		enemies_alive = enemy_mgr.get_active_enemy_count()
		enemy_count_updated.emit(enemies_alive)

func check_wave_completion() -> void:
	var should_complete = false
	
	# Timer bitti mi?
	if wave_timer <= 0.0:
		should_complete = true
	
	# Tüm düşmanlar öldürüldü mü?
	if enemies_alive <= 0 and enemies_spawned >= enemies_to_spawn:
		should_complete = true
	
	if should_complete and wave_state == WaveState.ACTIVE:
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

func reset() -> void:
	current_wave = 0
	wave_state = WaveState.WAITING
	wave_timer = 0.0
	enemies_to_spawn = 0
	enemies_spawned = 0
	enemies_alive = 0
	difficulty_level = 1.0


