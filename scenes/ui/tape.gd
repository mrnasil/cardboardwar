extends Area2D
class_name Tape

@onready var sprite: Sprite2D = $Sprite2D
@onready var collect_timer: Timer = $CollectTimer

var heal_amount: int = 10
var magnet_range: float = 100.0
var collect_speed: float = 500.0
var is_collecting: bool = false
var force_collect: bool = false  # Wave bitiminde zorla toplama

func _ready() -> void:
	# Sprite'ı görünür yap
	if sprite:
		sprite.visible = true
		sprite.modulate = Color.WHITE
	
	# Kısa bir süre sonra toplanabilir hale gel
	collect_timer.wait_time = 0.3
	collect_timer.start()
	collect_timer.timeout.connect(_on_collect_timer_timeout)
	
	# Area2D sinyalleri - body_entered player ile temas ettiğinde
	body_entered.connect(_on_body_entered)
	
	# Wave bitiminde tüm bantları çek
	if has_node("/root/WaveManager"):
		var wave_mgr = get_node("/root/WaveManager")
		wave_mgr.wave_completed.connect(_on_wave_completed)

func setup(heal: int, pos: Vector2) -> void:
	heal_amount = heal
	global_position = pos
	is_collecting = false
	force_collect = false
	
	# Sprite'ı görünür yap
	if sprite:
		sprite.visible = true
		sprite.modulate = Color.WHITE
	
	# Bant değerine göre sprite'ı ayarla
	_update_sprite_by_heal_amount()
	
	# Visible ve process mode'u aktif et
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	
	# Rastgele bir yöne fırlat
	var random_dir = Vector2.RIGHT.rotated(randf() * TAU)
	var random_distance = randf_range(20, 60)
	global_position += random_dir * random_distance
	
	# Hafif bir yukarı fırlatma animasyonu
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - 30, 0.3)
	tween.tween_property(self, "global_position:y", global_position.y, 0.2)
	
	print("Tape setup edildi: heal=", heal_amount, " pos=", global_position)

func _update_sprite_by_heal_amount() -> void:
	if not sprite:
		return
	
	var base_texture = load("res://assets/bant.png") as Texture2D
	if not base_texture:
		return
	
	# Bant heal amount'una göre varyasyon seç
	# Küçük, büyük, en büyük (3 frame yan yana varsayımı)
	var variation_index = 0
	if heal_amount <= 5:
		variation_index = 0  # Küçük
	elif heal_amount <= 15:
		variation_index = 1  # Büyük
	else:
		variation_index = 2  # En büyük
	
	# Texture'ı ayarla
	sprite.texture = base_texture
	
	# Sprite sheet'ten doğru frame'i seç (3 frame yan yana varsayımı)
	# Texture genişliğini 3'e bölerek her frame'in genişliğini bul
	if base_texture:
		var texture_size = base_texture.get_size()
		var frame_width = texture_size.x / 3.0
		var frame_height = texture_size.y
		
		# Region rect'i ayarla
		sprite.region_enabled = true
		sprite.region_rect = Rect2(
			variation_index * frame_width,
			0,
			frame_width,
			frame_height
		)

func _on_collect_timer_timeout() -> void:
	# Artık toplanabilir
	pass

func _process(delta: float) -> void:
	if not is_instance_valid(Global.player):
		return
	
	var player_pos = Global.player.global_position
	var distance = global_position.distance_to(player_pos)
	
	# Player'a çok yakınsa direkt topla (üzerinden geçme kontrolü)
	if distance < 25.0:
		collect_tape()
		return
	
	# Wave bitiminde zorla çek
	if force_collect:
		var direction = global_position.direction_to(player_pos)
		global_position += direction * collect_speed * 2.0 * delta  # Daha hızlı
		return
	
	# Normal magnet mekanizması
	if not is_collecting and collect_timer.is_stopped():
		# Player'a doğru çek
		if distance < magnet_range:
			is_collecting = true
	
	if is_collecting:
		var direction = global_position.direction_to(player_pos)
		global_position += direction * collect_speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Player üzerinden geçince direkt topla
	if body is Player:
		collect_tape()

func _on_wave_completed(_wave_number: int) -> void:
	# Wave bitiminde zorla player'a çek
	if not is_collecting and not force_collect:
		force_collect = true
		is_collecting = true

func collect_tape() -> void:
	# Player'a can ver
	if is_instance_valid(Global.player) and Global.player.health_component:
		Global.player.health_component.heal(heal_amount)
	
	# OPTIMIZE: Pool'a geri dön
	if has_node("/root/ObjectPool"):
		var pool = get_node("/root/ObjectPool")
		pool.return_tape(self)
	else:
		queue_free()

