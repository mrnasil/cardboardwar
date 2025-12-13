extends Control

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var start_button: Button = $VBoxContainer/StartButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var exit_button: Button = $VBoxContainer/ExitButton

func _ready() -> void:
	# Devam Et butonunu kontrol et ve göster/gizle
	if Global.has_active_game:
		continue_button.visible = true
		continue_button.pressed.connect(_on_continue_button_pressed)
		continue_button.focus_mode = Control.FOCUS_ALL
	else:
		continue_button.visible = false
	
	# Butonları sinyallere bağla
	start_button.pressed.connect(_on_start_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)
	
	# Butonların focus modunu ayarla (gamepad için)
	start_button.focus_mode = Control.FOCUS_ALL
	settings_button.focus_mode = Control.FOCUS_ALL
	exit_button.focus_mode = Control.FOCUS_ALL
	
	# İlk butona focus ver (gamepad için) - Devam Et varsa ona, yoksa Başlat'a
	if continue_button.visible:
		continue_button.grab_focus()
		# Butonlar arası gezinme için bağlantıları ayarla
		continue_button.focus_neighbor_bottom = start_button.get_path()
		start_button.focus_neighbor_top = continue_button.get_path()
		start_button.focus_neighbor_bottom = settings_button.get_path()
		settings_button.focus_neighbor_top = start_button.get_path()
	else:
		start_button.grab_focus()
		# Butonlar arası gezinme için bağlantıları ayarla
		start_button.focus_neighbor_bottom = settings_button.get_path()
		settings_button.focus_neighbor_top = start_button.get_path()
	
	settings_button.focus_neighbor_bottom = exit_button.get_path()
	exit_button.focus_neighbor_top = settings_button.get_path()
	
	# Font'ları uygula
	call_deferred("_apply_fonts")

func _apply_fonts() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)

func _input(event: InputEvent) -> void:
	# Gamepad desteği
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("dash"):
		# Seçili butona bas
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.pressed.emit()
	
	# ESC tuşu ile çıkış
	if event.is_action_pressed("ui_cancel"):
		_on_exit_button_pressed()

func _on_continue_button_pressed() -> void:
	# Yarıda kalmış oyunu devam ettir
	get_tree().change_scene_to_file("res://scenes/arena/arena.tscn")

func _on_start_button_pressed() -> void:
	# Yeni oyun başlat - oyun durumunu sıfırla
	Global.has_active_game = false
	# Karakter seçim ekranına geçiş yap
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelection.tscn")

func _on_settings_button_pressed() -> void:
	# Ayarlar menüsüne geçiş yap
	get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn")

func _on_exit_button_pressed() -> void:
	# Oyunu kapat
	get_tree().quit()

