extends Control
class_name DifficultySelection

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var difficulty_container: HBoxContainer = $VBoxContainer/DifficultyContainer
@onready var back_button: Button = $VBoxContainer/BackButton

signal difficulty_selected(difficulty: int)


var difficulty_buttons: Array[Button] = []
var selected_difficulty: int = 0

func _ready() -> void:
	# title_label.text is set in scene with translation key
	back_button.pressed.connect(_on_back_pressed)
	back_button.focus_mode = Control.FOCUS_ALL
	
	# Zorluk butonlarını oluştur (0-5)
	for i in range(6):
		var button = Button.new()
		button.text = str(i)
		button.custom_minimum_size = Vector2(80, 60)
		button.pressed.connect(_on_difficulty_selected.bind(i, button))
		button.focus_mode = Control.FOCUS_ALL
		difficulty_container.add_child(button)
		difficulty_buttons.append(button)
	
	# Focus bağlantılarını ayarla
	_setup_focus_connections()
	
	# İlk butona focus ver
	if difficulty_buttons.size() > 0:
		await get_tree().process_frame
		difficulty_buttons[0].grab_focus()
	
	# Font'ları uygula
	call_deferred("_apply_fonts")

func _apply_fonts() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)
		
		# Zorluk butonlarına da font uygula (sayılar için)
		for button in difficulty_buttons:
			if is_instance_valid(button) and font_mgr.number_font:
				button.add_theme_font_override("font", font_mgr.number_font)

func _setup_focus_connections() -> void:
	# Butonlar arası gezinme
	for i in range(difficulty_buttons.size()):
		var button = difficulty_buttons[i]
		if i > 0:
			button.focus_neighbor_left = difficulty_buttons[i - 1].get_path()
		if i < difficulty_buttons.size() - 1:
			button.focus_neighbor_right = difficulty_buttons[i + 1].get_path()
		
		# İlk buton sol tarafta back button'a bağlanır
		if i == 0:
			back_button.focus_neighbor_right = button.get_path()
			button.focus_neighbor_left = back_button.get_path()
	
	# Back button'dan ilk butona
	if difficulty_buttons.size() > 0:
		back_button.focus_neighbor_bottom = difficulty_buttons[0].get_path()

func _on_difficulty_selected(difficulty: int, _button: Button) -> void:
	selected_difficulty = difficulty
	Global.selected_difficulty = difficulty
	difficulty_selected.emit(difficulty)
	print("Zorluk seçildi: ", difficulty)
	
	# İlk eşya seçim ekranına geç
	get_tree().change_scene_to_file("res://scenes/ui/StartingSelection.tscn")

func _on_back_pressed() -> void:
	# Karakter seçim ekranına geri dön
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelection.tscn")

func _input(event: InputEvent) -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	
	# Gamepad A/X butonu ile seçim
	if event.is_action_pressed("ui_accept"):
		var focused = viewport.gui_get_focus_owner()
		if focused is Button:
			focused.pressed.emit()
			viewport.set_input_as_handled()
		return
	
	# Direkt gamepad butonu kontrolü (A/X = button 0)
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed and joy_event.button_index == 0: # A/X butonu
			var focused = viewport.gui_get_focus_owner()
			if focused is Button:
				focused.pressed.emit()
			viewport.set_input_as_handled()
			return
		
		# Gamepad B butonu ile geri dön
		if joy_event.pressed and joy_event.button_index == 1: # B butonu
			_on_back_pressed()
			viewport.set_input_as_handled()
			return
	
	# ESC tuşu ile geri dön
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		viewport.set_input_as_handled()
