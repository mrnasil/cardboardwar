extends Node
# Enemy Manager - Staggered Updates ve Culling
# Not: class_name kaldırıldı - autoload singleton ile çakışmayı önlemek için
# OPTIMIZE.md'ye göre: Spike önleme ve performans artışı

var active_enemies: Array[Enemy] = []
var update_groups: Array[Array] = []
var current_group_index := 0
var groups_per_frame := 10  # Her frame'de kaç grup update edilecek

var culling_distance := 2000.0  # Ekran dışı mesafe
var player_ref: Node2D
var culling_timer := 0.0
var culling_interval := 0.5  # Culling'i her 0.5 saniyede bir yap

func _ready() -> void:
	# Update gruplarını oluştur
	for i in range(groups_per_frame):
		update_groups.append([])

func _physics_process(delta: float) -> void:
	# Pause durumunda çalışma
	if get_tree().paused:
		return
	
	if not is_instance_valid(player_ref):
		return
	
	# Staggered update: Her frame'de sadece bir grup update edilir
	update_enemy_group(current_group_index)
	current_group_index = (current_group_index + 1) % groups_per_frame
	
	# Culling: Uzak enemy'leri devre dışı bırak (daha az sıklıkla)
	culling_timer += delta
	if culling_timer >= culling_interval:
		culling_timer = 0.0
		perform_culling()

func register_enemy(enemy: Enemy) -> void:
	if enemy in active_enemies:
		return
	
	# Enemy'nin process_mode'unun doğru ayarlandığından emin ol
	# Enemy'ler her zaman PROCESS_MODE_INHERIT olmalı (pause durumunda durur)
	enemy.process_mode = Node.PROCESS_MODE_INHERIT
	
	active_enemies.append(enemy)
	# Enemy'yi bir gruba ekle (round-robin)
	var group_index = active_enemies.size() % groups_per_frame
	update_groups[group_index].append(enemy)

func unregister_enemy(enemy: Enemy) -> void:
	active_enemies.erase(enemy)
	for group in update_groups:
		group.erase(enemy)

func update_enemy_group(group_index: int) -> void:
	if group_index >= update_groups.size():
		return
	
	var group = update_groups[group_index]
	var to_remove := []
	
	for enemy in group:
		if not is_instance_valid(enemy):
			to_remove.append(enemy)
			continue
		
		# Enemy update'i burada yapılabilir (gerekirse)
		# Şu an enemy kendi _process'ini kullanıyor
	
	for enemy in to_remove:
		group.erase(enemy)

func perform_culling() -> void:
	# Pause durumunda culling yapma
	if get_tree().paused:
		return
	
	if not is_instance_valid(player_ref):
		return
	
	# Culling'i kaldırdık - enemy'ler her zaman aktif kalacak
	# Bu takılmaları önler ve performans sorunları yoksa gerekli değil
	# Eğer performans sorunu olursa, burada enemy'leri görünürlük açısından kontrol edebiliriz
	# Ama process_mode'unu değiştirmiyoruz çünkü bu takılmalara neden oluyor

func set_player(player: Node2D) -> void:
	player_ref = player

func get_active_enemy_count() -> int:
	return active_enemies.size()

func clear_all_enemies() -> void:
	# Tüm aktif düşmanları temizle
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	
	active_enemies.clear()
	for group in update_groups:
		group.clear()

