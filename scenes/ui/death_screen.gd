extends CanvasLayer
class_name DeathScreen

@onready var death_label: Label = $VBoxContainer/DeathLabel
@onready var wave_label: Label = $VBoxContainer/WaveLabel
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var restart_button: Button = $VBoxContainer/ButtonContainer/RestartButton
@onready var main_menu_button: Button = $VBoxContainer/ButtonContainer/MainMenuButton

var final_wave: int = 0
var final_level: int = 0
var final_cardboard: int = 0

func _ready() -> void:
	# Buton sinyallerine bağlan
	restart_button.pressed.connect(_on_restart_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	
	# Butonların focus modunu ayarla
	restart_button.focus_mode = Control.FOCUS_ALL
	main_menu_button.focus_mode = Control.FOCUS_ALL
	
	# Butonların mouse filter'ını ayarla (pause'da da çalışsın)
	restart_button.mouse_filter = Control.MOUSE_FILTER_STOP
	main_menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Pause durumunda da çalışabilmesi için
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	set_process_unhandled_input(true)
	
	# Oyunu durdur
	get_tree().paused = true
	
	# İstatistikleri göster
	update_stats()
	
	# Focus bağlantılarını ayarla
	restart_button.focus_neighbor_right = main_menu_button.get_path()
	main_menu_button.focus_neighbor_left = restart_button.get_path()
	
	# İlk butona focus ver
	await get_tree().process_frame
	restart_button.grab_focus()
	
	# Font'ları uygula
	call_deferred("_apply_fonts")

func _apply_fonts() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)

func setup(wave: int, level: int, cardboard: int) -> void:
	final_wave = wave
	final_level = level
	final_cardboard = cardboard
	update_stats()

func update_stats() -> void:
	death_label.text = "ÖLDÜN!"
	wave_label.text = "Wave: %d" % final_wave
	stats_label.text = "Level: %d\nKarton: %d" % [final_level, final_cardboard]

func _unhandled_input(event: InputEvent) -> void:
	# Pause durumunda _input çalışmayabilir, _unhandled_input kullan
	_input(event)

func _input(event: InputEvent) -> void:
	# Mouse tıklaması kontrolü (pause'da da çalışmalı)
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			# Tıklanan butonu bul
			var clicked_button = _get_button_at_position(mouse_event.global_position)
			if clicked_button:
				clicked_button.pressed.emit()
				get_viewport().set_input_as_handled()
				return
	
	# Gamepad A/X butonu ile seçim
	var is_accept = false
	
	# Direkt gamepad butonu kontrolü (A/X = button 0) - önce kontrol et
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed:
			if joy_event.button_index == 0:  # A/X butonu
				is_accept = true
			elif joy_event.button_index == 1:  # B butonu
				_on_main_menu_pressed()
				get_viewport().set_input_as_handled()
				return
	
	# Action kontrolü
	if not is_accept and event.is_action_pressed("ui_accept"):
		is_accept = true
	
	# Klavye Enter/Space
	if not is_accept and event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
			is_accept = true
	
	if is_accept:
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.pressed.emit()
		else:
			# Focus yoksa ilk butona bas
			restart_button.pressed.emit()
		get_viewport().set_input_as_handled()
		return
	
	# D-Pad veya analog stick ile navigasyon
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed:
			if joy_event.button_index == 11:  # D-Pad Up (zaten yukarıda)
				pass
			elif joy_event.button_index == 12:  # D-Pad Down (zaten aşağıda)
				pass
			elif joy_event.button_index == 13:  # D-Pad Left
				restart_button.grab_focus()
				get_viewport().set_input_as_handled()
			elif joy_event.button_index == 14:  # D-Pad Right
				main_menu_button.grab_focus()
				get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var joy_event = event as InputEventJoypadMotion
		if joy_event.axis == 0:  # Horizontal axis
			if joy_event.axis_value < -0.5:  # Sol
				restart_button.grab_focus()
				get_viewport().set_input_as_handled()
			elif joy_event.axis_value > 0.5:  # Sağ
				main_menu_button.grab_focus()
				get_viewport().set_input_as_handled()
	
	# Klavye ile navigasyon
	if event.is_action_pressed("ui_left"):
		restart_button.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		main_menu_button.grab_focus()
		get_viewport().set_input_as_handled()

func _get_button_at_position(pos: Vector2) -> Button:
	# Verilen pozisyondaki butonu bul
	# Pause durumunda mouse pozisyonu doğru çalışmayabilir
	# Bunun yerine direkt buton kontrolü yap
	var viewport = get_viewport()
	if not viewport:
		return null
	
	# Mouse pozisyonunu al
	var mouse_pos = viewport.get_mouse_position()
	
	# Butonları kontrol et (global_position yerine screen_position kullan)
	if restart_button and restart_button.visible:
		var button_rect = Rect2(restart_button.global_position, restart_button.size)
		# CanvasLayer kullanıldığı için global_position doğru olmalı
		if button_rect.has_point(mouse_pos):
			return restart_button
	
	if main_menu_button and main_menu_button.visible:
		var button_rect = Rect2(main_menu_button.global_position, main_menu_button.size)
		if button_rect.has_point(mouse_pos):
			return main_menu_button
	
	return null

func _on_restart_pressed() -> void:
	print("Death Screen: Restart button pressed")
	# Oyunu yeniden başlat
	get_tree().paused = false
	Global.has_active_game = false
	Global.selected_character = ""
	Global.selected_difficulty = 0
	Global.selected_starting_item = {}
	# Scene değişikliği için call_deferred kullan
	call_deferred("_reload_scene")

func _reload_scene() -> void:
	print("Death Screen: Reloading scene")
	if get_tree():
		# Death screen'i kaldır (scene değişikliğinden önce)
		if is_instance_valid(self):
			queue_free()
		get_tree().reload_current_scene()

func _on_main_menu_pressed() -> void:
	print("Death Screen: Main menu button pressed")
	# Ana menüye dön
	get_tree().paused = false
	Global.has_active_game = false
	Global.selected_character = ""
	Global.selected_difficulty = 0
	Global.selected_starting_item = {}
	
	# Scene değişikliği için call_deferred kullan (queue_free'den önce)
	call_deferred("_change_to_main_menu")

func _change_to_main_menu() -> void:
	print("Death Screen: Changing to main menu")
	if get_tree():
		# Death screen'i kaldır (scene değişikliğinden sonra)
		if is_instance_valid(self):
			queue_free()
		get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

