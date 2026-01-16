extends Node2D
class_name Arena

@export var player: Player

@export var normal_color: Color
@export var blockedl_color: Color
@export var critical_color: Color
@export var hp_color: Color

# Harita sınırları (harita merkezinde, boyutlar CarpetBG sprite'ına göre)
@export var map_bounds: Rect2 = Rect2(-1024, -1024, 2048, 2048) # x, y, width, height
# Güvenli oyun alanı sınırları (Logic için kullanılır, Collision ve Görsel sınırlar map_bounds'u kullanır)
var safe_bounds: Rect2

const PAUSE_MENU_SCENE = preload("res://scenes/ui/PauseMenu.tscn")
const WAVE_INFO_SCENE = preload("res://scenes/ui/wave_info.tscn")
const GAME_HUD_SCENE = preload("res://scenes/ui/game_hud.tscn")
const DEATH_SCREEN_SCENE = preload("res://scenes/ui/death_screen.tscn")
const UPGRADE_SCREEN_SCENE = preload("res://scenes/ui/upgrade_screen.tscn")
const TOUCH_CONTROLS_SCENE = preload("res://scenes/ui/TouchControls.tscn")
var pause_menu_instance: CanvasLayer = null
var wave_info_instance: Control = null
var game_hud_instance: Control = null
var death_screen_instance: CanvasLayer = null
var upgrade_screen_instance: CanvasLayer = null
var touch_controls_instance: CanvasLayer = null

var touch_move_dir: Vector2 = Vector2.ZERO

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
	Global.has_active_game = true # Oyun başladı, aktif oyun var
	if player:
		print("Player pos: ", player.global_position)
	
	# İlk eşya seçiminde weapon seçildiyse, player'a ekle
	if is_instance_valid(player):
		if Global.selected_starting_item.has("type") and Global.selected_starting_item.type == "weapon":
			if Global.selected_starting_item.has("weapon_data") and Global.selected_starting_item.weapon_data is ItemWeapon:
				var weapon_data = Global.selected_starting_item.weapon_data as ItemWeapon
				player.add_weapon(weapon_data)
				print("Başlangıç weapon'ı eklendi: ", weapon_data.item_name)
	else:
		push_error("Arena: Player oluşturulamadı, weapon eklenemedi!")
	
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

	# Mobil cihazlar için dokunmatik kontrolleri ekle
	_setup_touch_controls()

func _physics_process(_delta: float) -> void:
	# Dokunmatik hareket yönünü player'a aktar (Sadece referans olarak kalsın, player kendisi okuyacak)
	pass

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
	
	var random_pos := randf_range(0, TAU) * 35
	var spawn_pos := unit.global_position + Vector2.RIGHT.rotated(random_pos)
	
	instance.global_position = spawn_pos
	
	# Floating text'e font uygula (sayılar için)
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		var label = instance.get_node_or_null("ValueLabel")
		if label is Label:
			font_mgr.apply_font_to_label(label as Label)
	
	return instance
	

func _on_create_block_text(unit: Node2D) -> void:
	var text := create_floating_text(unit)
	text.setup("闪!", blockedl_color)
	

func _on_create_damage_text(uinit: Node2D, hitbox: HitboxComponent) -> void:
	var text := create_floating_text(uinit)
	var color := critical_color if hitbox.critical else normal_color
	text.setup(str(int(hitbox.damage)), color)

func _add_wave_ui() -> void:
	# Wave UI'ı CanvasLayer olarak ekle
	var wave_canvas = CanvasLayer.new()
	wave_canvas.name = "WaveUICanvas"
	# Pause butonunu en üstte göstermek için yüksek bir layer ver
	wave_canvas.layer = 100
	add_child(wave_canvas)
	
	wave_info_instance = WAVE_INFO_SCENE.instantiate() as Control
	wave_canvas.add_child(wave_info_instance)

func _add_game_hud() -> void:
	# Game HUD'u CanvasLayer olarak ekle
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "GameHUDCanvas"
	canvas_layer.layer = 101 # Wave Info'nun üzerinde olsun
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
	wave_timer_label.offset_top = 80.0
	wave_timer_label.offset_right = 100.0
	wave_timer_label.offset_bottom = 120.0
	wave_timer_label.text = "60"
	wave_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wave_timer_label.add_theme_font_size_override("font_size", 48)
	canvas_layer.add_child(wave_timer_label)
	
	# GameHUD'a wave timer referansı ver
	if game_hud_instance.has_method("set_wave_timer_label"):
		game_hud_instance.set_wave_timer_label(wave_timer_label)

	# Android/Dokunmatik cihazlar için pause butonu ekle
	if OS.get_name() == "Android" or OS.get_name() == "iOS" or DisplayServer.is_touchscreen_available():
		var pause_btn = Button.new()
		pause_btn.name = "MobilePauseButton"
		pause_btn.text = "II"
		pause_btn.add_theme_font_size_override("font_size", 32)
		pause_btn.custom_minimum_size = Vector2(60, 60)
		
		# Pozisyon: Sayacın üzerinde (Sayaç y:20 civarı başlıyor)
		pause_btn.set_anchors_preset(Control.PRESET_TOP_WIDE)
		pause_btn.anchor_left = 0.5
		pause_btn.anchor_right = 0.5
		pause_btn.offset_left = -30.0
		pause_btn.offset_top = 10.0 # Sayacın üzerine (sayaç 20'de başlıyor, buton 10-70 arası)
		pause_btn.offset_right = 30.0
		pause_btn.offset_bottom = 70.0
		
		# Görünüm: Şeffaf-ish
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		btn_style.corner_radius_top_left = 10
		btn_style.corner_radius_top_right = 10
		btn_style.corner_radius_bottom_right = 10
		btn_style.corner_radius_bottom_left = 10
		pause_btn.add_theme_stylebox_override("normal", btn_style)
		pause_btn.add_theme_stylebox_override("hover", btn_style)
		pause_btn.add_theme_stylebox_override("pressed", btn_style)
		
		# DURAKLATMA SIRASINDA ÇALIŞMASI İÇİN KRİTİK:
		pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		
		pause_btn.pressed.connect(_toggle_pause)
		canvas_layer.add_child(pause_btn)
		
		# Font uygula
		if has_node("/root/FontManager"):
			var font_mgr = get_node("/root/FontManager")
			font_mgr.apply_font_to_label(pause_btn)

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
	# Harita sınırlarını hesapla
	_calculate_map_bounds()
	
	# WaveManager'ı başlat ve harita sınırlarını ver
	if has_node("/root/WaveManager"):
		var wave_mgr = get_node("/root/WaveManager")
		wave_mgr.set_player(player)
		wave_mgr.set_map_bounds(safe_bounds) # Logic için güvenli sınırları kullan
		wave_mgr.wave_completed.connect(_on_wave_completed)
		wave_mgr.wave_started.connect(_on_wave_started)
		# İlk wave'i başlat
		wave_mgr.start_wave(1)

func _on_wave_started(_wave_number: int) -> void:
	# Her wave başlangıcında player'ı merkeze al
	if is_instance_valid(player):
		player.global_position = Vector2.ZERO
		
	# Her wave başlangıcında player'ın canını tam doldur
	if is_instance_valid(player) and player.health_component:
		player.health_component.current_health = player.health_component.max_health
		player.health_component.on_health_changed.emit(player.health_component.current_health, player.health_component.max_health)

func _on_wave_completed(wave_number: int) -> void:
	# Wave 20 tamamlandı mı kontrol et
	if wave_number >= 20:
		# Endless mode kontrolü
		var endless_mode = false
		if has_node("/root/Global"):
			var global = get_node("/root/Global")
			endless_mode = global.endless_mode
		
		if not endless_mode:
			# Normal mod: Oyun kazandı
			_show_victory_screen()
			return
		else:
			# Endless mode: Devam et
			print("Wave 20 tamamlandı! Endless mode devam ediyor...")
	print("Wave %d tamamlandı!" % wave_number)
	
	# Player'ın animasyonunu tamamen durdur
	if is_instance_valid(player):
		# Hareket yönünü sıfırla
		player.move_dir = Vector2.ZERO
		# Animasyonu durdur ve idle animasyonuna geç, sonra durdur
		if player.anim_player:
			# Önce idle animasyonuna geç
			player.anim_player.play("idle")
			# Animasyonu durdur (current frame'de kalır)
			player.anim_player.stop()
			# Animasyon player'ın speed'ini 0 yap (animasyonu tamamen durdur)
			player.anim_player.speed_scale = 0.0
			# Animasyon player'ın process_mode'unu değiştir (pause durumunda çalışmasın)
			player.anim_player.process_mode = Node.PROCESS_MODE_DISABLED
	
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
		# Animasyon player'ı tekrar aktif et
		if player.anim_player:
			player.anim_player.process_mode = Node.PROCESS_MODE_INHERIT
			# Animasyon speed'ini geri yükle
			player.anim_player.speed_scale = 1.0
	
	# Oyunu devam ettir
	get_tree().paused = false
	
	# Wave 20 tamamlandı mı kontrol et
	if wave_number >= 20:
		# Endless mode kontrolü
		var endless_mode = false
		if has_node("/root/Global"):
			var global = get_node("/root/Global")
			endless_mode = global.endless_mode
		
		if not endless_mode:
			# Normal mod: Oyun kazandı
			_show_victory_screen()
			return
	
	# Kısa bir bekleme sonrası bir sonraki wave'e geç
	await get_tree().create_timer(1.0).timeout
	
	if has_node("/root/WaveManager"):
		var wave_mgr = get_node("/root/WaveManager")
		var next_wave = wave_number + 1
		
		# Endless mode kontrolü
		var endless_mode = false
		if has_node("/root/Global"):
			var global = get_node("/root/Global")
			endless_mode = global.endless_mode
		
		# Normal modda maksimum 20 wave
		if not endless_mode and next_wave > 20:
			_show_victory_screen()
			return
		
		wave_mgr.start_wave(next_wave)
		
		# Oyun devam ettirildikten sonra timer'ın başlangıç değerini tekrar emit et
		# (UI güncellemesi için bir frame bekle)
		await get_tree().process_frame
		wave_mgr.wave_timer_updated.emit(wave_mgr.get_wave_timer())

func _show_wave_completed_message(_wave_number: int) -> void:
	# Wave tamamlandı mesajını ekranın ortasında göster
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "WaveCompletedMessage"
	
	var color_rect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 0.7) # Yarı şeffaf siyah arka plan
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
		# Signal connection is not strictly needed for flow control as we await screen_closed
	
	# Show Shop Mode
	if upgrade_screen_instance.has_method("show_shop"):
		upgrade_screen_instance.show_shop(wave_number)
	else:
		# Fallback for old scene if not updated properly
		print("Arena error: UpgradeScreen missing show_shop method")
		return
	
	# Upgrade ekranına font uygula
	await get_tree().process_frame
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		if upgrade_screen_instance and is_instance_valid(upgrade_screen_instance):
			font_mgr.apply_fonts_recursive(upgrade_screen_instance)
	
	# Ekran kapanana kadar bekle
	await upgrade_screen_instance.screen_closed

func _generate_weapon_selection() -> Array:
	# İlk wave için weapon seçimi
	var weapons: Array[ItemWeapon] = []
	
	# Weapon resource'larını bul (sadece seviye 1 weapon'lar)
	var weapon_paths = [
		"res://resources/items/weapons/melee/punch/item_punch_1.tres",
		"res://resources/items/weapons/melee/knife/item_knife_1.tres",
		"res://resources/items/weapons/range/pistol/item_pistol_1.tres"
	]
	
	# Mevcut weapon'ları yükle
	for path in weapon_paths:
		if ResourceLoader.exists(path):
			var weapon = load(path) as ItemWeapon
			if weapon:
				weapons.append(weapon)
				print("Arena: Weapon yüklendi: ", weapon.item_name, " (", path, ")")
			else:
				print("Arena: Uyarı - Weapon yüklenemedi (null): ", path)
		else:
			print("Arena: Uyarı - Weapon dosyası bulunamadı: ", path)
	
	print("Arena: Toplam ", weapons.size(), " weapon yüklendi")
	
	# İlk wave'de TÜM silahları göster
	var selected_weapons: Array[ItemWeapon] = weapons.duplicate()
	
	print("Arena: İlk wave - Tüm ", selected_weapons.size(), " weapon gösteriliyor")
	
	# Upgrade formatına çevir
	var upgrades = []
	for weapon in selected_weapons:
		# Weapon'ın item_name'ini kullan (ItemBase'den gelir)
		var weapon_name = weapon.item_name if weapon.item_name else "Weapon"
		var upgrade = {
			"name": weapon_name,
			"type": "weapon",
			"weapon_data": weapon
		}
		upgrades.append(upgrade)
	
	return upgrades

func _generate_upgrades() -> Array:
	# Normal wave'ler için upgrade'ler - gerçek upgrade sistemi eklendiğinde buraya gelecek
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
	var upgrade_name = upgrade_data.get("name", "Unknown")
	print("Upgrade seçildi: ", upgrade_name)
	
	# Eğer weapon seçildiyse, player'a ekle
	if upgrade_data.has("type") and upgrade_data.type == "weapon":
		if upgrade_data.has("weapon_data") and upgrade_data.weapon_data is ItemWeapon:
			var weapon_data = upgrade_data.weapon_data as ItemWeapon
			if is_instance_valid(player):
				player.add_weapon(weapon_data)
				print("Weapon eklendi: ", weapon_data.item_name)
	else:
		# Normal upgrade'i uygula - Dictionary içinde item_data varsa primary stats modifier'larını uygula
		# upgrade_data her zaman Dictionary olduğu için, içinde item_data olup olmadığını kontrol et
		if upgrade_data.has("item_data") and upgrade_data.item_data is ItemBase:
			var item = upgrade_data.item_data as ItemBase
			if is_instance_valid(player):
				item.apply_primary_stats_modifiers(player)
				print("Item primary stats modifier'ları uygulandı: ", item.item_name)
		elif upgrade_data.has("type"):
			# Dictionary formatında upgrade ise (eski sistem)
			# Eski upgrade sistemi - şimdilik boş
			pass

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

func _show_victory_screen() -> void:
	# Victory screen (şimdilik death screen'i kullan, sonra ayrı bir victory screen eklenebilir)
	var final_wave = 20
	var final_level = 0
	var final_cardboard = 0
	
	if has_node("/root/WaveManager"):
		var wave_mgr = get_node("/root/WaveManager")
		final_wave = wave_mgr.get_current_wave()
	
	if is_instance_valid(player):
		final_level = player.level
		final_cardboard = player.cardboard
	
	# Oyunu durdur
	get_tree().paused = true
	
	# Kısa bir bekleme sonrası victory ekranını göster
	await get_tree().create_timer(0.5).timeout
	_show_death_screen(final_wave, final_level, final_cardboard)

func get_map_bounds() -> Rect2:
	return map_bounds

func is_position_in_map(pos: Vector2) -> bool:
	return map_bounds.has_point(pos)

func clamp_position_to_map(pos: Vector2) -> Vector2:
	# Dikdörtgen sınırlandırma
	var bounds = map_bounds
	var margin = 50.0 # Kenar boşluğu
	
	var min_x = bounds.position.x + margin
	var max_x = bounds.end.x - margin
	var min_y = bounds.position.y + margin
	var max_y = bounds.end.y - margin
	
	var clamped_x = clamp(pos.x, min_x, max_x)
	var clamped_y = clamp(pos.y, min_y, max_y)
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
	# Oyun Alanı Sınırları - Dikdörtgen
	var arena_size = Vector2(2000, 2000) # Kare/Dikdörtgen boyut
	# Merkeze yerleştir
	map_bounds = Rect2(-arena_size.x / 2, -arena_size.y / 2, arena_size.x, arena_size.y)
	
	# Safe Bounds Hesaplama (Logic için)
	# Dikdörtgen olduğu için direkt map_bounds alınabilir veya biraz pay bırakılabilir
	safe_bounds = map_bounds
	# Kenarlardan biraz güvenli alan bırak
	safe_bounds = safe_bounds.grow(-50.0)

	# Arka plan düzeltmesi
	var carpet_bg = get_node_or_null("CarpetBG")
	if carpet_bg and carpet_bg is Sprite2D:
		var sprite = carpet_bg as Sprite2D
		
		# Manuel olarak görseli yüklemeyi dene
		var img_path = "res://assets/sprites/swamp_tile.png"
		var tex = load(img_path)
		
		if tex:
			sprite.texture = tex
			print("Arena: swamp_tile.png başarıyla yüklendi (ResourceLoader).")
		
		# Doku varsa (Fallback veya Yeni) ayarları uygula
		if sprite.texture:
			# Seamless/Repeating ayarları
			# TEXTURE_REPEAT_MIRROR kullanarak kenar çizgilerini gizlemeyi dene
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
			sprite.region_enabled = true
			
			# Harita sınırlarını genişlet (oyuncunun görebileceği kadar)
			var bg_rect = map_bounds.grow(2000.0)
			sprite.region_rect = Rect2(Vector2.ZERO, bg_rect.size)
			
			# Modülasyon (Texture rengini koru)
			sprite.modulate = Color(1, 1, 1, 1)
			
			# Merkezde kalması için pozisyon ayarı
			sprite.position = map_bounds.get_center()
			sprite.z_index = -11
			
			# Texture scale (dokunun sıklığı)
			sprite.scale = Vector2(1, 1)

	print("Harita sınırları ayarlandı: ", map_bounds)
	_draw_map_border()
	_create_physics_boundaries()
	_spawn_decorations()

func _spawn_decorations() -> void:
	# Eğer zaten dekorasyon varsa tekrar oluşturma (restart koruması)
	if has_node("Decorations"):
		return
		
	var decoration_holder = Node2D.new()
	decoration_holder.name = "Decorations"
	decoration_holder.y_sort_enabled = true # Dekorasyonlar kendi içinde de sıralansın
	add_child(decoration_holder)
	
	# Dekorasyon dosyaları
	var props = [
		"res://assets/sprites/noir_willow_tree.png",
		"res://assets/sprites/noir_crate_stack.png",
		"res://assets/sprites/noir_smooth_rock.png"
	]
	
	# Standart Godot resource loader kullanacağımız için manuel image loading'e gerek yok.
	
	# Rastgele dağıt
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	

	var decoration_count = 120
	var margin = 1200.0 # Daha geniş alan
	var spawn_offset = 250.0
	
	# Cluster merkezleri oluştur (Orman öbekleri)
	var clusters = []
	for k in range(12): # 12 ana öbek
		var side = rng.randi() % 4
		var c_pos = Vector2.ZERO
		var b = map_bounds
		var cluster_offset = rng.randf_range(300, 800)
		
		match side:
			0: c_pos = Vector2(rng.randf_range(b.position.x - margin, b.end.x + margin), b.position.y - spawn_offset - cluster_offset)
			1: c_pos = Vector2(rng.randf_range(b.position.x - margin, b.end.x + margin), b.end.y + spawn_offset + cluster_offset)
			2: c_pos = Vector2(b.position.x - spawn_offset - cluster_offset, rng.randf_range(b.position.y - margin, b.end.y + margin))
			3: c_pos = Vector2(b.end.x + spawn_offset + cluster_offset, rng.randf_range(b.position.y - margin, b.end.y + margin))
		clusters.append(c_pos)

	for i in range(decoration_count):
		# Standart Resource Loader kullan (Warning fix)
		# Texture listesinden rastgele seç
		var type_index = rng.randi() % props.size()
		var prop_path = props[type_index]
		var tex = load(prop_path)
		
		if not tex:
			continue
			
		var sprite = Sprite2D.new()
		sprite.texture = tex
		
		# Pozisyon belirleme: Cluster veya Rastgele
		var pos = Vector2.ZERO
		
		if rng.randf() > 0.3: # %70 ihtimalle bir cluster etrafında
			var cluster_center = clusters[rng.randi() % clusters.size()]
			# Cluster etrafında dağılım (Gaussian)
			var angle = rng.randf() * TAU
			var dist = rng.randf_range(0, 400)
			pos = cluster_center + Vector2(cos(angle), sin(angle)) * dist
		else:
			# Rastgele serpistirme (Bölge dışı)
			# ... (Eski mantıkla benzer ama daha basit)
			var side = rng.randi() % 4
			var b = map_bounds
			match side:
				0: pos = Vector2(rng.randf_range(b.position.x - margin, b.end.x + margin), b.position.y - spawn_offset - rng.randf() * margin)
				1: pos = Vector2(rng.randf_range(b.position.x - margin, b.end.x + margin), b.end.y + spawn_offset + rng.randf() * margin)
				2: pos = Vector2(b.position.x - spawn_offset - rng.randf() * margin, rng.randf_range(b.position.y - margin, b.end.y + margin))
				3: pos = Vector2(b.end.x + spawn_offset + rng.randf() * margin, rng.randf_range(b.position.y - margin, b.end.y + margin))
		
		sprite.position = pos
		
		# Depth/Fog Efekti
		# Merkeze olan uzaklığa göre rengi soluklaştır (Atmosphere)
		var dist_to_center = pos.distance_to(map_bounds.get_center())
		var fog_factor = clamp((dist_to_center - 1000.0) / 1500.0, 0.0, 0.8)
		# Uzaktakiler daha koyu ve hafif şeffaf
		var col_val = 1.0 - (fog_factor * 0.7)
		sprite.modulate = Color(col_val, col_val, col_val, 1.0)
		
		# Scale ve Varyasyon
		var s = rng.randf_range(0.15, 0.35)
		# Uzaktakiler daha küçük algılanabilir (Pseudo-perspective)
		s *= (1.0 - fog_factor * 0.3)
		sprite.scale = Vector2(s, s)
		
		if rng.randf() > 0.5: sprite.flip_h = true
		
		match type_index:
			1: sprite.rotation_degrees = rng.randf_range(-15, 15) # Crate
			2: sprite.rotation_degrees = rng.randf_range(0, 360) # Rock
			0: sprite.rotation_degrees = rng.randf_range(-5, 5) # Tree (hafif rüzgar yamukluğu)

		sprite.offset = Vector2(0, -tex.get_height() / 2.0)
		decoration_holder.add_child(sprite)


func _draw_map_border() -> void:
	# Eğer varsa eski border'ı temizle
	var old_border = get_node_or_null("MapBorder")
	if old_border:
		old_border.queue_free()
	
	# Yeni border (Line2D) oluştur
	var border = Line2D.new()
	border.name = "MapBorder"
	border.width = 12.0
	border.default_color = Color(0.9, 0.1, 0.1, 0.9) # Parlak kırmızı
	border.joint_mode = Line2D.LINE_JOINT_ROUND
	border.z_index = 0
	
	# Dikdörtgen noktaları
	var b = map_bounds
	var points = PackedVector2Array([
		b.position, # Sol üst
		Vector2(b.end.x, b.position.y), # Sağ üst
		b.end, # Sağ alt
		Vector2(b.position.x, b.end.y), # Sol alt
		b.position # Sol üst (kapat)
	])
	
	border.points = points
	add_child(border)

func _create_physics_boundaries() -> void:
	# Eğer varsa eski sınırları temizle
	var old_walls = get_node_or_null("PhysicsWalls")
	if old_walls:
		old_walls.queue_free()
		
	var walls_node = StaticBody2D.new()
	walls_node.name = "PhysicsWalls"
	walls_node.collision_layer = 1 # Environment layer
	add_child(walls_node)
	
	var b = map_bounds
	var margin = 200.0 # Duvar kalınlığı
	var wall_gap = 100.0 # Görsel sınırın ne kadar dışında başlasın (Forgiveness)
	
	# Sol Duvar
	_add_wall_polygon(walls_node, [
		Vector2(b.position.x - margin - wall_gap, b.position.y - margin),
		Vector2(b.position.x - wall_gap, b.position.y - margin),
		Vector2(b.position.x - wall_gap, b.end.y + margin),
		Vector2(b.position.x - margin - wall_gap, b.end.y + margin)
	])
	# Sağ Duvar
	_add_wall_polygon(walls_node, [
		Vector2(b.end.x + wall_gap, b.position.y - margin),
		Vector2(b.end.x + margin + wall_gap, b.position.y - margin),
		Vector2(b.end.x + margin + wall_gap, b.end.y + margin),
		Vector2(b.end.x + wall_gap, b.end.y + margin)
	])
	# Üst Duvar
	_add_wall_polygon(walls_node, [
		Vector2(b.position.x - wall_gap, b.position.y - margin - wall_gap),
		Vector2(b.end.x + wall_gap, b.position.y - margin - wall_gap),
		Vector2(b.end.x + wall_gap, b.position.y - wall_gap),
		Vector2(b.position.x - wall_gap, b.position.y - wall_gap)
	])
	# Alt Duvar
	_add_wall_polygon(walls_node, [
		Vector2(b.position.x - wall_gap, b.end.y + wall_gap),
		Vector2(b.end.x + wall_gap, b.end.y + wall_gap),
		Vector2(b.end.x + wall_gap, b.end.y + margin + wall_gap),
		Vector2(b.position.x - wall_gap, b.end.y + margin + wall_gap)
	])

func _add_wall_polygon(parent: Node, points: Array) -> void:
	var col = CollisionPolygon2D.new()
	col.polygon = PackedVector2Array(points)
	parent.add_child(col)
func _setup_touch_controls() -> void:
	# Sadece mobil ve dokunmatik destekli cihazlarda ekle
	if OS.get_name() == "Android" or OS.get_name() == "iOS" or DisplayServer.is_touchscreen_available():
		if not touch_controls_instance:
			touch_controls_instance = TOUCH_CONTROLS_SCENE.instantiate()
			add_child(touch_controls_instance)
			touch_controls_instance.touch_move.connect(_on_touch_move)
			touch_controls_instance.touch_dash.connect(_on_touch_dash)

func _on_touch_move(dir: Vector2) -> void:
	touch_move_dir = dir

func _on_touch_dash() -> void:
	# Input.action_press/release simülasyonu yapmak yerine direkt player metodunu çağırmak daha sağlıklı olabilir
	# ama InputMap üzerinden gitmek de bir seçenek. En temizi player'a bildirmek.
	if is_instance_valid(player) and player.has_method("start_dash"):
		if player.can_dash(true):
			player.start_dash()
