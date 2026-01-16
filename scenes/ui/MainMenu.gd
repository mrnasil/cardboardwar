extends Control

const UIThemeManager = preload("res://autoloads/ui_themes.gd")

@onready var continue_button: Button = $ButtonContainer/ContinueButton
@onready var start_button: Button = $ButtonContainer/StartButton
@onready var settings_button: Button = $ButtonContainer/SettingsButton
@onready var exit_button: Button = $ButtonContainer/ExitButton
@onready var logo: TextureRect = $Logo
@onready var button_container: VBoxContainer = $ButtonContainer
@onready var studio_logo: TextureButton = $StudioLogo

func _ready() -> void:
	# Initial Setup for Animations
	# 1. Background starts black (handled by modulate)
	modulate = Color(0, 0, 0, 1)
	
	# 2. Logo starts invisible and small
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.5, 0.5)
	logo.pivot_offset = logo.size / 2 # Center pivot for scaling
	
	# Load correct studio logo textue
	var studio_tex = load("res://assets/sprites/clicker-games.png")
	if studio_tex:
		studio_logo.texture_normal = studio_tex
	
	# Studio Logo Interaction
	studio_logo.pressed.connect(func(): OS.shell_open("https://clicker.games"))
	studio_logo.mouse_entered.connect(func(): studio_logo.modulate = Color(0, 0, 0)) # Invert (assumes white logo)
	studio_logo.mouse_exited.connect(func(): studio_logo.modulate = Color(1, 1, 1)) # Reset
	
	# 3. Menu starts off-screen right
	var screen_width = get_viewport_rect().size.x
	# Adjust for container width (approx 300)
	var final_pos_x = button_container.position.x
	button_container.position.x = screen_width + 50 # Start off-screen
	
	# Play Intro Animation
	_play_intro_animation(final_pos_x)

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
	
	# Butonların text'lerini kontrol et
	print("MainMenu: Buton text'leri:")
	print("  - StartButton: '", start_button.text, "'")
	print("  - SettingsButton: '", settings_button.text, "'")
	print("  - ExitButton: '", exit_button.text, "'")
	
	# Font'ları uygula - FontManager'ın hazır olmasını bekle
	call_deferred("_apply_fonts")
	
	# Theme uygula
	_apply_theme()

func _play_intro_animation(final_menu_x: float) -> void:
	var tween = create_tween()
	
	# Step 1: Background Fade In (Main Canvas Modulate)
	# This reveals the background texture (which is static)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Step 2: Logo Appears (Fade In + Scale Up) - Starts slightly after BG
	# Parallel execution for logo
	tween.parallel().tween_property(logo, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(logo, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Step 3: Menu Slides In from Right - After Logo is mostly done
	# Add a small delay or chain it
	# We want it to start *after* logo is mostly visible, so we chain.
	# But user said "logo arkadan belirsin, o gecince menu gelsin" (menu comes after logo appears)
	tween.tween_property(button_container, "position:x", final_menu_x, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)

func _apply_theme() -> void:
	# Removed custom modulate tween from here as it is handled in _play_intro_animation
	if not UIThemeManager:
		return
		
	# Background rengi
	if has_node("Background"):
		var bg = get_node("Background")
		if bg is ColorRect:
			bg.color = UIThemeManager.COLOR_BACKGROUND_MAIN
			
	# Buton stilleri
	UIThemeManager.apply_theme_to_button(continue_button)
	UIThemeManager.apply_theme_to_button(start_button)
	UIThemeManager.apply_theme_to_button(settings_button)
	UIThemeManager.apply_theme_to_button(exit_button)

func _apply_fonts() -> void:
	# FontManager'ın hazır olmasını bekle
	await get_tree().process_frame
	await get_tree().process_frame # Bir frame daha bekle
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		# Font'ları uygula - font yoksa sistem font'u kullanılacak
		font_mgr.apply_fonts_recursive(self)
		
		# Font'lar yüklenmemişse tekrar dene
		if not font_mgr.number_font and not font_mgr.text_font and not font_mgr.text_font_bold:
			await get_tree().create_timer(0.2).timeout
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
