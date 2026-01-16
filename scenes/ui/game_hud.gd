extends Control
class_name GameHUD

@onready var health_bar: ProgressBar = $VBoxContainer/HealthBar/ProgressBar
@onready var health_label: Label = $VBoxContainer/HealthBar/HealthLabel
@onready var exp_bar: ProgressBar = $VBoxContainer/ExpBar/ProgressBar
@onready var level_label: Label = $VBoxContainer/ExpBar/LevelLabel
@onready var cardboard_label: Label = $VBoxContainer/CardboardContainer/CardboardLabel
@onready var cardboard_icon: Label = $VBoxContainer/CardboardContainer/CardboardIcon

var damage_meter_container: VBoxContainer
var total_damage_label: Label
var weapon_damage_container: VBoxContainer
var weapon_labels: Dictionary = {} # weapon -> label mapping

var wave_timer_label: Label = null

var player: Player = null
var stats_tooltip: StatsTooltip = null

func _ready() -> void:
	# Player'ı bekle
	await get_tree().process_frame
	setup_player()
	setup_wave_timer()
	setup_stats_tooltip()
	setup_damage_meter()


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
	player.on_damage_dealt.connect(_on_damage_dealt)
	
	# İlk güncelleme
	update_health()
	update_experience()
	update_cardboard()
	
	# Damage meter ikonunu güncelle
	if damage_meter_container and player.sprite:
		var total_icon = damage_meter_container.find_child("TotalIcon", true, false)
		if total_icon and total_icon is TextureRect:
			total_icon.texture = player.sprite.texture

func _on_health_changed(_current: int, _max_health: int) -> void:
	update_health()

func update_health() -> void:
	if not player or not player.health_component:
		return
	
	var current = player.health_component.current_health
	var max_health = player.health_component.max_health
	var ratio = float(current) / float(max_health) if max_health > 0 else 0.0
	
	health_bar.value = ratio
	health_label.text = "%d / %d" % [current, max_health]

func _on_experience_gained(_current_exp: int, _exp_needed: int) -> void:
	update_experience()

func _on_level_up(_new_level: int) -> void:
	update_experience()

func update_experience() -> void:
	if not player:
		return
	
	var current_exp = player.experience
	var exp_needed = player.experience_needed
	var ratio = float(current_exp) / float(exp_needed) if exp_needed > 0 else 0.0
	
	exp_bar.value = ratio
	level_label.text = "LV.%d" % player.level

func _on_cardboard_changed(_cardboard: int) -> void:
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
		var t = float(seconds) / 5.0 # 5'te 1.0, 0'da 0.0
		var red = 1.0
		var green = t
		var blue = t
		wave_timer_label.modulate = Color(red, green, blue, 1.0)
	else:
		# 5'ten fazla ise beyaz
		wave_timer_label.modulate = Color.WHITE

func setup_stats_tooltip() -> void:
	# Stats tooltip'i oluştur
	stats_tooltip = _create_stats_tooltip()
	if stats_tooltip:
		get_tree().root.add_child(stats_tooltip)
		stats_tooltip.z_index = 1000 # Üstte göster

func _create_stats_tooltip() -> StatsTooltip:
	var tooltip = StatsTooltip.new()
	
	# Background panel
	var background = Panel.new()
	background.name = "Background"
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	bg_style.border_color = Color(0.5, 0.5, 0.5, 1.0)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_right = 8
	bg_style.corner_radius_bottom_left = 8
	background.add_theme_stylebox_override("panel", bg_style)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	tooltip.add_child(background)
	
	# VBoxContainer
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	tooltip.add_child(vbox)
	
	# Title label
	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Stats"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	
	# Stats container
	var stats_container = VBoxContainer.new()
	stats_container.name = "StatsContainer"
	vbox.add_child(stats_container)
	
	# Size ayarla
	tooltip.custom_minimum_size = Vector2(300, 400)
	
	return tooltip

func setup_damage_meter() -> void:
	# Main VBoxContainer'ı bul
	var main_vbox = get_node_or_null("VBoxContainer")
	if not main_vbox:
		return
	
	# Damage Meter Container
	damage_meter_container = VBoxContainer.new()
	damage_meter_container.name = "DamageMeter"
	damage_meter_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_meter_container.add_theme_constant_override("separation", 5)
	
	# Health bar'ın altına ekle
	main_vbox.add_child(damage_meter_container)
	# HealthBar, ExpBar, CardboardContainer var. Bunların altına koyalım.
	main_vbox.move_child(damage_meter_container, 3)
	
	# Total Damage Panel (Arka plan için)
	var total_panel = PanelContainer.new()
	total_panel.name = "TotalDamagePanel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.85, 0.65, 0.15, 0.9) # Altın sarısı, hafif şeffaf
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 5
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	total_panel.add_theme_stylebox_override("panel", style)
	damage_meter_container.add_child(total_panel)
	
	# Total Damage HBox
	var total_hbox = HBoxContainer.new()
	total_hbox.name = "TotalDamageHBox"
	total_hbox.add_theme_constant_override("separation", 10)
	total_panel.add_child(total_hbox)
	
	# Total Damage Icon
	var total_icon = TextureRect.new()
	total_icon.name = "TotalIcon"
	total_icon.custom_minimum_size = Vector2(28, 28)
	total_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	total_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if player and player.sprite:
		total_icon.texture = player.sprite.texture
	total_hbox.add_child(total_icon)
	
	# Total Damage Label
	total_damage_label = Label.new()
	total_damage_label.name = "TotalDamageLabel"
	total_damage_label.text = "0"
	total_damage_label.add_theme_font_size_override("font_size", 22)
	total_damage_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1)) # Koyu yazı (sarı üstüne)
	total_damage_label.add_theme_color_override("font_outline_color", Color.WHITE)
	total_damage_label.add_theme_constant_override("outline_size", 1)
	total_hbox.add_child(total_damage_label)
	
	# Weapon Damage Container
	weapon_damage_container = VBoxContainer.new()
	weapon_damage_container.name = "WeaponDamageContainer"
	weapon_damage_container.add_theme_constant_override("separation", 2)
	damage_meter_container.add_child(weapon_damage_container)
	
	# Margin ekle (Silahların biraz içeriden başlaması için)
	# weapon_damage_container.set_offsets_preset(Control.PRESET_FULL_RECT) - GEREKSİZ, Layout Container yönetiyor


func _on_damage_dealt(total_damage: float, weapon_damage: float, weapon: Weapon) -> void:
	if not total_damage_label:
		return
	
	total_damage_label.text = str(int(total_damage))
	
	if is_instance_valid(weapon):
		update_weapon_damage_ui(weapon, weapon_damage)

func update_weapon_damage_ui(weapon: Weapon, damage: float) -> void:
	if not weapon_damage_container:
		return
		
	if not weapon_labels.has(weapon):
		# Yeni weapon satırı oluştur
		var hbox = HBoxContainer.new()
		hbox.name = "Weapon_" + str(weapon.get_instance_id())
		weapon_damage_container.add_child(hbox)
		
		# Weapon Icon
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if weapon.sprite:
			icon.texture = weapon.sprite.texture
		hbox.add_child(icon)
		
		# Weapon Damage Label
		var label = Label.new()
		label.text = str(int(damage))
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1, 0.8, 0.4)) # Hafif sarı
		hbox.add_child(label)
		
		weapon_labels[weapon] = label
		
		# Weapon silindiğinde cleanup yap
		weapon.tree_exiting.connect(func():
			if is_instance_valid(hbox):
				hbox.queue_free()
			weapon_labels.erase(weapon)
		)
	else:
		weapon_labels[weapon].text = str(int(damage))
