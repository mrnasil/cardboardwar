extends CanvasLayer
class_name UpgradeScreen

@onready var upgrade_container: VBoxContainer = $VBoxContainer/UpgradeContainer
@onready var continue_button: Button = $VBoxContainer/ContinueButton

signal upgrade_selected(upgrade_data)
signal screen_closed

var available_upgrades: Array = []
var upgrade_buttons: Array[Button] = []
var selected_upgrade = null
var is_waiting_for_selection: bool = false
var selected_button_index: int = 0
var is_on_continue_button: bool = false
var last_input_time: float = 0.0
var input_delay: float = 0.2  # Gamepad input delay

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = true
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)  # _input() fonksiyonunu aktif et
	
	# Font'ları uygula
	call_deferred("_apply_fonts")

func _apply_fonts() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)
		
		# Upgrade butonlarına da font uygula
		for button in upgrade_buttons:
			if is_instance_valid(button):
				_apply_font_to_button(button)

func _apply_font_to_button(button: Button) -> void:
	if not button or not has_node("/root/FontManager"):
		return
	
	var font_mgr = get_node("/root/FontManager")
	# Button'ın text'ine göre font uygula
	var text = button.text
	if font_mgr.is_number_only(text):
		if font_mgr.number_font:
			button.add_theme_font_override("font", font_mgr.number_font)
	else:
		if font_mgr.text_font:
			button.add_theme_font_override("font", font_mgr.text_font)

func show_upgrades(upgrades: Array) -> void:
	available_upgrades = upgrades
	selected_upgrade = null
	continue_button.disabled = true
	is_waiting_for_selection = true
	selected_button_index = 0
	is_on_continue_button = false
	upgrade_buttons.clear()
	
	# Mevcut upgrade butonlarını temizle
	for child in upgrade_container.get_children():
		child.queue_free()
	
	# Upgrade butonlarını oluştur
	for upgrade in upgrades:
		var button = Button.new()
		button.text = upgrade.name if upgrade.has("name") else "Upgrade"
		button.custom_minimum_size = Vector2(300, 50)
		button.pressed.connect(_on_upgrade_selected.bind(upgrade, button))
		upgrade_container.add_child(button)
		upgrade_buttons.append(button)
		
		# Font'u uygula (buton içindeki text için)
		if has_node("/root/FontManager"):
			var font_mgr = get_node("/root/FontManager")
			# Button içindeki text için Label bul ve font uygula
			call_deferred("_apply_font_to_button", button)
	
	# İlk butonu vurgula
	if upgrade_buttons.size() > 0:
		_update_button_highlight()
	
	# Ekranı göster ve oyunu durdur
	visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS  # Upgrade ekranı pause'da da çalışsın
	get_tree().paused = true
	
	# Player'ın hareket etmesini engelle
	if is_instance_valid(Global.player):
		Global.player.process_mode = Node.PROCESS_MODE_DISABLED

func _on_upgrade_selected(upgrade_data, button: Button) -> void:
	selected_upgrade = upgrade_data
	
	# Seçili butonun index'ini bul
	for i in range(upgrade_buttons.size()):
		if upgrade_buttons[i] == button:
			selected_button_index = i
			break
	
	is_on_continue_button = false
	
	# Tüm butonları sıfırla
	for child in upgrade_container.get_children():
		if child is Button:
			child.modulate = Color.WHITE
	
	# Seçili butonu vurgula
	button.modulate = Color(0.5, 1.0, 0.5)
	continue_button.disabled = false
	continue_button.modulate = Color.WHITE

func _process(delta: float) -> void:
	if not visible or not is_waiting_for_selection:
		return
	
	last_input_time += delta
	
	# Gamepad input kontrolü (analog stick ve Y tuşu)
	_handle_gamepad_input()

func _input(event: InputEvent) -> void:
	if not visible or not is_waiting_for_selection:
		return
	
	# Gamepad A/X butonu veya klavye Enter/Space
	# Hem action hem de direkt buton kontrolü yapıyoruz
	var is_accept = false
	
	# Direkt gamepad butonu kontrolü (A/X = button 0) - önce kontrol et
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed and joy_event.button_index == 0:  # A/X button
			is_accept = true
	# Action kontrolü
	elif event.is_action_pressed("ui_accept"):
		is_accept = true
	# Klavye Enter/Space
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
			is_accept = true
	
	if is_accept:
		print("Upgrade Screen: Accept pressed, is_on_continue: ", is_on_continue_button, " selected_index: ", selected_button_index, " buttons: ", upgrade_buttons.size())
		if is_on_continue_button and not continue_button.disabled:
			_on_continue_pressed()
		elif not is_on_continue_button and selected_button_index < upgrade_buttons.size():
			var button = upgrade_buttons[selected_button_index]
			var upgrade = available_upgrades[selected_button_index]
			print("Upgrade Screen: Selecting upgrade: ", upgrade)
			_on_upgrade_selected(upgrade, button)
		else:
			print("Upgrade Screen: Accept pressed but conditions not met")
		get_viewport().set_input_as_handled()
		return
	
	# Gamepad Y tuşu (Triangle/Y) basılı tutma
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.button_index == 3 and joy_event.pressed:  # Y/Triangle
			if not continue_button.disabled:
				_on_continue_pressed()
			get_viewport().set_input_as_handled()
			return
	
	# Gamepad D-Pad veya analog stick ile navigasyon
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed:
			# D-Pad Up = 11, D-Pad Down = 12 (Godot 4)
			if joy_event.button_index == 11:  # D-Pad Up
				_move_selection_up()
				get_viewport().set_input_as_handled()
			elif joy_event.button_index == 12:  # D-Pad Down
				_move_selection_down()
				get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var joy_event = event as InputEventJoypadMotion
		# Analog stick kontrolü (axis 1 = vertical)
		if joy_event.axis == 1:
			if joy_event.axis_value < -0.5 and last_input_time >= input_delay:  # Yukarı
				_move_selection_up()
				last_input_time = 0.0
				get_viewport().set_input_as_handled()
			elif joy_event.axis_value > 0.5 and last_input_time >= input_delay:  # Aşağı
				_move_selection_down()
				last_input_time = 0.0
				get_viewport().set_input_as_handled()
	
	# Klavye ile de navigasyon (fallback)
	if event.is_action_pressed("ui_up"):
		_move_selection_up()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection_down()
		get_viewport().set_input_as_handled()

func _move_selection_up() -> void:
	if is_on_continue_button:
		is_on_continue_button = false
		selected_button_index = upgrade_buttons.size() - 1
	else:
		selected_button_index = max(0, selected_button_index - 1)
	_update_button_highlight()

func _move_selection_down() -> void:
	if selected_button_index >= upgrade_buttons.size() - 1:
		is_on_continue_button = true
	else:
		selected_button_index = min(upgrade_buttons.size() - 1, selected_button_index + 1)
	_update_button_highlight()

func _handle_gamepad_input() -> void:
	# Y tuşu (Triangle/Gamepad button 3) basılı tutulduğunda devam et
	# Not: Bu _process'te çalışır çünkü basılı tutma durumunu kontrol ediyoruz
	if Input.is_joy_button_pressed(0, 3):  # JOY_BUTTON_Y = 3 (Triangle on PlayStation, Y on Xbox)
		if not continue_button.disabled:
			_on_continue_pressed()
		return

func _handle_continue_input() -> void:
	# Continue butonuna odaklan
	if Input.is_action_just_pressed("ui_accept"):
		_on_continue_pressed()

func _update_button_highlight() -> void:
	# Tüm upgrade butonlarını sıfırla
	for i in range(upgrade_buttons.size()):
		var button = upgrade_buttons[i]
		if i == selected_button_index and not is_on_continue_button:
			button.modulate = Color(0.7, 1.0, 0.7)  # Hafif vurgu
		else:
			button.modulate = Color.WHITE
	
	# Continue butonunu vurgula
	if is_on_continue_button:
		continue_button.modulate = Color(0.7, 1.0, 0.7)
	else:
		continue_button.modulate = Color.WHITE

func _on_continue_pressed() -> void:
	if selected_upgrade:
		upgrade_selected.emit(selected_upgrade)
	
	# Ekranı kapat ve oyunu devam ettir
	is_waiting_for_selection = false
	visible = false
	get_tree().paused = false
	
	# Player'ın process_mode'unu geri yükle
	if is_instance_valid(Global.player):
		Global.player.process_mode = Node.PROCESS_MODE_INHERIT
	
	screen_closed.emit()

