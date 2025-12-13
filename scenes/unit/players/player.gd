extends Unit
class_name Player

@export var dash_duration := 0.5
@export var dash_speed_multi := 2.5
@export var dash_cooldown := 0.5

@onready var dash_cooldown_timer: Timer = $DashCooldwnTimer
@onready var dash_timer: Timer = $DashTimer
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var trail: Trail = %Trail
@onready var weapon_container: WeaponContainer = $WeaponContainer
@onready var dash_smoke: CPUParticles2D = %DashSmoke

var current_weapons:Array[Weapon] = []

var move_dir:Vector2
var is_dashing := false
var dash_available := false

# Level ve Experience sistemi
signal on_level_up(new_level: int)
signal on_experience_gained(current_exp: int, exp_needed: int)
signal on_cardboard_changed(cardboard: int)

var level: int = 1
var experience: int = 0
var experience_needed: int = 10  # İlk level için gerekli exp
var cardboard: int = 0

# Level başına stat artışları
@export var health_per_level: float = 5.0
@export var damage_per_level: float = 1.0
@export var speed_per_level: float = 10.0

func _ready() -> void:
	super._ready()
	dash_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	
	# Level sistemi başlangıç
	level = 1
	experience = 0
	experience_needed = get_experience_needed_for_level(level)
	cardboard = 0
	
	add_weapon(preload("uid://d1go7qyiyhwib"))
	#add_weapon(preload("uid://d1go7qyiyhwib"))
	#add_weapon(preload("uid://d1go7qyiyhwib"))
	#add_weapon(preload("uid://d1go7qyiyhwib"))
	#add_weapon(preload("uid://d1go7qyiyhwib"))
	#add_weapon(preload("uid://d1go7qyiyhwib"))

func _process(delta: float) -> void:
	# Pause durumunda veya upgrade ekranı açıkken hareket etme
	if get_tree().paused:
		return
	
	# Upgrade ekranı kontrolü
	var upgrade_screen = get_tree().root.get_node_or_null("UpgradeScreen")
	if upgrade_screen and upgrade_screen.visible:
		return
	
	move_dir = Input.get_vector("move_left","move_right","move_up","move_down")
	var current_velocity := move_dir * stats.speed
	if is_dashing:
		current_velocity *= dash_speed_multi
	
	position += current_velocity * delta
	position.x = clamp(position.x, -1000,1000)
	position.y = clamp(position.y,-1000,1000)
	
	if can_dash():
		start_dash()
	
	update_animations()
	update_rotation()

func add_weapon(data:ItemWeapon) -> void:
	var weapon := data.scene.instantiate() as Weapon
	add_child(weapon)
	
	weapon.setup_weapon(data)
	current_weapons.append(weapon)
	weapon_container.update_weapons_position(current_weapons)

func update_animations() -> void:
	if move_dir.length() > 0:
		anim_player.play("move")
	else:
		anim_player.play("idle")

func update_rotation() -> void:
	if move_dir == Vector2.ZERO:
		return
		
	if move_dir.x >= 0.1:
		visuals.scale = Vector2(0.5, 0.5)  # Sağa giderken sağa dön
	else:
		visuals.scale = Vector2(-0.5, 0.5)  # Sola giderken sola dön

func start_dash() -> void:
	is_dashing = true
	dash_timer.start()
	trail.start_trail()
	visuals.modulate.a = 0.5
	collision.set_deferred("disabled",true)
	
	# Bulut efekti - dash başladığında arkasında beyaz bulut
	if dash_smoke:
		dash_smoke.global_position = global_position
		# Dash yönüne göre bulut yönünü ayarla
		if move_dir != Vector2.ZERO:
			var dash_angle_rad = move_dir.angle() + PI  # Arkaya doğru (radyan)
			dash_smoke.direction = Vector2.from_angle(dash_angle_rad)
		dash_smoke.emitting = true
	
	
func can_dash() -> bool:
	return not is_dashing and\
	 dash_cooldown_timer.is_stopped() and\
	Input.is_action_just_pressed("dash") and\
	move_dir != Vector2.ZERO 

# 朝向
func is_facing_right() -> bool:
	return visuals.scale.x == 0.5
	
func _on_dash_timer_timeout() -> void:
	is_dashing = false
	visuals.modulate.a = 1.0
	move_dir = Vector2.ZERO
	collision.set_deferred("disabled",false)
	dash_cooldown_timer.stop()

# Level ve Experience fonksiyonları
func get_experience_needed_for_level(lvl: int) -> int:
	# Her level için gerekli exp artışı (Brotato tarzı)
	# Level 1: 10, Level 2: 15, Level 3: 22, vb.
	return int(10 + (lvl - 1) * 5 + (lvl - 1) * (lvl - 1) * 0.5)

func add_experience(amount: int) -> void:
	experience += amount
	on_experience_gained.emit(experience, experience_needed)
	
	# Level up kontrolü
	while experience >= experience_needed:
		level_up()

func level_up() -> void:
	experience -= experience_needed
	level += 1
	experience_needed = get_experience_needed_for_level(level)
	
	# Stat artışları
	if stats:
		stats.health += health_per_level
		stats.damage += damage_per_level
		stats.speed += speed_per_level
		
		# Health component'i güncelle
		if health_component:
			var old_max = health_component.max_health
			health_component.max_health = int(stats.health)
			# Mevcut health'i orantılı olarak artır
			var health_ratio = float(health_component.current_health) / float(old_max) if old_max > 0 else 1.0
			health_component.current_health = int(stats.health * health_ratio)
			health_component.on_health_changed.emit(health_component.current_health, health_component.max_health)
	
	on_level_up.emit(level)
	on_experience_gained.emit(experience, experience_needed)
	
	print("Level Up! Yeni Level: %d" % level)

# Cardboard (Karton) fonksiyonları
func add_cardboard(amount: int) -> void:
	cardboard += amount
	on_cardboard_changed.emit(cardboard)

func spend_cardboard(amount: int) -> bool:
	if cardboard >= amount:
		cardboard -= amount
		on_cardboard_changed.emit(cardboard)
		return true
	return false
