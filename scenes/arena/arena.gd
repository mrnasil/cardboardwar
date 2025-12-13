extends Node2D
class_name Arena

@export var player:Player

@export var normal_color:Color
@export var blockedl_color:Color
@export var critical_color:Color
@export var hp_color:Color

# Harita sınırları (harita merkezinde, boyutlar GrassBG sprite'ına göre)
@export var map_bounds: Rect2 = Rect2(-960, -1080, 1920, 2160)  # x, y, width, height

const PAUSE_MENU_SCENE = preload("res://scenes/ui/PauseMenu.tscn")
const WAVE_INFO_SCENE = preload("res://scenes/ui/wave_info.tscn")
const GAME_HUD_SCENE = preload("res://scenes/ui/game_hud.tscn")
const DEATH_SCREEN_SCENE = preload("res://scenes/ui/death_screen.tscn")
const UPGRADE_SCREEN_SCENE = preload("res://scenes/ui/upgrade_screen.tscn")
var pause_menu_instance: CanvasLayer = null
var wave_info_instance: Control = null
var game_hud_instance: Control = null
var death_screen_instance: CanvasLayer = null
var upgrade_screen_instance: CanvasLayer = null

func _ready() -> void:
	# Pause durumunda da input alabilmek için
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Player'ı yükle veya değiştir
	var character_to_load: String = ""
	
	# Seçilen karakteri kontrol et
	if Global.selected_character != "" and ResourceLoader.exists(Global.selected_character):
		character_to_load = Global.selected_character
		print("Global.selected_character bulundu: ", Global.selected_character)
	else:
		# Varsayılan karakteri kullan
		character_to_load = "res://scenes/unit/players/player_well_rounded.tscn"
		print("Varsayılan karakter kullanılıyor: ", character_to_load)
	
	# Mevcut player node'unu kontrol et ve değiştir
	var old_player_pos: Vector2 = Vector2.ZERO
	if player and is_instance_valid(player):
		old_player_pos = player.global_position
		# Eski player'ı kaldır
		remove_child(player)
		player.queue_free()
		player = null
		print("Eski player kaldırıldı")
	
	# Yeni karakteri yükle
	if ResourceLoader.exists(character_to_load):
		var character_scene = load(character_to_load) as PackedScene
		if character_scene:
			var new_player = character_scene.instantiate() as Player
			if new_player:
				add_child(new_player)
				if old_player_pos != Vector2.ZERO:
					new_player.global_position = old_player_pos
				player = new_player
				print("Karakter yüklendi: ", character_to_load)
			else:
				push_error("Karakter instantiate edilemedi: ", character_to_load)
		else:
			push_error("Karakter scene yüklenemedi: ", character_to_load)
	else:
		push_error("Karakter dosyası bulunamadı: ", character_to_load)
	
	Global.player = player
	Global.has_active_game = true  # Oyun başladı, aktif oyun var
	
	# OPTIMIZE: EnemyManager ve ObjectPool'u başlat
	if has_node("/root/EnemyManager"):
		var manager = get_node("/root/EnemyManager")
		manager.set_player(player)
	
	Global.on_create_block_text.connect(_on_create_block_text)
	Global.on_create_damage_text.connect(_on_create_damage_text)
	
	# Player ölüm sinyalini dinle (bir sonraki frame'de bağla)
	call_deferred("_connect_player_death_signal")
	
	# UI'ları ekle
	_add_wave_ui()
	_add_game_hud()
	
	# Font'ları uygula (UI'lar eklendikten sonra)
	call_deferred("_apply_fonts_to_ui")
	
	# Harita sınırlarını hesapla ve wave'i başlat (async olarak)
	_initialize_wave_system()

func _input(event: InputEvent) -> void:
	# Pause menüsü açıkken input'u pause menüye bırak
	if pause_menu_instance and is_instance_valid(pause_menu_instance) and pause_menu_instance.visible:
		return
	
	# Death screen açıkken input'u death screen'e bırak
	if death_screen_instance and is_instance_valid(death_screen_instance) and death_screen_instance.visible:
		return
	
	# Upgrade ekranı açıkken sadece pause input'unu engelle
	if upgrade_screen_instance and is_instance_valid(upgrade_screen_instance) and upgrade_screen_instance.visible:
		# Sadece pause input'unu engelle, diğer input'lar upgrade ekranında işlenecek
		if event.is_action_pressed("ui_cancel") and not (event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == 6):
			return
		
	# ESC veya gamepad Start butonu ile pause/unpause
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	# Gamepad Start butonu (button_index 6) ile pause/unpause
	if event is InputEventJoypadButton:
		var joypad_event = event as InputEventJoypadButton
		# Start butonu genellikle button_index 6'dır
		if joypad_event.button_index == 6 and joypad_event.pressed:
			_toggle_pause()
			get_viewport().set_input_as_handled()
			return

func _toggle_pause() -> void:
	if get_tree().paused:
		# Oyun zaten durdurulmuş, devam ettir
		get_tree().paused = false
		_clear_pause_menu()
	else:
		# Oyunu durdur
		get_tree().paused = true
		# Pause menüsünü göster (sadece yoksa oluştur)
		if not pause_menu_instance or not is_instance_valid(pause_menu_instance):
			pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
			# CanvasLayer olduğu için direkt root'a ekle
			get_tree().root.add_child(pause_menu_instance)

func _clear_pause_menu() -> void:
	if pause_menu_instance and is_instance_valid(pause_menu_instance):
		pause_menu_instance.queue_free()
		pause_menu_instance = null

func create_floating_text(unit: Node2D) -> FloatingText:
	# OPTIMIZE: Object Pooling kullan
	var instance: FloatingText
	if has_node("/root/ObjectPool"):
		var pool = get_node("/root/ObjectPool")
		instance = pool.get_floating_text()
	else:
		instance = Global.FLOATING_TEXT_SCENE.instantiate() as FloatingText
	
	if not instance.get_parent():
		get_tree().root.add_child(instance)
	
	var random_pos := randf_range(0,TAU) * 35
	var spawn_pos := unit.global_position + Vector2.RIGHT.rotated(random_pos)
	
	instance.global_position = spawn_pos
	
	# Floating text'e font uygula (sayılar için)
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		var label = instance.get_node_or_null("ValueLabel")
		if label is Label:
			font_mgr.apply_font_to_label(label as Label)
	
	return instance
	

func _on_create_block_text(unit:Node2D) -> void:
	var text := create_floating_text(unit)
	text.setup("闪!",blockedl_color)
	

func _on_create_damage_text(uinit:Node2D,hitbox:HitboxComponent) -> void:
	var text := create_floating_text(uinit)
	var color := critical_color if hitbox.critical else normal_color
	text.setup(str(int(hitbox.damage)),color)

func _add_wave_ui() -> void:
	# Wave UI'ı CanvasLayer olarak ekle
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "WaveUICanvas"
	add_child(canvas_layer)
	
	wave_info_instance = WAVE_INFO_SCENE.instantiate() as Control
	canvas_layer.add_child(wave_info_instance)

func _add_game_hud() -> void:
	# Game HUD'u CanvasLayer olarak ekle
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "GameHUDCanvas"
	add_child(canvas_layer)
	
	game_hud_instance = GAME_HUD_SCENE.instantiate() as Control
	canvas_layer.add_child(game_hud_instance)
	
	# Wave timer label'ı ekranın ortasına ekle
	var wave_timer_label = Label.new()
	wave_timer_label.name = "WaveTimerLabel"
	wave_timer_label.anchors_preset = Control.PRESET_TOP_WIDE
	wave_timer_label.anchor_left = 0.5
	wave_timer_label.anchor_top = 0.0
	wave_timer_label.anchor_right = 0.5
	wave_timer_label.anchor_bottom = 0.0
	wave_timer_label.offset_left = -100.0
	wave_timer_label.offset_top = 20.0
	wave_timer_label.offset_right = 100.0
	wave_timer_label.offset_bottom = 60.0
	wave_timer_label.text = "60"
	wave_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_timer_label.add_theme_font_size_override("font_size", 48)
	canvas_layer.add_child(wave_timer_label)
	
	# GameHUD'a wave timer referansı ver
	if game_hud_instance.has_method("set_wave_timer_label"):
		game_hud_instance.set_wave_timer_label(wave_timer_label)

func _connect_player_death_signal() -> void:
	# Player ölüm sinyalini bağla
	if is_instance_valid(player) and player.health_component:
		if not player.health_component.on_unit_died.is_connected(_on_player_died):
			player.health_component.on_unit_died.connect(_on_player_died)

func _initialize_wave_system() -> void:
	# Async olarak harita sınırlarını hesapla ve wave'i başlat
	# Bu fonksiyon await kullanabilir çünkü _ready()'den sonra çağrılıyor
	call_deferred("_setup_wave_system_async")

func _setup_wave_system_async() -> void:
	# Sprite'ların yüklenmesini bekle
	await get_tree().process_frame
	await get_tree().process_frame  # Bir frame daha bekle (güvenli)
	
	# Harita sınırlarını hesapla
	_calculate_map_bounds()
	
	# WaveManager'ı başlat ve harita sınırlarını ver
	if has_node("/root/WaveManager"):
		var wave_mgr = get_node("/root/WaveManager")
		wave_mgr.set_player(player)
		wave_mgr.set_map_bounds(map_bounds)  # ÖNCE harita sınırlarını set et
		wave_mgr.wave_completed.connect(_on_wave_completed)
		wave_mgr.wave_started.connect(_on_wave_started)
		# İlk wave'i başlat
		wave_mgr.start_wave(1)

func _on_wave_started(wave_number: int) -> void:
	# Her wave başlangıcında player'ın canını tam doldur
	if is_instance_valid(player) and player.health_component:
		player.health_component.current_health = player.health_component.max_health
		player.health_component.on_health_changed.emit(player.health_component.current_health, player.health_component.max_health)

func _on_wave_completed(wave_number: int) -> void:
	print("Wave %d tamamlandı!" % wave_number)
	
	# Oyunu durdur - hiçbir şey hareket etmemeli
	get_tree().paused = true
	
	# Pause menüsü açıksa upgrade ekranını gösterme
	if pause_menu_instance and is_instance_valid(pause_menu_instance) and pause_menu_instance.visible:
		return
	
	# Wave tamamlandı mesajını göster
	await _show_wave_completed_message(wave_number)
	
	# Upgrade ekranını göster ve seçilene kadar bekle
	await _show_upgrade_screen(wave_number)
	
	# Tüm düşmanları temizle (önceki wave'den kalan düşmanlar olmamalı)
	if has_node("/root/EnemyManager"):
		var enemy_mgr = get_node("/root/EnemyManager")
		enemy_mgr.clear_all_enemies()
	
	# Spawn queue'yu da temizle
	if has_node("/root/SpawnManager"):
		var spawn_mgr = get_node("/root/SpawnManager")
		spawn_mgr.clear_queue()
	
	# Player'ın process_mode'unu geri yükle (upgrade ekranında disabled olabilir)
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Oyunu devam ettir
	get_tree().paused = false
	
	# Kısa bir bekleme sonrası bir sonraki wave'e geç
	await get_tree().create_timer(1.0).timeout
	
	if has_node("/root/WaveManager"):
		var wave_mgr = get_node("/root/WaveManager")
		wave_mgr.start_wave(wave_number + 1)
		
		# Oyun devam ettirildikten sonra timer'ın başlangıç değerini tekrar emit et
		# (UI güncellemesi için bir frame bekle)
		await get_tree().process_frame
		wave_mgr.wave_timer_updated.emit(wave_mgr.get_wave_timer())

func _show_wave_completed_message(wave_number: int) -> void:
	# Wave tamamlandı mesajını ekranın ortasında göster
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "WaveCompletedMessage"
	
	var color_rect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 0.7)  # Yarı şeffaf siyah arka plan
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(color_rect)
	
	var label = Label.new()
	label.text = "Wave Tamamlandı!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 72)
	label.modulate = Color.WHITE
	# Ekranın tam ortasına yerleştir
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.offset_left = -300.0
	label.offset_top = -36.0
	label.offset_right = 300.0
	label.offset_bottom = 36.0
	canvas_layer.add_child(label)
	
	# CanvasLayer'ı ekle
	get_tree().root.add_child(canvas_layer)
	
	# Font'u uygula
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_font_to_label(label)
	
	# 2 saniye bekle
	await get_tree().create_timer(2.0).timeout
	
	# Mesajı kaldır
	canvas_layer.queue_free()

func _show_upgrade_screen(wave_number: int) -> void:
	# Upgrade ekranını oluştur (yoksa)
	if not upgrade_screen_instance or not is_instance_valid(upgrade_screen_instance):
		upgrade_screen_instance = UPGRADE_SCREEN_SCENE.instantiate() as CanvasLayer
		get_tree().root.add_child(upgrade_screen_instance)
		upgrade_screen_instance.upgrade_selected.connect(_on_upgrade_selected)
	
	# Örnek upgrade'ler oluştur (gerçek upgrade sistemi eklendiğinde buraya gelecek)
	var upgrades = _generate_upgrades()
	upgrade_screen_instance.show_upgrades(upgrades)
	
	# Upgrade ekranına font uygula
	await get_tree().process_frame
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		if upgrade_screen_instance and is_instance_valid(upgrade_screen_instance):
			font_mgr.apply_fonts_recursive(upgrade_screen_instance)
	
	# Ekran kapanana kadar bekle
	await upgrade_screen_instance.screen_closed

func _generate_upgrades() -> Array:
	# Örnek upgrade'ler - gerçek upgrade sistemi eklendiğinde buraya gelecek
	var upgrades = []
	
	# 3 rastgele upgrade oluştur
	for i in range(3):
		var upgrade = {
			"name": "Upgrade %d" % (i + 1),
			"type": "stat",
			"value": 1.0
		}
		upgrades.append(upgrade)
	
	return upgrades

func _on_upgrade_selected(upgrade_data: Dictionary) -> void:
	print("Upgrade seçildi: ", upgrade_data.name)
	# Upgrade'i uygula (gerçek upgrade sistemi eklendiğinde buraya gelecek)

func _on_player_died() -> void:
	# Oyunu durdur
	get_tree().paused = true
	
	# İstatistikleri topla (player silinmeden önce)
	var final_wave = 0
	var final_level = 1
	var final_cardboard = 0
	
	if has_node("/root/WaveManager"):
		var wave_mgr = get_node("/root/WaveManager")
		final_wave = wave_mgr.get_current_wave()
	
	if is_instance_valid(player):
		final_level = player.level
		final_cardboard = player.cardboard
	
	# Kısa bir bekleme sonrası ölüm ekranını göster
	await get_tree().create_timer(0.5).timeout
	_show_death_screen(final_wave, final_level, final_cardboard)

func _show_death_screen(wave: int, level: int, cardboard: int) -> void:
	# Ölüm ekranını oluştur
	if not death_screen_instance or not is_instance_valid(death_screen_instance):
		death_screen_instance = DEATH_SCREEN_SCENE.instantiate() as CanvasLayer
		get_tree().root.add_child(death_screen_instance)
	
	death_screen_instance.setup(wave, level, cardboard)
	
	# Death screen'e font uygula
	await get_tree().process_frame
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		if death_screen_instance and is_instance_valid(death_screen_instance):
			font_mgr.apply_fonts_recursive(death_screen_instance)

func get_map_bounds() -> Rect2:
	return map_bounds

func is_position_in_map(pos: Vector2) -> bool:
	return map_bounds.has_point(pos)

func clamp_position_to_map(pos: Vector2) -> Vector2:
	# Godot 4'te Rect2.clamp() yok, manuel clamp yapıyoruz
	var clamped_x = clamp(pos.x, map_bounds.position.x, map_bounds.position.x + map_bounds.size.x)
	var clamped_y = clamp(pos.y, map_bounds.position.y, map_bounds.position.y + map_bounds.size.y)
	return Vector2(clamped_x, clamped_y)

func _apply_fonts_to_ui() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	# Tüm UI'lara font uygula
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		
		print("FontManager: UI'lara font uygulanıyor...")
		print("  - number_font: ", font_mgr.number_font != null)
		print("  - text_font: ", font_mgr.text_font != null)
		
		# Wave UI'ya font uygula
		if wave_info_instance and is_instance_valid(wave_info_instance):
			font_mgr.apply_fonts_recursive(wave_info_instance)
		
		# Game HUD'a font uygula
		if game_hud_instance and is_instance_valid(game_hud_instance):
			font_mgr.apply_fonts_recursive(game_hud_instance)
		
		# Wave timer label'a font uygula (sayılar için)
		var wave_timer_label = null
		# CanvasLayer içinde ara
		for child in get_tree().root.get_children():
			if child is CanvasLayer:
				var found = child.get_node_or_null("WaveTimerLabel")
				if found:
					wave_timer_label = found
					break
		
		if wave_timer_label is Label:
			font_mgr.apply_font_to_label(wave_timer_label as Label)
	else:
		print("FontManager: FontManager bulunamadı!")

func _calculate_map_bounds() -> void:
	# Basit harita sınırları - sabit boyutlar kullan
	# GrassBG scale = Vector2(2, 4) ve genellikle harita merkezde
	# Daha geniş harita sınırları - düşmanlar kenarlara gelebilir
	# Export'taki değerlerle tutarlı olmalı
	map_bounds = Rect2(-960, -1080, 1920, 2160)
	print("Harita sınırları ayarlandı: ", map_bounds)
	
	# İsteğe bağlı: GrassBG'den hesaplama (şimdilik kapalı - sorunlu)
	# var grass_bg = get_node_or_null("GrassBG")
	# if grass_bg and grass_bg is Sprite2D:
	# 	var sprite = grass_bg as Sprite2D
	# 	if sprite.texture:
	# 		var texture_size = sprite.texture.get_size()
	# 		var scale = sprite.scale
	# 		var actual_size = texture_size * scale
	# 		var sprite_pos = sprite.position
	# 		var half_width = actual_size.x / 2.0
	# 		var half_height = actual_size.y / 2.0
	# 		map_bounds = Rect2(
	# 			sprite_pos.x - half_width,
	# 			sprite_pos.y - half_height,
	# 			actual_size.x,
	# 			actual_size.y
	# 		)
	# 		print("Harita sınırları GrassBG'den hesaplandı: ", map_bounds)
