extends CanvasLayer

var continue_button: Button
var main_menu_button: Button
var control: Control

func _ready() -> void:
	# Node'ları manuel olarak bul - await ile bir frame bekle
	await get_tree().process_frame
	
	control = get_node_or_null("Control")
	if not control:
		push_error("PauseMenu: Control node'u bulunamadı!")
		return
	
	var vbox = control.get_node_or_null("VBoxContainer")
	if not vbox:
		push_error("PauseMenu: VBoxContainer bulunamadı!")
		return
	
	continue_button = vbox.get_node_or_null("ContinueButton")
	main_menu_button = vbox.get_node_or_null("MainMenuButton")
	
	# Butonların null olup olmadığını kontrol et
	if not continue_button or not main_menu_button:
		push_error("PauseMenu: Butonlar bulunamadı! ContinueButton: %s, MainMenuButton: %s" % [continue_button, main_menu_button])
		return
	
	# Butonları sinyallere bağla
	continue_button.pressed.connect(_on_continue_button_pressed)
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	
	# Butonların focus modunu ayarla (gamepad için)
	continue_button.focus_mode = Control.FOCUS_ALL
	main_menu_button.focus_mode = Control.FOCUS_ALL
	
	# İlk butona focus ver (gamepad için)
	continue_button.grab_focus()
	
	# Butonlar arası gezinme için bağlantıları ayarla
	continue_button.focus_neighbor_bottom = main_menu_button.get_path()
	main_menu_button.focus_neighbor_top = continue_button.get_path()
	
	# Pause menüsü pause sırasında da çalışmalı
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	# Ekranın tamamını kapsaması için
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	# PRESET_FULL_RECT kullanıldığında size ve position otomatik ayarlanır
	
	# Font'ları uygula
	call_deferred("_apply_fonts")

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
		if joy_event.pressed and joy_event.button_index == 0:  # A/X butonu
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
