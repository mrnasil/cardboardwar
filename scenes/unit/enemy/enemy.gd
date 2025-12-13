extends Unit
class_name Enemy

const Cardboard = preload("res://scenes/ui/coin.gd")
const Tape = preload("res://scenes/ui/tape.gd")

# 羊群效应
@export var flock_push := 20.0
# 视觉区域
@onready var vision_area: Area2D = $VisionArea
@onready var knockback_timer: Timer = $KnockbackTimer


var can_move := true

var knockback_dir:Vector2

var knockback_power:float

func _ready() -> void:
	super._ready()
	# EnemyManager'a kaydet
	if has_node("/root/EnemyManager"):
		var manager = get_node("/root/EnemyManager")
		manager.register_enemy(self)
	# HealthComponent'e ölüm sinyalini bağla
	if health_component:
		health_component.on_unit_died.connect(_on_enemy_died)
	
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
		
	if not can_move_towards_player():
		return
	
	var move_direction = get_move_direction() + knockback_dir * knockback_power
	var new_position = position + move_direction * stats.speed * delta
	
	# Harita sınırları kontrolü - sadece harita dışına çıkmayı engelle
	# Düşmanlar harita kenarına tam olarak gelebilir (margin yok)
	new_position = clamp_position_to_map(new_position)
	
	position = new_position
	update_rotation()

# 更新朝向
# OPTIMIZE: Sadece değiştiyse güncelle
func update_rotation() -> void:
	if not is_instance_valid(Global.player):
		return
	var player_pos := Global.player.global_position
	var moving_right := global_position.x < player_pos.x
	var new_scale = Vector2(-0.5,0.5) if moving_right else Vector2(0.5,0.5)
	# Sadece değiştiyse güncelle (gereksiz işlem önleme)
	if visuals.scale != new_scale:
		visuals.scale = new_scale

# 移动方向
func get_move_direction() -> Vector2:
	if not is_instance_valid(Global.player):
		return Vector2.ZERO
	
	# 获得玩家方向
	var direction := global_position.direction_to(Global.player.position)
	
	# OPTIMIZE: get_overlapping_areas() maliyetli, sadece gerektiğinde çağır
	# Flock push hesaplamasını optimize et - max 5 enemy ile hesapla (performans)
	var overlapping = vision_area.get_overlapping_areas()
	var max_flock_check = 5  # Çok fazla enemy varsa sınırla
	if overlapping.size() > 0:
		var checked = 0
		for area: Node2D in overlapping:
			if checked >= max_flock_check:
				break
			if area != self and is_instance_valid(area) and area.is_inside_tree():
				var vector := global_position - area.global_position
				var length_sq = vector.length_squared()
				if length_sq > 0.0:  # Sıfıra bölmeyi önle
					direction += flock_push * vector.normalized() / sqrt(length_sq)
					checked += 1
			
	return direction
			

# 是否可以移动到玩家，距离60个像素，方式和玩家重叠
# OPTIMIZE: distance_squared kullan (sqrt hesaplaması yok)
func can_move_towards_player() -> bool:
	if not is_instance_valid(Global.player):
		return false
	var distance_sq = global_position.distance_squared_to(Global.player.global_position)
	return distance_sq > 3600.0  # 60^2 = 3600

func apply_knockback(knock_dir :Vector2,knock_power:float) -> void:
	knockback_dir = knock_dir
	knockback_power = knock_power
	if knockback_timer.time_left >0:
		knockback_timer.stop()
		reset_knockback()
		
	knockback_timer.start()

func reset_knockback() -> void:
	knockback_dir = Vector2.ZERO
	knockback_power = 0.0

func _on_knockback_timer_timeout() -> void:
	reset_knockback()

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	super._on_hurtbox_component_on_damaged(hitbox)
	
	if hitbox.knockback_power > 0 and is_instance_valid(hitbox.source):
		var dir := hitbox.source.global_position.direction_to(global_position)
		apply_knockback(dir,hitbox.knockback_power)

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

func spawn_cardboard() -> void:
	if not stats:
		return
	
	var cardboard_amount = stats.gold_drop
	if cardboard_amount <= 0:
		cardboard_amount = 1
	
	# Arena'yı bul
	var arena = get_tree().current_scene
	if not arena or not arena is Arena:
		return
	
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
			# Arena'ya ekle (deferred olarak - physics query flush sırasında hata vermemesi için)
			if not cardboard.get_parent():
				arena.call_deferred("add_child", cardboard)
				# Setup'ı da deferred olarak çağır (child eklendikten sonra)
				cardboard.call_deferred("setup", 1, global_position)
			else:
				# Zaten parent'ı varsa direkt setup çağır
				cardboard.setup(1, global_position)

func spawn_tape() -> void:
	# Bant düşürme şansı - %20 şans
	var tape_drop_chance = 0.20
	if randf() > tape_drop_chance:
		return
	
	# Arena'yı bul
	var arena = get_tree().current_scene
	if not arena or not arena is Arena:
		print("Enemy: Arena bulunamadı!")
		return
	
	# Bant spawn et
	var tape: Tape = null
	if has_node("/root/ObjectPool"):
		var pool = get_node("/root/ObjectPool")
		tape = pool.get_tape()
		if not tape:
			# Pool'dan alınamazsa yeni oluştur
			var tape_scene = preload("res://scenes/ui/tape.tscn")
			tape = tape_scene.instantiate() as Tape
	else:
		var tape_scene = preload("res://scenes/ui/tape.tscn")
		tape = tape_scene.instantiate() as Tape
	
	if not tape:
		print("Enemy: Tape oluşturulamadı!")
		return
	
	# Bant can miktarını hesapla (max canın %10-15'i)
	var heal_amount = 10  # Varsayılan değer
	if is_instance_valid(Global.player) and Global.player.health_component:
		heal_amount = int(Global.player.health_component.max_health * randf_range(0.10, 0.15))
		if heal_amount <= 0:
			heal_amount = 10
	
	# Arena'ya ekle (deferred olarak - physics query flush sırasında hata vermemesi için)
	if not tape.get_parent():
		arena.call_deferred("add_child", tape)
		# Setup'ı da deferred olarak çağır (child eklendikten sonra)
		tape.call_deferred("setup", heal_amount, global_position)
	else:
		# Zaten parent'ı varsa direkt setup çağır
		tape.setup(heal_amount, global_position)
	
	print("Enemy: Bant spawn edildi, heal: ", heal_amount, " pos: ", global_position)

func clamp_position_to_map(pos: Vector2) -> Vector2:
	# Arena'dan harita sınırlarını al
	var arena = get_tree().current_scene
	var bounds: Rect2
	if arena and arena is Arena:
		var arena_node = arena as Arena
		if arena_node.has_method("get_map_bounds"):
			bounds = arena_node.get_map_bounds()
			if bounds.size.x > 0 and bounds.size.y > 0:  # Geçerli sınırlar var mı?
				# Godot 4'te Rect2.clamp() yok, manuel clamp yapıyoruz
				var clamped_x = clamp(pos.x, bounds.position.x, bounds.position.x + bounds.size.x)
				var clamped_y = clamp(pos.y, bounds.position.y, bounds.position.y + bounds.size.y)
				return Vector2(clamped_x, clamped_y)
	# Arena bulunamazsa veya sınırlar geçersizse varsayılan sınırları kullan
	bounds = Rect2(-960, -1080, 1920, 2160)
	var clamped_x = clamp(pos.x, bounds.position.x, bounds.position.x + bounds.size.x)
	var clamped_y = clamp(pos.y, bounds.position.y, bounds.position.y + bounds.size.y)
	return Vector2(clamped_x, clamped_y)
