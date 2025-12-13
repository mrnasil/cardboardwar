extends Area2D
class_name Cardboard

@onready var sprite: Sprite2D = $Sprite2D
@onready var collect_timer: Timer = $CollectTimer

var cardboard_value: int = 1
var magnet_range: float = 100.0
var collect_speed: float = 500.0
var is_collecting: bool = false
var force_collect: bool = false  # Wave bitiminde zorla toplama

# Karton varyasyonları için texture'lar
var cardboard_textures: Array[Texture2D] = []

func _ready() -> void:
	# Sprite'ı görünür yap
	if sprite:
		sprite.visible = true
	
	# Karton texture'larını yükle (az, orta, çok)
	_load_cardboard_textures()
	
	# Kısa bir süre sonra toplanabilir hale gel
	collect_timer.wait_time = 0.3
	collect_timer.start()
	collect_timer.timeout.connect(_on_collect_timer_timeout)
	
	# Area2D sinyalleri - body_entered player ile temas ettiğinde
	body_entered.connect(_on_body_entered)
	
	# Wave bitiminde tüm kartonları çek
	if has_node("/root/WaveManager"):
		var wave_mgr = get_node("/root/WaveManager")
		wave_mgr.wave_completed.connect(_on_wave_completed)

func _load_cardboard_textures() -> void:
	# Karton varyasyonlarını yükle
	var base_texture = load("res://assets/cardboard.png") as Texture2D
	if not base_texture:
		# Eğer dosya yoksa, geçici olarak gold sprite kullan
		base_texture = preload("res://assets/sprites/Gold/gold_1.png")
	
	if base_texture:
		# Eğer tek bir atlas texture ise, TextureRegion kullan
		# Şimdilik tek texture kullan, setup'ta değere göre ayarla
		cardboard_textures = [base_texture, base_texture, base_texture]

func setup(value: int, pos: Vector2) -> void:
	cardboard_value = value
	global_position = pos
	is_collecting = false
	force_collect = false
	
	# Karton değerine göre sprite'ı ayarla (az=0, orta=1, çok=2)
	_update_sprite_by_value()
	
	# Rastgele bir yöne fırlat
	var random_dir = Vector2.RIGHT.rotated(randf() * TAU)
	var random_distance = randf_range(20, 60)
	global_position += random_dir * random_distance
	
	# Hafif bir yukarı fırlatma animasyonu
	var tween = create_tween()
	tween.tween_property(self, "global_position:y", global_position.y - 30, 0.3)
	tween.tween_property(self, "global_position:y", global_position.y, 0.2)

func _update_sprite_by_value() -> void:
	if not sprite:
		return
	
	var base_texture = load("res://assets/cardboard.png") as Texture2D
	if not base_texture:
		# Eğer dosya yoksa, geçici olarak gold sprite kullan
		base_texture = preload("res://assets/sprites/Gold/gold_1.png")
	
	if not base_texture:
		return
	
	# Karton değerine göre varyasyon seç (1=az, 2=orta, 3+=çok)
	var variation_index = 0
	if cardboard_value == 1:
		variation_index = 0  # Az
	elif cardboard_value == 2:
		variation_index = 1  # Orta
	else:
		variation_index = 2  # Çok
	
	# Texture'ı ayarla
	sprite.texture = base_texture
	
	# Sprite sheet'ten doğru frame'i seç (3 frame yan yana varsayımı)
	# Texture genişliğini 3'e bölerek her frame'in genişliğini bul
	var texture_width = base_texture.get_width()
	var texture_height = base_texture.get_height()
	var frame_width = texture_width / 3.0
	
	if frame_width > 0:
		# Region'ı etkinleştir ve doğru frame'i göster
		sprite.region_enabled = true
		sprite.region_rect = Rect2(variation_index * frame_width, 0, frame_width, texture_height)

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
		collect_cardboard()
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
		collect_cardboard()

func _on_wave_completed(_wave_number: int) -> void:
	# Wave bitiminde zorla player'a çek
	if not is_collecting and not force_collect:
		force_collect = true
		is_collecting = true

func collect_cardboard() -> void:
	# Player'a karton ekle
	if is_instance_valid(Global.player) and Global.player.has_method("add_cardboard"):
		Global.player.add_cardboard(cardboard_value)
	
	# OPTIMIZE: Pool'a geri dön
	if has_node("/root/ObjectPool"):
		var pool = get_node("/root/ObjectPool")
		pool.return_cardboard(self)
	else:
		queue_free()

