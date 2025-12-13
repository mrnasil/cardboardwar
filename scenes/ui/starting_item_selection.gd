extends Control
class_name StartingItemSelection

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var item_container: VBoxContainer = $VBoxContainer/ItemContainer
@onready var continue_button: Button = $VBoxContainer/ContinueButton

signal item_selected(item_data)
signal continue_pressed

var available_items: Array = []
var item_buttons: Array[Button] = []
var selected_item = null
var selected_button_index: int = 0
var is_on_continue_button: bool = false
var last_input_time: float = 0.0
var input_delay: float = 0.2

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.disabled = true
	continue_button.focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	# İlk eşya seçeneklerini göster
	_show_starting_items()
	
	# Font'ları uygula
	call_deferred("_apply_fonts")

func _apply_fonts() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)
		
		# Item butonlarına da font uygula
		for button in item_buttons:
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

func _show_starting_items() -> void:
	# Örnek eşya listesi - gerçek eşyalar oyuna göre ayarlanabilir
	var items = [
		{"name": "Küçük Karton", "type": "cardboard", "value": 5},
		{"name": "Orta Karton", "type": "cardboard", "value": 10},
		{"name": "Büyük Karton", "type": "cardboard", "value": 15},
		{"name": "Hız Artışı", "type": "speed", "value": 50},
		{"name": "Can Artışı", "type": "health", "value": 10}
	]
	
	show_items(items)

func show_items(items: Array) -> void:
	available_items = items
	selected_item = null
	continue_button.disabled = true
	selected_button_index = 0
	is_on_continue_button = false
	item_buttons.clear()
	
	# Mevcut item butonlarını temizle
	for child in item_container.get_children():
		child.queue_free()
	
	# Item butonlarını oluştur
	for item in items:
		var button = Button.new()
		button.text = item.name if item.has("name") else "Item"
		button.custom_minimum_size = Vector2(300, 50)
		button.pressed.connect(_on_item_selected.bind(item, button))
		button.focus_mode = Control.FOCUS_ALL
		item_container.add_child(button)
		item_buttons.append(button)
		
		# Font'u uygula
		call_deferred("_apply_font_to_button", button)
	
	# Focus bağlantılarını ayarla
	_setup_focus_connections()
	
	# İlk butonu vurgula
	if item_buttons.size() > 0:
		_update_button_highlight()
		await get_tree().process_frame
		item_buttons[0].grab_focus()
	
	# Ekranı göster
	visible = true

func _setup_focus_connections() -> void:
	# Item butonları arası gezinme
	for i in range(item_buttons.size()):
		var button = item_buttons[i]
		if i > 0:
			button.focus_neighbor_top = item_buttons[i - 1].get_path()
		if i < item_buttons.size() - 1:
			button.focus_neighbor_bottom = item_buttons[i + 1].get_path()
		else:
			# Son buton continue butonuna bağlanır
			button.focus_neighbor_bottom = continue_button.get_path()
			continue_button.focus_neighbor_top = button.get_path()

func _process(delta: float) -> void:
	if not visible:
		return
	
	last_input_time += delta
	_handle_gamepad_input()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Gamepad A/X butonu veya klavye Enter/Space
	var is_accept = false
	
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed and joy_event.button_index == 0:  # A/X button
			is_accept = true
	elif event.is_action_pressed("ui_accept"):
		is_accept = true
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
			is_accept = true
	
	if is_accept:
		if is_on_continue_button and not continue_button.disabled:
			_on_continue_pressed()
		elif not is_on_continue_button and selected_button_index < item_buttons.size():
			var button = item_buttons[selected_button_index]
			var item = available_items[selected_button_index]
			_on_item_selected(item, button)
		get_viewport().set_input_as_handled()
		return
	
	# Y tuşu basılı tutulduğunda devam et
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.button_index == 3 and joy_event.pressed:  # Y/Triangle
			if not continue_button.disabled:
				_on_continue_pressed()
			get_viewport().set_input_as_handled()
			return
	
	# D-Pad veya analog stick ile navigasyon
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed:
			if joy_event.button_index == 11:  # D-Pad Up
				_move_selection_up()
				get_viewport().set_input_as_handled()
			elif joy_event.button_index == 12:  # D-Pad Down
				_move_selection_down()
				get_viewport().set_input_as_handled()
	elif event is InputEventJoypadMotion:
		var joy_event = event as InputEventJoypadMotion
		if joy_event.axis == 1:
			if joy_event.axis_value < -0.5 and last_input_time >= input_delay:
				_move_selection_up()
				last_input_time = 0.0
				get_viewport().set_input_as_handled()
			elif joy_event.axis_value > 0.5 and last_input_time >= input_delay:
				_move_selection_down()
				last_input_time = 0.0
				get_viewport().set_input_as_handled()
	
	# Klavye ile navigasyon
	if event.is_action_pressed("ui_up"):
		_move_selection_up()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_move_selection_down()
		get_viewport().set_input_as_handled()

func _handle_gamepad_input() -> void:
	# Y tuşu basılı tutulduğunda devam et
	if Input.is_joy_button_pressed(0, 3):
		if not continue_button.disabled:
			_on_continue_pressed()
		return

func _move_selection_up() -> void:
	if is_on_continue_button:
		is_on_continue_button = false
		selected_button_index = item_buttons.size() - 1
	else:
		selected_button_index = max(0, selected_button_index - 1)
	_update_button_highlight()

func _move_selection_down() -> void:
	if selected_button_index >= item_buttons.size() - 1:
		is_on_continue_button = true
	else:
		selected_button_index = min(item_buttons.size() - 1, selected_button_index + 1)
	_update_button_highlight()

func _on_item_selected(item_data, button: Button) -> void:
	selected_item = item_data
	
	# Seçili butonun index'ini bul
	for i in range(item_buttons.size()):
		if item_buttons[i] == button:
			selected_button_index = i
			break
	
	is_on_continue_button = false
	
	# Tüm butonları sıfırla
	for child in item_container.get_children():
		if child is Button:
			child.modulate = Color.WHITE
	
	# Seçili butonu vurgula
	button.modulate = Color(0.5, 1.0, 0.5)
	continue_button.disabled = false
	continue_button.modulate = Color.WHITE
	
	item_selected.emit(item_data)
	print("İlk eşya seçildi: ", item_data)

func _update_button_highlight() -> void:
	# Tüm item butonlarını sıfırla
	for i in range(item_buttons.size()):
		var button = item_buttons[i]
		if i == selected_button_index and not is_on_continue_button:
			button.modulate = Color(0.7, 1.0, 0.7)
		else:
			button.modulate = Color.WHITE
	
	# Continue butonunu vurgula
	if is_on_continue_button:
		continue_button.modulate = Color(0.7, 1.0, 0.7)
	else:
		continue_button.modulate = Color.WHITE

func _on_continue_pressed() -> void:
	# Seçilen eşyayı Global'a kaydet
	if selected_item:
		Global.selected_starting_item = selected_item
		print("İlk eşya kaydedildi: ", selected_item)
	
	# Arena'ya geç
	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")

