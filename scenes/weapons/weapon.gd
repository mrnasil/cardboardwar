extends Node2D
class_name Weapon

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = %CollisionShape2D
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var weapon_behavior: WeaponBehavior = $WeaponBehavior

var data: ItemWeapon
var is_attacking := false
var atk_start_pos: Vector2
var targets: Array[Enemy]
var closest_target: Enemy
var weapon_spread: float
var total_damage_dealt: float = 0.0

func _ready() -> void:
	atk_start_pos = sprite.position

func _process(_delta: float) -> void:
	# Pause durumunda veya upgrade ekranı açıkken çalışma
	if get_tree().paused:
		return
	
	# Upgrade screen kontrolü
	var upgrade_screen = get_tree().root.get_node_or_null("UpgradeScreen")
	if upgrade_screen and upgrade_screen.visible:
		return
	
	# OPTIMIZE: Target aramayı her frame yapmak yerine daha az sıklıkta yap
	if not is_attacking:
		if targets.size() > 0:
			# Geçersiz target'ları temizle
			targets = targets.filter(func(t): return is_instance_valid(t))
			if targets.size() > 0:
				update_closest_target()
			else:
				closest_target = null
		else:
			closest_target = null
	
	rotate_to_target()
	
	if can_use_weapon():
		use_weapon()

func setup_weapon(weapon_data: ItemWeapon) -> void:
	self.data = weapon_data
	update_weapon_range()

func update_weapon_range() -> void:
	if not data or not data.stats:
		return
	
	var base_range = data.stats.max_range
	var range_bonus = 0.0
	
	# Primary stats range bonusu
	if Global.player and Global.player.primary_stats:
		range_bonus = Global.player.primary_stats.get_range_bonus()
	
	# Melee weapon'lar için range bonusu yarıya iner
	if data.type == ItemWeapon.WeaponType.MELEE:
		range_bonus = range_bonus / 2.0
	
	var final_range = base_range + range_bonus
	
	# Minimum range 25
	final_range = max(25.0, final_range)
	
	if collision and collision.shape:
		collision.shape.radius = final_range
	
func use_weapon() -> void:
	calculate_spread()
	weapon_behavior.execute_attack()
	
	# Life steal'i uygula
	if weapon_behavior.has_method("apply_life_steal"):
		weapon_behavior.apply_life_steal()
	
	# Attack speed hesaplama (primary stats + class bonuses)
	var cooldown = data.stats.cooldown
	var attack_speed_multiplier = 1.0
	
	# Primary stats attack speed
	if Global.player and Global.player.primary_stats:
		attack_speed_multiplier = Global.player.primary_stats.get_attack_speed_multiplier()
	
	# Class bonuslarından attack speed bonusunu al
	if Global.player and Global.player.class_bonuses:
		var class_bonuses = Global.player.class_bonuses
		if class_bonuses.has(data.weapon_class):
			var bonuses = class_bonuses[data.weapon_class]
			var attack_speed_bonus = bonuses.get("attack_speed", 0.0)
			if attack_speed_bonus > 0.0:
				# Class bonus attack speed'i de ekle
				attack_speed_multiplier *= (1.0 + attack_speed_bonus)
	
	# Cooldown'ı attack speed'e göre ayarla
	cooldown = data.stats.cooldown / attack_speed_multiplier
	
	# Max attack speed limiti: 12 attacks/second (melee için daha yavaş olabilir)
	var min_cooldown = 1.0 / 12.0 # 12 attacks/second = 0.083s cooldown
	if data.type == ItemWeapon.WeaponType.MELEE:
		# Melee için biraz daha yavaş limit
		min_cooldown = 1.0 / 8.0 # 8 attacks/second
	
	cooldown = max(cooldown, min_cooldown)
	
	cooldown_timer.wait_time = cooldown
	cooldown_timer.start()

func rotate_to_target() -> void:
	if is_attacking:
		rotation = get_custom_rotation_to_target()
	else:
		rotation = get_rotation_to_target()

func get_custom_rotation_to_target() -> float:
	if not closest_target or not is_instance_valid(closest_target):
		return rotation
	
	var rot := global_position.direction_to(closest_target.global_position).angle()
	return rot + weapon_spread
	

func get_rotation_to_target() -> float:
	if targets.size() == 0:
		return get_idle_rotation()
		
	var rot := global_position.direction_to(closest_target.global_position).angle()
	return rot

func get_idle_rotation() -> float:
	if Global.player.is_facing_right():
		return 0
	else:
		return PI

# 计算武器选择朝向
func calculate_spread() -> void:
	weapon_spread += randf_range(-1 + data.stats.accuracy, 1 - data.stats.accuracy)
	rotation += weapon_spread
	
func update_closest_target() -> void:
	closest_target = get_closest_target()

func get_closest_target() -> Node2D:
	if targets.size() == 0:
		return null
	
	# OPTIMIZE: distance_squared kullan (sqrt hesaplaması yok)
	var closest_enemy: Enemy = null
	var closest_distance_sq := INF
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		var target_enemy = target as Enemy
		if not target_enemy:
			continue
		
		var distance_sq := global_position.distance_squared_to(target_enemy.global_position)
		
		if distance_sq < closest_distance_sq:
			closest_enemy = target_enemy
			closest_distance_sq = distance_sq
	
	return closest_enemy


func can_use_weapon() -> bool:
	return cooldown_timer.is_stopped() and closest_target


func _on_range_area_2_area_entered(area: Area2D) -> void:
	targets.push_back(area)


func _on_range_area_2_area_exited(area: Area2D) -> void:
	targets.erase(area)
	if targets.size() == 0:
		closest_target = null


func _on_cooldown_timer_timeout() -> void:
	cooldown_timer.stop()
