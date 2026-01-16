extends Area2D
class_name Bullet

@export var speed: float = 1600.0
@export var damage: float = 1.0
@export var is_critical: bool = false
@export var owner_unit: Node2D = null

var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 2.0
var traveled_distance: float = 0.0
var max_distance: float = 2000.0

var sprite: Sprite2D
var collision: CollisionShape2D

var is_enemy_bullet: bool = false

func _ready() -> void:
	# Node referanslarını al
	sprite = get_node_or_null("Sprite2D")
	collision = get_node_or_null("CollisionShape2D")
	
	# Sprite yoksa oluştur
	if not sprite:
		sprite = Sprite2D.new()
		add_child(sprite)
		sprite.name = "Sprite2D"
		sprite.modulate = Color(1, 1, 0, 1)
		sprite.scale = Vector2(0.3, 0.3)
	
	# Signal'leri bağla
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func setup(dmg: float, dir: Vector2, spd: float, crit: bool, p_owner: Node2D) -> void:
	damage = dmg
	direction = dir.normalized()
	speed = spd
	is_critical = crit
	owner_unit = p_owner
	
	# Takım belirle ve collision mask ayarla
	if p_owner is Enemy:
		is_enemy_bullet = true
		# Enemy mermisi -> Player Hurtbox (Layer 6 = 32)
		collision_layer = 4 # HitboxEnemy (Layer 3)
		collision_mask = 32 # HurtboxPlayer (Layer 6)
		
		# Düşman mermisi BEYAZ ve daha büyük olsun (daha görünür)
		if sprite:
			sprite.modulate = Color(1.0, 1.0, 1.0) # Tam Beyaz
			sprite.scale = Vector2(0.5, 0.5) # Biraz daha büyük
	else:
		is_enemy_bullet = false
		# Player mermisi -> Enemy Hurtbox (Layer 4 = 8)
		collision_layer = 16 # HitboxPlayer (Layer 5)
		collision_mask = 8 # HurtboxEnemy (Layer 4)
	
	# Yönüne doğru döndür
	rotation = direction.angle()
	
	# Lifetime timer başlat
	if is_inside_tree():
		await get_tree().create_timer(lifetime).timeout
		if is_instance_valid(self):
			queue_free()

func _process(delta: float) -> void:
	# Hareket
	var movement = direction * speed * delta
	global_position += movement
	traveled_distance += movement.length()
	
	# Maksimum mesafeyi aştıysa sil
	if traveled_distance >= max_distance:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	# Hurtbox component'e çarptıysa
	if area is HurtboxComponent:
		var hurtbox = area as HurtboxComponent
		# HurtboxComponent unit'in child'ı, parent'ı unit olmalı
		var target_unit = hurtbox.get_parent()
		
		# Target Unit değilse yoksay
		if not target_unit is Unit:
			return
		
		# Kendi sahibine veya sahibinin parent'ına çarparsa yoksay
		var actual_owner = owner_unit
		if is_instance_valid(owner_unit) and owner_unit is Weapon:
			var weapon_parent = owner_unit.get_parent()
			if is_instance_valid(weapon_parent):
				actual_owner = weapon_parent
			
		if is_instance_valid(actual_owner) and target_unit == actual_owner:
			return
		
		# Takım kontrolü (Flag üzerinden)
		var valid_hit = false
		
		if is_enemy_bullet:
			# Düşman mermisi ise Player'a çarpmalı
			if target_unit is Player:
				valid_hit = true
		else:
			# Player mermisi ise Enemy'ye çarpmalı
			if target_unit is Enemy:
				valid_hit = true
		
		if not valid_hit:
			return
			
		# Hasar uygula
		if target_unit.health_component:
			target_unit.health_component.take_damage(damage)
			
			# Hasarı raporla (sadece player mermileri için)
			if not is_enemy_bullet:
				var player = Global.player
				if is_instance_valid(player):
					player.record_damage(damage, owner_unit if owner_unit is Weapon else null)
		
		# Mermiyi sil (Çarptı ve durdu)
		queue_free()
