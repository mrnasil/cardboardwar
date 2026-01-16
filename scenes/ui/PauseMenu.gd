extends CanvasLayer

# const StatsTooltip = preload("res://scenes/ui/stats_tooltip.gd")

const UIThemeManager = preload("res://autoloads/ui_themes.gd")

var continue_button: Button
var settings_button: Button
var main_menu_button: Button
var control: Control
var stats_tooltip: StatsTooltip = null
var stats_container: VBoxContainer = null

func _ready() -> void:
	# Pause menüsü pause sırasında da çalışmalı - AWAIT'DEN ÖNCE OLMALI
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Node'ları manuel olarak bul - await ile bir frame bekle
	await get_tree().process_frame
	
	control = get_node_or_null("Control")
	if not control:
		push_error("PauseMenu: Control node'u bulunamadı!")
		return
	
	var hbox = control.get_node_or_null("HBoxContainer")
	if not hbox:
		push_error("PauseMenu: HBoxContainer bulunamadı!")
		return
	
	var left_panel = hbox.get_node_or_null("LeftPanel")
	if not left_panel:
		push_error("PauseMenu: LeftPanel bulunamadı!")
		return
	
	var left_center = left_panel.get_node_or_null("CenterContainer")
	if not left_center:
		push_error("PauseMenu: LeftPanel/CenterContainer bulunamadı!")
		return
	
	var left_vbox = left_center.get_node_or_null("VBoxContainer")
	if not left_vbox:
		push_error("PauseMenu: LeftPanel/CenterContainer/VBoxContainer bulunamadı!")
		return
	
	continue_button = left_vbox.get_node_or_null("ContinueButton")
	settings_button = left_vbox.get_node_or_null("SettingsButton")
	main_menu_button = left_vbox.get_node_or_null("MainMenuButton")
	
	# Butonların null olup olmadığını kontrol et
	if not continue_button or not settings_button or not main_menu_button:
		push_error("PauseMenu: Butonlar bulunamadı! ContinueButton: %s, SettingsButton: %s, MainMenuButton: %s" % [continue_button, settings_button, main_menu_button])
		return
	
	# Butonları sinyallere bağla
	continue_button.pressed.connect(_on_continue_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	
	# Butonların focus modunu ayarla (gamepad için)
	continue_button.focus_mode = Control.FOCUS_ALL
	settings_button.focus_mode = Control.FOCUS_ALL
	main_menu_button.focus_mode = Control.FOCUS_ALL
	
	# İlk butona focus ver (gamepad için)
	continue_button.grab_focus()
	
	# Theme uygula
	_apply_theme()
	
	# Butonlar arası gezinme için bağlantıları ayarla

func _apply_theme() -> void:
	if not UIThemeManager:
		return
		
	# Buton stilleri
	UIThemeManager.apply_theme_to_button(continue_button)
	UIThemeManager.apply_theme_to_button(settings_button)
	UIThemeManager.apply_theme_to_button(main_menu_button)
	
	# Background
	var bg = get_node_or_null("Control/Background")
	if bg and bg is ColorRect:
		bg.color = UIThemeManager.COLOR_BACKGROUND_OVERLAY
	
	# Butonlar arası gezinme için bağlantıları ayarla
	continue_button.focus_neighbor_bottom = settings_button.get_path()
	settings_button.focus_neighbor_top = continue_button.get_path()
	settings_button.focus_neighbor_bottom = main_menu_button.get_path()
	main_menu_button.focus_neighbor_top = settings_button.get_path()
	
	# Pause menüsü pause sırasında da çalışmalı (yukarıda da set edildi ama garanti olsun)
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	# Ekranın tamamını kapsaması için
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	# PRESET_FULL_RECT kullanıldığında size ve position otomatik ayarlanır
	
	# Font'ları uygula
	call_deferred("_apply_fonts")
	
	# Stats tooltip'i oluştur
	setup_stats_tooltip()
	
	# Stats container'ı oluştur
	setup_stats_display()

func _apply_fonts() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)

func _input(event: InputEvent) -> void:
	# ESC veya Start butonu ile devam et
	if event.is_action_pressed("ui_cancel"):
		if continue_button:
			_on_continue_button_pressed()
		get_viewport().set_input_as_handled()
		return
	
	# Gamepad A/X butonu ile seçim
	if event.is_action_pressed("ui_accept"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.pressed.emit()
		get_viewport().set_input_as_handled()
		return
	
	# Direkt gamepad butonu kontrolü (A/X = button 0)
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed and joy_event.button_index == 0: # A/X butonu
			var focused = get_viewport().gui_get_focus_owner()
			if focused is Button:
				focused.pressed.emit()
			get_viewport().set_input_as_handled()
			return

func _on_continue_button_pressed() -> void:
	# Oyunu devam ettir
	get_tree().paused = false
	# Arena'daki pause_menu_instance referansını temizle
	var arena = get_tree().current_scene
	if arena and arena.has_method("_clear_pause_menu"):
		arena._clear_pause_menu()
	queue_free()

func _on_settings_button_pressed() -> void:
	# Ayarlar menüsünü overlay olarak göster (scene değiştirmeden, oyun durumu korunur)
	Global.from_pause_menu = true
	# Pause menüsünü gizle (ayarlar menüsüne geçerken üst üste binmesin)
	visible = false
	
	# SettingsMenu'yu instantiate et ve root'a ekle
	const SETTINGS_MENU_SCENE = preload("res://scenes/ui/SettingsMenu.tscn")
	var settings_menu = SETTINGS_MENU_SCENE.instantiate()
	# CanvasLayer olarak ekle (pause menüsü gibi)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "SettingsMenuCanvas"
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS # Pause durumunda da çalışsın
	canvas_layer.add_child(settings_menu)
	get_tree().root.add_child(canvas_layer)
	# SettingsMenu'nun geri döndüğünde pause menüsünü tekrar göstermesi için referans ver
	if settings_menu.has_method("set_pause_menu_reference"):
		settings_menu.set_pause_menu_reference(self)

func _on_main_menu_button_pressed() -> void:
	# Oyunu durdur ve ana menüye dön
	get_tree().paused = false
	Global.has_active_game = false
	Global.selected_character = ""
	Global.selected_difficulty = 0
	Global.selected_starting_item = {}
	
	# Arena'daki pause_menu_instance referansını temizle
	var arena = get_tree().current_scene
	if arena and arena.has_method("_clear_pause_menu"):
		arena._clear_pause_menu()
	
	# WaveManager'daki wave_completed sinyalini bağlantısını kes
	if has_node("/root/WaveManager") and arena:
		var wave_mgr = get_node("/root/WaveManager")
		# Godot 4'te is_connected() 2 parametre alır: signal ve callable
		var callable = Callable(arena, "_on_wave_completed")
		if wave_mgr.wave_completed.is_connected(callable):
			wave_mgr.wave_completed.disconnect(callable)
	
	# Pause menüsünü temizle
	queue_free()
	# Ana menüye geç
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func setup_stats_tooltip() -> void:
	# Stats tooltip'i oluştur
	stats_tooltip = _create_stats_tooltip()
	if stats_tooltip:
		get_tree().root.add_child(stats_tooltip)
		stats_tooltip.z_index = 1000

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
	# Stats container
	var tooltip_stats_container = VBoxContainer.new()
	tooltip_stats_container.name = "StatsContainer"
	vbox.add_child(tooltip_stats_container)
	
	# Size ayarla
	tooltip.custom_minimum_size = Vector2(300, 400)
	
	return tooltip

func setup_stats_display() -> void:
	if not control:
		return
	
	# HBoxContainer'ı bul
	var hbox = control.get_node_or_null("HBoxContainer")
	if not hbox:
		return
	
	# RightPanel'i bul
	var right_panel = hbox.get_node_or_null("RightPanel")
	if not right_panel:
		# RightPanel yoksa oluştur - Panel olarak oluştur (siyah arka plan için)
		right_panel = Panel.new()
		right_panel.name = "RightPanel"
		right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# RightPanel'in arka planını siyah yap
		var right_panel_style = StyleBoxFlat.new()
		right_panel_style.bg_color = Color.BLACK
		right_panel.add_theme_stylebox_override("panel", right_panel_style)
		hbox.add_child(right_panel)
	
	# Stats container için Panel oluştur (arka plan için)
	var stats_panel = Panel.new()
	stats_panel.name = "StatsPanel"
	stats_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel_style = StyleBoxEmpty.new()
	stats_panel.add_theme_stylebox_override("panel", panel_style)
	right_panel.add_child(stats_panel)
	
	# TabContainer oluştur (Birincil/Ikincil sekmeleri için)
	var tab_container = TabContainer.new()
	tab_container.name = "TabContainer"
	tab_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_container.offset_left = 20
	tab_container.offset_right = -20
	tab_container.offset_top = 10
	tab_container.offset_bottom = 0
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_panel.add_child(tab_container)
	
	# Birincil stats container
	var primary_container = VBoxContainer.new()
	primary_container.name = "PrimaryStatsContainer"
	primary_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	primary_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.add_child(primary_container)
	tab_container.set_tab_title(0, "Birincil")
	
	# CenterContainer - stats'leri yatayda ortalı
	var stats_center = CenterContainer.new()
	stats_center.name = "StatsCenter"
	stats_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	primary_container.add_child(stats_center)
	
	# Stats container - VBoxContainer
	var _stats_container_local = VBoxContainer.new()
	_stats_container_local.name = "ContentContainer"
	_stats_container_local.add_theme_constant_override("separation", 3)
	stats_center.add_child(_stats_container_local)
	
	# Member variable'ı güncelle
	stats_container = _stats_container_local
	
	# Ikincil stats container (şimdilik boş, gelecekte eklenebilir)
	var secondary_container = VBoxContainer.new()
	secondary_container.name = "SecondaryStatsContainer"
	secondary_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	secondary_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.add_child(secondary_container)
	tab_container.set_tab_title(1, "Ikincil")
	
	# Stats'ları güncelle
	update_stats_display(tab_container)

func update_stats_display(_tab_container: TabContainer = null) -> void:
	if not stats_container or not Global.player:
		return
	
	# Mevcut label'ları temizle
	for child in stats_container.get_children():
		child.queue_free()
	
	# Player stats'ları göster
	var player = Global.player
	if player and player.primary_stats:
		var stats = player.primary_stats
		var stats_list: Array[Dictionary] = []
		
		# Player level (eğer varsa)
		if "level" in player:
			stats_list.append({
				"text": "Mevcut Seviye: %d" % player.level,
				"value": float(player.level)
			})
		
		# Max HP - Her zaman göster
		stats_list.append({
			"text": "Maks. Sağlık: %d" % int(stats.max_hp),
			"value": stats.max_hp
		})
		
		# HP Regeneration - Her zaman göster
		var regen_per_sec = stats.get_hp_regeneration_per_second()
		stats_list.append({
			"text": "Sağlık Yenileme: %.2f" % regen_per_sec,
			"value": stats.hp_regeneration
		})
		
		# Life Steal - Her zaman göster
		stats_list.append({
			"text": "%% Can Çalma: %.1f" % stats.life_steal,
			"value": stats.life_steal
		})
		
		# Damage - Her zaman göster
		stats_list.append({
			"text": "%% Hasar: %.1f" % stats.damage,
			"value": stats.damage
		})
		
		# Melee/Ranged/Elemental Damage - Her zaman göster
		stats_list.append({
			"text": "Yakın Saldırı Hasarı: %.1f" % stats.melee_damage,
			"value": stats.melee_damage
		})
		stats_list.append({
			"text": "Menzilli Saldırı Hasarı: %.1f" % stats.ranged_damage,
			"value": stats.ranged_damage
		})
		stats_list.append({
			"text": "Element Hasarı: %.1f" % stats.elemental_damage,
			"value": stats.elemental_damage
		})
		
		# Attack Speed - Her zaman göster
		stats_list.append({
			"text": "%% Saldırı Hızı: %.1f" % stats.attack_speed,
			"value": stats.attack_speed
		})
		
		# Crit Chance - Her zaman göster
		stats_list.append({
			"text": "%% Kritik Hasar Olasılığı: %.1f" % stats.crit_chance,
			"value": stats.crit_chance
		})
		
		# Engineering - Her zaman göster
		stats_list.append({
			"text": "Mühendislik: %.1f" % stats.engineering,
			"value": stats.engineering
		})
		
		# Range - Her zaman göster
		stats_list.append({
			"text": "Menzil: %.1f" % stats.weapon_range,
			"value": stats.weapon_range
		})
		
		# Armor - Her zaman göster
		stats_list.append({
			"text": "Zırh: %.1f" % stats.armor,
			"value": stats.armor
		})
		
		# Dodge - Her zaman göster
		stats_list.append({
			"text": "%% Kaçınma: %.1f" % stats.dodge,
			"value": stats.dodge
		})
		
		# Speed - Her zaman göster
		stats_list.append({
			"text": "%% Hız: %.1f" % stats.speed,
			"value": stats.speed
		})
		
		# Luck - Her zaman göster
		stats_list.append({
			"text": "Şans: %.1f" % stats.luck,
			"value": stats.luck
		})
		
		# Harvesting - Her zaman göster
		stats_list.append({
			"text": "Toplama: %.1f" % stats.harvesting,
			"value": stats.harvesting
		})
		
		# Label'ları ekle
		for stat in stats_list:
			var label = Label.new()
			label.text = stat["text"]
			
			# Renk ayarla
			var color = Color.WHITE
			if stat.has("color"):
				color = stat["color"]
			elif stat.has("value"):
				var value = stat["value"]
				if value > 0:
					color = Color(0.5, 1.0, 0.5) # Yeşil
				elif value < 0:
					color = Color(1.0, 0.5, 0.5) # Kırmızı
			
			label.modulate = color
			
			# Font uygula
			if has_node("/root/FontManager"):
				var font_mgr = get_node("/root/FontManager")
				if font_mgr.text_font:
					label.add_theme_font_override("font", font_mgr.text_font)
			
			stats_container.add_child(label)
