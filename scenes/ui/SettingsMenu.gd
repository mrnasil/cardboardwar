extends Control

const SETTINGS_FILE_PATH = "user://settings.cfg"
const UIThemeManager = preload("res://autoloads/ui_themes.gd")

@onready var back_button: Button = $VBoxContainer/BackButton
@onready var music_slider: HSlider = $VBoxContainer/MusicContainer/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SFXContainer/SFXSlider
@onready var fullscreen_checkbox: CheckBox = $VBoxContainer/FullscreenContainer/FullscreenCheckbox
@onready var language_option: OptionButton = $VBoxContainer/LanguageContainer/LanguageOption

const LANGUAGES = [
	{"code": "en", "name": "English"},
	{"code": "tr", "name": "Türkçe"}
]

var pause_menu_reference: CanvasLayer = null # Pause menüsü referansı (overlay modunda)

func _ready() -> void:
	# Pause durumunda da çalışabilmesi için
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	# Control node'unun mouse event'lerini alabilmesi için
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Geri butonunu sinyale bağla
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		# Geri butonunun focus modunu ayarla
		back_button.focus_mode = Control.FOCUS_ALL
		# Butonun tıklanabilir olduğundan emin ol
		back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		push_error("SettingsMenu: Geri butonu bulunamadı!")
	
	# Slider'ları sinyallere bağla
	music_slider.value_changed.connect(_on_music_slider_changed)
	sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	
	# Checkbox'ı sinyale bağla
	# Checkbox'ı sinyale bağla
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	
	# Dil seçimini sinyale bağla
	language_option.item_selected.connect(_on_language_selected)
	
	# Dilleri doldur
	language_option.clear()
	for i in range(LANGUAGES.size()):
		language_option.add_item(LANGUAGES[i].name)
		language_option.set_item_metadata(i, LANGUAGES[i].code)
	
	# Slider'ları ve checkbox'ı focus alabilir yap (gamepad için)
	music_slider.focus_mode = Control.FOCUS_ALL
	sfx_slider.focus_mode = Control.FOCUS_ALL
	fullscreen_checkbox.focus_mode = Control.FOCUS_ALL
	language_option.focus_mode = Control.FOCUS_ALL
	
	# Focus bağlantılarını ayarla (gamepad navigasyonu için)
	music_slider.focus_neighbor_bottom = sfx_slider.get_path()
	sfx_slider.focus_neighbor_top = music_slider.get_path()
	sfx_slider.focus_neighbor_bottom = fullscreen_checkbox.get_path()
	fullscreen_checkbox.focus_neighbor_top = sfx_slider.get_path()
	fullscreen_checkbox.focus_neighbor_bottom = language_option.get_path()
	
	language_option.focus_neighbor_top = fullscreen_checkbox.get_path()
	language_option.focus_neighbor_bottom = back_button.get_path()
	
	back_button.focus_neighbor_top = language_option.get_path()
	
	# İlk kontrol elemanına focus ver (gamepad için)
	music_slider.grab_focus()
	
	# Ses kanallarını oluştur
	_init_audio_buses()
	
	# Ayarları yükle
	_load_settings()
	
	# Font'ları uygula
	call_deferred("_apply_fonts")
	
	# Theme uygula
	_apply_theme()

func _init_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
		
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

func _apply_theme() -> void:
	if not UIThemeManager:
		return
		
	# Background rengi
	if has_node("Background"):
		var bg_node = get_node("Background")
		if bg_node is ColorRect:
			bg_node.color = UIThemeManager.COLOR_BACKGROUND_MAIN
			
	# Buton stilleri
	if back_button:
		UIThemeManager.apply_theme_to_button(back_button)

func _apply_fonts() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)

func _input(event: InputEvent) -> void:
	# Input event'lerini yakala (pause durumunda da çalışsın)
	if not visible:
		return
	
	var focused = get_viewport().gui_get_focus_owner()
	
	# Gamepad desteği
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("dash"):
		# Seçili kontrol elemanına bas
		if focused is Button:
			focused.pressed.emit()
			get_viewport().set_input_as_handled()
		elif focused is CheckBox:
			var checkbox: CheckBox = focused
			checkbox.button_pressed = not checkbox.button_pressed
			# Toggled sinyalini manuel olarak emit et (gamepad için gerekli)
			checkbox.toggled.emit(checkbox.button_pressed)
			get_viewport().set_input_as_handled()
	
	# ESC tuşu ile geri dön
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		var vp = get_viewport()
		if vp:
			vp.set_input_as_handled()
	
	# Gamepad ile slider kontrolü (sol/sağ ok tuşları)
	if focused is HSlider:
		if event.is_action_pressed("move_left"):
			focused.value = max(focused.min_value, focused.value - focused.step)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("move_right"):
			focused.value = min(focused.max_value, focused.value + focused.step)
			get_viewport().set_input_as_handled()

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
		
		# Dil ayarını yükle
		var lang_code = config.get_value("general", "language", "")
		if lang_code == "":
			# Ayar yoksa cihaz dilini kullan
			lang_code = OS.get_locale_language()
		
		# Desteklenen dillerden biri mi kontrol et, değilse İngilizce yap
		var found = false
		for lang in LANGUAGES:
			if lang.code == lang_code:
				found = true
				break
		if not found:
			lang_code = "en"
			
		_apply_language(lang_code)
	else:
		# Varsayılan değerler
		music_slider.value = 80.0
		sfx_slider.value = 80.0
		var current_mode = DisplayServer.window_get_mode()
		var is_fullscreen = current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		fullscreen_checkbox.button_pressed = is_fullscreen
		
		# Varsayılan dil (cihaz dili)
		var lang_code = OS.get_locale_language()
		var found = false
		for lang in LANGUAGES:
			if lang.code == lang_code:
				found = true
				break
		if not found:
			lang_code = "en"
		_apply_language(lang_code)

func _on_music_slider_changed(value: float) -> void:
	# Müzik ses seviyesini ayarla
	var index = AudioServer.get_bus_index("Music")
	if index != -1:
		AudioServer.set_bus_volume_db(index, linear_to_db(value / 100.0))
	_save_settings()

func _on_sfx_slider_changed(value: float) -> void:
	# Efekt ses seviyesini ayarla
	var index = AudioServer.get_bus_index("SFX")
	if index != -1:
		AudioServer.set_bus_volume_db(index, linear_to_db(value / 100.0))
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

func _on_language_selected(index: int) -> void:
	var code = language_option.get_item_metadata(index)
	_apply_language(code)
	_save_settings()

func _apply_language(code: String) -> void:
	TranslationServer.set_locale(code)
	# OptionButton seçimini güncelle
	for i in range(language_option.item_count):
		if language_option.get_item_metadata(i) == code:
			language_option.selected = i
			break

func _save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	config.set_value("video", "fullscreen", fullscreen_checkbox.button_pressed)
	
	# Seçili dili kaydet
	var selected_idx = language_option.selected
	if selected_idx >= 0:
		var lang_code = language_option.get_item_metadata(selected_idx)
		config.set_value("general", "language", lang_code)

	config.save(SETTINGS_FILE_PATH)

func set_pause_menu_reference(pause_menu: CanvasLayer) -> void:
	# Pause menüsü referansını kaydet (overlay modunda)
	pause_menu_reference = pause_menu

func _on_back_button_pressed() -> void:
	# Eğer pause menüsünden geldiysek (overlay modunda)
	if Global.from_pause_menu and pause_menu_reference:
		Global.from_pause_menu = false
		# Pause menüsünü tekrar göster
		if is_instance_valid(pause_menu_reference):
			pause_menu_reference.visible = true
		# SettingsMenu canvas layer'ını ve kendisini sil
		var parent = get_parent()
		if parent:
			# CanvasLayer'ı sil (içindeki SettingsMenu da silinir)
			parent.queue_free()
		else:
			queue_free()
	elif Global.from_pause_menu:
		# Eski yöntem (scene değişimi) - artık kullanılmıyor ama yedek olarak
		Global.from_pause_menu = false
		var tree = get_tree()
		if not tree:
			return
		# Oyunu pause'da tut
		tree.paused = true
		# Arena scene'ine geri dön
		tree.change_scene_to_file("res://scenes/arena/arena.tscn")
		# Scene değişimini bekle
		await tree.process_frame
		await tree.process_frame
		
		if not is_instance_valid(tree):
			return
		
		var arena = tree.current_scene
		if arena:
			const PAUSE_MENU_SCENE = preload("res://scenes/ui/PauseMenu.tscn")
			var pause_menu = PAUSE_MENU_SCENE.instantiate()
			tree.root.add_child(pause_menu)
			if "pause_menu_instance" in arena:
				arena.pause_menu_instance = pause_menu
	else:
		# Ana menüye geri dön
		var tree = get_tree()
		if tree:
			tree.change_scene_to_file("res://scenes/ui/MainMenu.tscn")
