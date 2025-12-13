extends Control

const SETTINGS_FILE_PATH = "user://settings.cfg"

@onready var back_button: Button = $VBoxContainer/BackButton
@onready var music_slider: HSlider = $VBoxContainer/MusicContainer/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXContainer/SFXSlider
@onready var fullscreen_checkbox: CheckBox = $VBoxContainer/FullscreenContainer/FullscreenCheckbox

func _ready() -> void:
	# Geri butonunu sinyale bağla
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Slider'ları sinyallere bağla
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	
	# Checkbox'ı sinyale bağla
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	
	# Slider'ları ve checkbox'ı focus alabilir yap (gamepad için)
	music_slider.focus_mode = Control.FOCUS_ALL
	sfx_slider.focus_mode = Control.FOCUS_ALL
	fullscreen_checkbox.focus_mode = Control.FOCUS_ALL
	
	# Focus bağlantılarını ayarla (gamepad navigasyonu için)
	music_slider.focus_neighbor_bottom = sfx_slider.get_path()
	sfx_slider.focus_neighbor_top = music_slider.get_path()
	sfx_slider.focus_neighbor_bottom = fullscreen_checkbox.get_path()
	fullscreen_checkbox.focus_neighbor_top = sfx_slider.get_path()
	fullscreen_checkbox.focus_neighbor_bottom = back_button.get_path()
	back_button.focus_neighbor_top = fullscreen_checkbox.get_path()
	
	# İlk kontrol elemanına focus ver (gamepad için)
	music_slider.grab_focus()
	
	# Ayarları yükle
	_load_settings()
	
	# Font'ları uygula
	call_deferred("_apply_fonts")

func _apply_fonts() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)

func _input(event: InputEvent) -> void:
	var focused = get_viewport().gui_get_focus_owner()
	
	# Gamepad desteği
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("dash"):
		# Seçili kontrol elemanına bas
		if focused is Button:
			focused.pressed.emit()
		elif focused is CheckBox:
			var checkbox: CheckBox = focused
			checkbox.button_pressed = not checkbox.button_pressed
			# Toggled sinyalini manuel olarak emit et (gamepad için gerekli)
			checkbox.toggled.emit(checkbox.button_pressed)
	
	# ESC tuşu ile geri dön
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
	
	# Gamepad ile slider kontrolü (sol/sağ ok tuşları)
	if focused is HSlider:
		if event.is_action_pressed("move_left"):
			focused.value = max(focused.min_value, focused.value - focused.step)
		elif event.is_action_pressed("move_right"):
			focused.value = min(focused.max_value, focused.value + focused.step)

func _load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE_PATH)
	
	# Ayarları yükle (varsayılan değerler veya kaydedilmiş değerler)
	if err == OK:
		music_slider.value = config.get_value("audio", "music_volume", 80.0)
		sfx_slider.value = config.get_value("audio", "sfx_volume", 80.0)
		var fullscreen = config.get_value("video", "fullscreen", false)
		fullscreen_checkbox.button_pressed = fullscreen
		# Kaydedilmiş tam ekran ayarını uygula
		_apply_fullscreen(fullscreen)
	else:
		# Varsayılan değerler
		music_slider.value = 80.0
		sfx_slider.value = 80.0
		var current_mode = DisplayServer.window_get_mode()
		var is_fullscreen = current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		fullscreen_checkbox.button_pressed = is_fullscreen

func _on_music_slider_changed(value: float) -> void:
	# Müzik ses seviyesini ayarla
	# TODO: AudioServer veya müzik player'a bağlanacak
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value / 100.0))
	_save_settings()

func _on_sfx_slider_changed(_value: float) -> void:
	# Efekt ses seviyesini ayarla
	# TODO: SFX bus'a bağlanacak
	_save_settings()

func _on_fullscreen_toggled(button_pressed: bool) -> void:
	# Tam ekran modunu ayarla
	_apply_fullscreen(button_pressed)
	_save_settings()

func _apply_fullscreen(enabled: bool) -> void:
	if enabled:
		# Tam ekran modunu ayarla
		# Önce borderless fullscreen'i dene (daha uyumlu)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	config.set_value("video", "fullscreen", fullscreen_checkbox.button_pressed)
	config.save(SETTINGS_FILE_PATH)

func _on_back_button_pressed() -> void:
	# Ana menüye geri dön
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
