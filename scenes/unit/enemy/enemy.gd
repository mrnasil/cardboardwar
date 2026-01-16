extends Unit
class_name Enemy

# global class Cardboard ve Tape zaten tanımlı olduğu için const tanımlarına gerek yok

enum EnemyBehavior {
	CHASER, # Player'a koşar
	WANDERER, # Random haritada yürür
	SHOOTER, # Ateş eder
	SPLITTER # Öldürülmezse bölünür
}

# Enemy davranış tipi
@export var behavior_type: EnemyBehavior = EnemyBehavior.CHASER

# 羊群效应
@export var flock_push := 20.0
# 视觉区域
@onready var vision_area: Area2D = $VisionArea
@onready var knockback_timer: Timer = $KnockbackTimer

# Wanderer için
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var wander_duration: float = 2.0 # Her 2 saniyede yeni hedef

# Shooter için
var shoot_timer: float = 0.0
var shoot_cooldown: float = 1.5 # 1.5 saniyede bir ateş et

# Splitter için
@export var can_split: bool = false
@export var split_health_threshold: float = 0.3 # %30 can altındaysa bölün

var can_move := true

var knockback_dir: Vector2

var knockback_power: float

func _ready() -> void:
	super._ready()
	# EnemyManager'a kaydet
	register_to_manager()
	add_to_group("enemies")
	if health_component:
		if not health_component.on_unit_died.is_connected(_on_enemy_died):
			health_component.on_unit_died.connect(_on_enemy_died)

func register_to_manager() -> void:
	if has_node("/root/EnemyManager"):
		var manager = get_node("/root/EnemyManager")
		manager.register_enemy(self)
func _exit_tree() -> void:
	# EnemyManager'dan çıkar
	if has_node("/root/EnemyManager"):
		var manager = get_node("/root/EnemyManager")
		manager.unregister_enemy(self)
	
# OPTIMIZE: _process yerine _physics_process kullan (daha tutarlı)
func _physics_process(delta: float) -> void:
	# Pause durumunda hareket etme
	if get_tree().paused:
		return
	
	if not can_move:
		return
	
	# Behavior'a göre davranış
	match behavior_type:
		EnemyBehavior.CHASER:
			_process_chaser(delta)
		EnemyBehavior.WANDERER:
			_process_wanderer(delta)
		EnemyBehavior.SHOOTER:
			_process_shooter(delta)
		EnemyBehavior.SPLITTER:
			_process_chaser(delta) # Splitter da player'a koşar ama bölünebilir
	
	# Player'a çok yakınsa hareket etme (bug önleme)
	if is_instance_valid(Global.player):
		var distance_sq = global_position.distance_squared_to(Global.player.global_position)
		if distance_sq < 10000.0: # 100 pixel'den yakınsa
			# Sadece knockback uygula, player'a doğru hareket etme
			var knockback_move = knockback_dir * knockback_power * stats.speed * delta
			if knockback_move.length_squared() > 0.0:
				var k_pos = global_position + knockback_move
				k_pos = clamp_position_to_map(k_pos)
				global_position = k_pos
			update_rotation()
			_check_out_of_bounds_visibility()
			return
	
	# Knockback uygula
	var move_direction = get_move_direction() + knockback_dir * knockback_power
	var new_position = global_position + move_direction * stats.speed * delta
	
	# Harita sınırları kontrolü
	new_position = clamp_position_to_map(new_position)
	
	global_position = new_position
	update_rotation()
	_check_out_of_bounds_visibility()

func _process_chaser(_delta: float) -> void:
	if not can_move_towards_player():
		return

func _process_wanderer(delta: float) -> void:
	# Random haritada yürü
	wander_timer -= delta
	if wander_timer <= 0.0 or global_position.distance_squared_to(wander_target) < 100.0:
		# Yeni random hedef seç
		var arena = get_tree().current_scene
		if arena and arena.has_method("get_map_bounds"):
			var bounds = arena.get_map_bounds()
			wander_target = Vector2(
				randf_range(bounds.position.x + 100, bounds.position.x + bounds.size.x - 100),
				randf_range(bounds.position.y + 100, bounds.position.y + bounds.size.y - 100)
			)
		wander_timer = wander_duration

func _process_shooter(delta: float) -> void:
	# Player'a doğru dön ama yaklaşma (mesafe koru)
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_at_player()
		shoot_timer = shoot_cooldown
	
	# Player'dan uzak dur
	if is_instance_valid(Global.player):
		var distance_sq = global_position.distance_squared_to(Global.player.global_position)
		if distance_sq < 40000.0: # 200 pixel'den yakınsa uzaklaş
			var away_dir = global_position.direction_to(Global.player.global_position) * -1
			var move_direction = away_dir + knockback_dir * knockback_power
			var new_position = global_position + move_direction * stats.speed * delta * 0.5
			new_position = clamp_position_to_map(new_position)
			global_position = new_position

# 更新朝向
# OPTIMIZE: Sadece değiştiyse güncelle
func update_rotation() -> void:
	if not is_instance_valid(Global.player):
		return
	var player_pos := Global.player.global_position
	var moving_right := global_position.x < player_pos.x
	var new_scale = Vector2(-0.5, 0.5) if moving_right else Vector2(0.5, 0.5)
	# Sadece değiştiyse güncelle (gereksiz işlem önleme)
	if visuals.scale != new_scale:
		visuals.scale = new_scale

# 移动方向
func get_move_direction() -> Vector2:
	match behavior_type:
		EnemyBehavior.WANDERER:
			# Wanderer için random hedefe git
			if wander_target != Vector2.ZERO:
				return global_position.direction_to(wander_target)
			return Vector2.ZERO
		EnemyBehavior.SHOOTER:
			# Shooter player'dan uzak durur, hareket etmez (sadece ateş eder)
			return Vector2.ZERO
		_:
			# Chaser ve Splitter için player'a git
			if not is_instance_valid(Global.player):
				return Vector2.ZERO
			
			# 获得玩家方向
			var direction := global_position.direction_to(Global.player.global_position)
			
			# OPTIMIZE: get_overlapping_areas() maliyetli, sadece gerektiğinde çağır
			# Flock push hesaplamasını optimize et - max 5 enemy ile hesapla (performans)
			var overlapping = vision_area.get_overlapping_areas()
			var max_flock_check = 5 # Çok fazla enemy varsa sınırla
			if overlapping.size() > 0:
				var checked = 0
				for area: Node2D in overlapping:
					if checked >= max_flock_check:
						break
					if area != self and is_instance_valid(area) and area.is_inside_tree():
						var vector := global_position - area.global_position
						var length_sq = vector.length_squared()
						if length_sq > 0.1: # Sıfıra bölmeyi ve aşırı itmeyi önle
							var distance = sqrt(length_sq)
							# Max itme kuvveti sınırla (teleportu önlemek için)
							var push_force = min(flock_push / distance, 5.0)
							direction += vector.normalized() * push_force
							checked += 1
				
			# Direction vectorünü normalize et ki enemy hızlanmasın
			return direction.normalized()
			

# 是否可以移动到玩家，距离100个像素，方式和玩家重叠
# OPTIMIZE: distance_squared kullan (sqrt hesaplaması yok)
func can_move_towards_player() -> bool:
	if not is_instance_valid(Global.player):
		return false
	var distance_sq = global_position.distance_squared_to(Global.player.global_position)
	# Minimum mesafe 100 pixel (100^2 = 10000) - bug'ı önlemek için artırıldı
	return distance_sq > 10000.0 # 100^2 = 10000

func apply_knockback(knock_dir: Vector2, knock_power: float) -> void:
	knockback_dir = knock_dir
	knockback_power = knock_power
	
	# Timer scene tree'de değilse başlatma
	if not is_inside_tree():
		return
	
	knockback_timer.start()

func stop_timers() -> void:
	if is_instance_valid(knockback_timer):
		knockback_timer.stop()
	if is_instance_valid(flash_timer):
		flash_timer.stop()
func reset_enemy() -> void:
	can_move = true
	reset_knockback()
	stop_timers()
	wander_target = Vector2.ZERO
	wander_timer = 0.0
	shoot_timer = 0.0
	if health_component:
		health_component.current_health = health_component.max_health
	visible = true
	# Re-add to enemy group just in case
	if not is_in_group("enemies"):
		add_to_group("enemies")

func reset_knockback() -> void:
	knockback_dir = Vector2.ZERO
	knockback_power = 0.0

func _on_knockback_timer_timeout() -> void:
	reset_knockback()

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	super._on_hurtbox_component_on_damaged(hitbox)
	
	# Splitter kontrolü - can %30'un altına düştüyse bölün
	if behavior_type == EnemyBehavior.SPLITTER and can_split:
		if health_component and health_component.current_health > 0:
			var health_ratio = float(health_component.current_health) / float(health_component.max_health)
			if health_ratio <= split_health_threshold:
				# Bölünme işlemini bir sonraki frame'de yap (hasar işlemi tamamlansın)
				call_deferred("split_enemy")
				# Enemy'yi sil ama normal ölüm işlemlerini yapma
				call_deferred("_remove_splitter_after_split")
				return
	
	if hitbox.knockback_power > 0 and is_instance_valid(hitbox.source):
		var dir := hitbox.source.global_position.direction_to(global_position)
		apply_knockback(dir, hitbox.knockback_power)

func _remove_splitter_after_split() -> void:
	if has_node("/root/ObjectPool"):
		var pool = get_node("/root/ObjectPool")
		pool.return_enemy(self)
	else:
		queue_free()

func shoot_at_player() -> void:
	if not is_instance_valid(Global.player):
		return
	
	# Enemy projectile scene'i yükle
	var projectile_scene = preload("res://scenes/weapons/projectiles/bullet.tscn")
	if not projectile_scene:
		return
	
	var projectile = projectile_scene.instantiate()
	if not projectile:
		return
	
	# Projectile'ı arena'ya ekle
	var arena = get_tree().current_scene
	if not arena:
		return
	
	arena.add_child(projectile)
	projectile.global_position = global_position
	
	# Player'a doğru yön
	var direction = global_position.direction_to(Global.player.global_position)
	
	# Projectile setup (az hasar - 2-3 arası)
	if projectile.has_method("setup"):
		var damage = randf_range(2.0, 3.0)
		var speed = 800.0 # Yavaş mermi
		projectile.setup(damage, direction, speed, false, self)

func _on_enemy_died() -> void:
	# Karton spawn et
	spawn_cardboard()
	
	# Bant (Tape) düşürme şansı - belirli bir oranda
	spawn_tape()
	
	# Player'a experience ver
	if is_instance_valid(Global.player) and Global.player.has_method("add_experience"):
		# Her düşman için 1-3 arası experience
		var exp_gain = randi_range(1, 3)
		Global.player.add_experience(exp_gain)
	
	# OPTIMIZE: Enemy öldüğünde pool'a geri dön
	if has_node("/root/ObjectPool"):
		var pool = get_node("/root/ObjectPool")
		pool.return_enemy(self)
	else:
		queue_free()

func split_enemy() -> void:
	# 2 küçük enemy spawn et
	var arena = get_tree().current_scene
	if not arena:
		return
	
	# Küçük enemy scene'i (chaser_slow kullanabiliriz)
	var small_enemy_scene = preload("res://scenes/unit/enemy/enemy_chaser_slow.tscn")
	if not small_enemy_scene:
		return
	
	for i in range(2):
		var small_enemy = small_enemy_scene.instantiate()
		if not small_enemy:
			continue
		
		arena.add_child(small_enemy)
		
		# Spawn pozisyonu - ana enemy'nin etrafında
		var angle = (TAU / 2.0) * i
		var offset = Vector2.RIGHT.rotated(angle) * 50.0
		small_enemy.global_position = global_position + offset
		
		# Küçük enemy'nin canını azalt (yarı can)
		if small_enemy.health_component and health_component:
			var new_health = max(1, int(health_component.max_health * 0.5))
			small_enemy.health_component.max_health = new_health
			small_enemy.health_component.current_health = new_health
		
		# Küçük enemy'yi küçült
		if small_enemy.visuals:
			small_enemy.visuals.scale = Vector2(0.3, 0.3)

func get_arena() -> Node2D:
	var current = get_tree().current_scene
	if current.get("map_bounds"):
		return current
	
	# Fallback: Root çocuklarında ara
	for child in get_tree().root.get_children():
		if child.get("map_bounds"):
			return child
	return null

func spawn_cardboard() -> void:
	if not stats:
		return
	
	var cardboard_amount = stats.gold_drop
	if cardboard_amount <= 0:
		cardboard_amount = 1
	
	var arena = get_arena()
	if not arena:
		return
	
	# Pozisyonu harita sınırları içine sabitle (biraz pay bırak)
	var spawn_pos = clamp_position_to_map_with_margin(global_position, 30.0)
	
	# Her karton için spawn et
	for i in range(cardboard_amount):
		var cardboard: Cardboard
		if has_node("/root/ObjectPool"):
			var pool = get_node("/root/ObjectPool")
			cardboard = pool.get_cardboard()
		else:
			var cardboard_scene = preload("res://scenes/ui/coin.tscn")
			cardboard = cardboard_scene.instantiate() as Cardboard
		
		if cardboard:
			# Arena'ya ekle
			if not cardboard.get_parent():
				arena.call_deferred("add_child", cardboard)
				cardboard.call_deferred("setup", 1, spawn_pos)
			else:
				cardboard.setup(1, spawn_pos)

func spawn_tape() -> void:
	var tape_drop_chance = 0.20
	if randf() > tape_drop_chance:
		return
	
	var arena = get_arena()
	if not arena:
		print("Enemy: Arena bulunamadı!")
		return
	
	var tape: Tape = null
	if has_node("/root/ObjectPool"):
		var pool = get_node("/root/ObjectPool")
		tape = pool.get_tape()
		if not tape:
			var tape_scene = preload("res://scenes/ui/tape.tscn")
			tape = tape_scene.instantiate() as Tape
	else:
		var tape_scene = preload("res://scenes/ui/tape.tscn")
		tape = tape_scene.instantiate() as Tape
	
	if not tape:
		print("Enemy: Tape oluşturulamadı!")
		return
	
	var heal_amount = 10
	if is_instance_valid(Global.player) and Global.player.health_component:
		heal_amount = int(Global.player.health_component.max_health * randf_range(0.10, 0.15))
		if heal_amount <= 0:
			heal_amount = 10
	
	# Pozisyonu harita sınırları içine sabitle (biraz pay bırak)
	var spawn_pos = clamp_position_to_map_with_margin(global_position, 30.0)
	
	if not tape.get_parent():
		arena.call_deferred("add_child", tape)
		tape.call_deferred("setup", heal_amount, spawn_pos)
	else:
		tape.setup(heal_amount, spawn_pos)
	
	print("Enemy: Bant spawn edildi, heal: ", heal_amount, " pos: ", spawn_pos)

func clamp_position_to_map_with_margin(pos: Vector2, margin: float) -> Vector2:
	var bounds = Rect2(-1600, -1600, 3200, 3200) # Devasa fallback (arena gelene kadar)
	var arena = get_arena()
	if arena:
		bounds = arena.get_map_bounds()
	
	# Margin ile daraltılmış sınırlar
	var min_x = bounds.position.x + margin
	var max_x = bounds.position.x + bounds.size.x - margin
	var min_y = bounds.position.y + margin
	var max_y = bounds.position.y + bounds.size.y - margin
	
	var clamped_x = clamp(pos.x, min_x, max_x)
	var clamped_y = clamp(pos.y, min_y, max_y)
	return Vector2(clamped_x, clamped_y)

func clamp_position_to_map(pos: Vector2) -> Vector2:
	# Her zaman harita sınırlarından biraz içeride kal (margin = 50.0)
	return clamp_position_to_map_with_margin(pos, 50.0)

func _check_out_of_bounds_visibility() -> void:
	var arena = get_arena()
	if arena and arena.has_method("is_position_in_map"):
		var bounds = arena.get_map_bounds()
		# Toleranslı kontrol - hafif dışarı çıkarsa görünmez olsun
		if not bounds.has_point(global_position):
			# Eğer clamp failed olduysa ve dışarı çıktıysa gizle
			visible = false
		else:
			visible = true
	else:
		# Fallback: Çok uzaklaşırsa gizle
		if global_position.length_squared() > 4000000: # 2000^2
			visible = false
		else:
			visible = true
