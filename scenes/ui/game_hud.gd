extends Control
class_name GameHUD

@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar/ProgressBar
@onready var health_label: Label = $VBoxContainer/HealthBar/HealthLabel
@onready var exp_bar: ProgressBar = $VBoxContainer/ExpBar/ProgressBar
@onready var level_label: Label = $VBoxContainer/ExpBar/LevelLabel
@onready var cardboard_label: Label = $VBoxContainer/CardboardContainer/CardboardLabel
@onready var cardboard_icon: Label = $VBoxContainer/CardboardContainer/CardboardIcon

var wave_timer_label: Label = null

var player: Player = null

func _ready() -> void:
	# Player'ı bekle
	await get_tree().process_frame
	setup_player()
	setup_wave_timer()

func setup_player() -> void:
	player = Global.player
	if not player:
		# Player henüz hazır değilse, bir sonraki frame'de tekrar dene
		call_deferred("setup_player")
		return
	
	# Sinyallere bağlan
	player.health_component.on_health_changed.connect(_on_health_changed)
	player.on_level_up.connect(_on_level_up)
	player.on_experience_gained.connect(_on_experience_gained)
	player.on_cardboard_changed.connect(_on_cardboard_changed)
	
	# İlk güncelleme
	update_health()
	update_experience()
	update_cardboard()

func _on_health_changed(current: int, max_health: int) -> void:
	update_health()

func update_health() -> void:
	if not player or not player.health_component:
		return
	
	var current = player.health_component.current_health
	var max_health = player.health_component.max_health
	var ratio = float(current) / float(max_health) if max_health > 0 else 0.0
	
	health_bar.value = ratio
	health_label.text = "%d / %d" % [current, max_health]

func _on_experience_gained(current_exp: int, exp_needed: int) -> void:
	update_experience()

func _on_level_up(new_level: int) -> void:
	update_experience()

func update_experience() -> void:
	if not player:
		return
	
	var current_exp = player.experience
	var exp_needed = player.experience_needed
	var ratio = float(current_exp) / float(exp_needed) if exp_needed > 0 else 0.0
	
	exp_bar.value = ratio
	level_label.text = "LV.%d" % player.level

func _on_cardboard_changed(cardboard: int) -> void:
	update_cardboard()

func update_cardboard() -> void:
	if not player:
		return
	
	cardboard_label.text = str(player.cardboard)

func set_wave_timer_label(label: Label) -> void:
	wave_timer_label = label
	setup_wave_timer()

func setup_wave_timer() -> void:
	if not wave_timer_label:
		return
	# WaveManager sinyaline bağlan
	if has_node("/root/WaveManager"):
		var wave_mgr = get_node("/root/WaveManager")
		if not wave_mgr.wave_timer_updated.is_connected(_on_wave_timer_updated):
			wave_mgr.wave_timer_updated.connect(_on_wave_timer_updated)

func _on_wave_timer_updated(time_remaining: float) -> void:
	if not wave_timer_label:
		return
	# Saniye cinsinden göster (yukarı yuvarla)
	var seconds = int(ceil(time_remaining))
	wave_timer_label.text = str(seconds)
	
	# 5 saniyeden geriye sayarken beyazdan kırmızıya dönüş
	if seconds <= 5:
		# 5'ten 0'a kadar: beyaz (1,1,1) -> kırmızı (1,0,0)
		var t = float(seconds) / 5.0  # 5'te 1.0, 0'da 0.0
		var red = 1.0
		var green = t
		var blue = t
		wave_timer_label.modulate = Color(red, green, blue, 1.0)
	else:
		# 5'ten fazla ise beyaz
		wave_timer_label.modulate = Color.WHITE

