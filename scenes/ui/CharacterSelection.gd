extends Control
class_name CharacterSelection

const UIThemeManager = preload("res://autoloads/ui_themes.gd")

# UI Node'ları
@onready var title_label: Label = $Background/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var back_button: Button = $Background/MarginContainer/VBoxContainer/Header/BackButton
@onready var character_grid: GridContainer = $Background/MarginContainer/VBoxContainer/ContentSplit/LeftPanel/CharacterGrid
@onready var stats_container: VBoxContainer = $Background/MarginContainer/VBoxContainer/ContentSplit/RightPanel/StatsContainer
@onready var stats_title: Label = $Background/MarginContainer/VBoxContainer/ContentSplit/RightPanel/StatsContainer/StatsTitle
@onready var stats_label: RichTextLabel = $Background/MarginContainer/VBoxContainer/ContentSplit/RightPanel/StatsContainer/StatsLabel

# Karakter bilgileri: [sprite_path, scene_path, name, description]
var characters = [
	["res://assets/sprites/Players/Player_1.png", "res://scenes/unit/players/player_well_rounded.tscn", "CHAR_WELL_ROUNDED_NAME", "CHAR_WELL_ROUNDED_DESC"],
	["res://assets/sprites/Players/Player_2.png", "res://scenes/unit/players/player_brawler.tscn", "CHAR_BRAWLER_NAME", "CHAR_BRAWLER_DESC"],
	["res://assets/sprites/Players/Player_3.png", "res://scenes/unit/players/player_crazy.tscn", "CHAR_CRAZY_NAME", "CHAR_CRAZY_DESC"],
	["res://assets/sprites/Players/Player_4.png", "res://scenes/unit/players/player_bunny.tscn", "CHAR_BUNNY_NAME", "CHAR_BUNNY_DESC"],
	["res://assets/sprites/Players/Player_5.png", "res://scenes/unit/players/player_kninght.tscn", "CHAR_KNIGHT_NAME", "CHAR_KNIGHT_DESC"],
	["res://assets/sprites/Players/Player_6.png", "res://scenes/unit/players/player_cardboard.tscn", "CHAR_CARDBOARD_NAME", "CHAR_CARDBOARD_DESC"]
]

var character_buttons: Array[Button] = []
var selection_indicators: Array[Control] = []
var selected_character_index: int = -2

func _ready() -> void:
	# Node'ları kontrol et
	if not character_grid:
		push_error("CharacterSelection: character_grid bulunamadı!")
		return
	
	# Geri butonunu kontrol et ve bağla
	if not back_button:
		# Eğer @onready ile bulunamadıysa, manuel bul
		back_button = get_node_or_null("Background/MarginContainer/VBoxContainer/Header/BackButton")
	
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		back_button.focus_mode = Control.FOCUS_ALL
	else:
		push_error("CharacterSelection: back_button bulunamadı!")
	
	# Karakter grid'ini doldur
	_populate_character_grid()
	
	# Font'ları uygula
	call_deferred("_apply_fonts")
	
	# Background rengini ayarla (Global Theme)
	if has_node("Background"):
		var bg_node = get_node("Background")
		if bg_node is ColorRect:
			if UIThemeManager:
				bg_node.color = UIThemeManager.COLOR_BACKGROUND_MAIN
	
	# İlk karaktere focus ver
	if character_buttons.size() > 0:
		await get_tree().process_frame
		character_buttons[0].grab_focus()

func _apply_fonts() -> void:
	await get_tree().process_frame
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)
		
		# Başlıklar ve açıklamalar için Bold font kullan
		if font_mgr.text_font_bold:
			# Ana başlık
			if title_label:
				title_label.add_theme_font_override("font", font_mgr.text_font_bold)
			
			# Özellikler başlığı
			if stats_title:
				stats_title.add_theme_font_override("font", font_mgr.text_font_bold)
			
			# Açıklama metni (Başlık fontuyla aynı olsun istendi)
			if stats_label:
				stats_label.add_theme_font_override("normal_font", font_mgr.text_font_bold)
				stats_label.add_theme_font_override("bold_font", font_mgr.text_font_bold)

func _unhandled_input(event: InputEvent) -> void:
	# ESC tuşu ile geri dön
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		get_viewport().set_input_as_handled()
		return

	# Gamepad A/X butonu ile seçim (ui_accept genelde Enter, Space, A butonu)
	if event.is_action_pressed("ui_accept"):
		var viewport = get_viewport()
		if viewport:
			var focused = viewport.gui_get_focus_owner()
			if focused is Button:
				focused.pressed.emit()
				viewport.set_input_as_handled()
				return

	# Direkt gamepad butonu kontrolü (A/X = button 0)
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed and joy_event.button_index == 0: # A/X butonu
			var viewport = get_viewport()
			if viewport:
				var focused = viewport.gui_get_focus_owner()
				if focused is Button:
					focused.pressed.emit()
					viewport.set_input_as_handled()
					return

func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _populate_character_grid() -> void:
	# Rastgele karakter butonu
	var random_button = _create_character_button(-1, "", "?", "CHAR_RANDOM_DESC")
	if random_button:
		character_grid.add_child(random_button)
	
	# Diğer karakterleri ekle
	for i in range(characters.size()):
		var char_data = characters[i]
		var char_button = _create_character_button(i, char_data[0], char_data[2], char_data[3])
		if char_button:
			character_grid.add_child(char_button)
	
	_update_selection_indicators()

func _create_character_button(index: int, sprite_path: String, char_name: String, description: String) -> Control:
	# Ana container
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(120, 150)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Karakter butonu

	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 100)
	button.flat = false
	button.focus_mode = Control.FOCUS_ALL
	button.clip_contents = true # İçeriğin taşmasını engelle
	
	# Buton stilleri - UIThemeManager kullanarak
	if UIThemeManager:
		UIThemeManager.apply_theme_to_button(button)
		
		# Karakter butonuna özel override'lar gerekirse buraya eklenebilir
		# Örneğin focus stili için border width arttırmak gibi
		var focus_style = UIThemeManager.create_stylebox(UIThemeManager.COLOR_BUTTON_NORMAL, UIThemeManager.COLOR_FOCUS_BORDER, 3)
		button.add_theme_stylebox_override("focus", focus_style)
	else:
		# Fallback styles (UIThemes yüklenmezse)
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
		button.add_theme_stylebox_override("normal", normal_style)
	
	# Sprite veya label ekle
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		# Texture'ı yükle (export uyarısını önlemek için)
		var texture = load(sprite_path) as Texture2D
		var resized_texture: Texture2D = null
		var image: Image = null
		
		if texture:
			# Texture'dan Image al (export'ta çalışır)
			if texture is ImageTexture:
				var image_texture = texture as ImageTexture
				image = image_texture.get_image()
			elif texture is CompressedTexture2D:
				# CompressedTexture2D'den Image al
				var compressed_texture = texture as CompressedTexture2D
				image = compressed_texture.get_image()
			
			# Image varsa resize et
			if image and not image.is_empty():
				# Görseli 50x50 boyutuna küçült (aspect ratio korunarak)
				var target_size = 50
				var original_size = image.get_size()
				
				# 1050x150 gibi geniş görseller için: 50 piksel genişliğe göre ölçekle
				# Her iki boyutu da kontrol et, küçük olanı kullan
				var img_scale = min(float(target_size) / original_size.x, float(target_size) / original_size.y)
				var new_size = (original_size * img_scale).round()
				
				# Görseli resize et
				if new_size.x > 0 and new_size.y > 0:
					var resized_image = image.duplicate()
					resized_image.resize(int(new_size.x), int(new_size.y), Image.INTERPOLATE_LANCZOS)
					
					# Küçültülmüş görselden ImageTexture oluştur
					resized_texture = ImageTexture.create_from_image(resized_image)
					# print("Görsel resize edildi: ", original_size, " -> ", new_size)
		
		# Eğer resize başarısız olduysa orijinal texture'ı kullan
		if not resized_texture and texture:
			resized_texture = texture
			print("Resize başarısız, orijinal texture kullanılıyor")
		
		# CenterContainer ile ortalı göster
		if resized_texture:
			var center = CenterContainer.new()
			center.set_anchors_preset(Control.PRESET_FULL_RECT)
			center.offset_left = 20
			center.offset_top = 20
			center.offset_right = -20
			center.offset_bottom = -20
			button.add_child(center)
			
			# TextureRect ile küçültülmüş görseli göster - SABİT 50x50 BOYUT
			var texture_rect = TextureRect.new()
			texture_rect.texture = resized_texture
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			# Sabit boyut: 50x50
			texture_rect.custom_minimum_size = Vector2(50, 50)
			texture_rect.size = Vector2(50, 50)
			texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			center.add_child(texture_rect)
	else:
		# Rastgele için "?" göster
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		button.add_child(center)
		
		var label = Label.new()
		label.text = "?"
		label.add_theme_font_size_override("font_size", 48)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		center.add_child(label)
	
	# İsim label'ı
	var name_label = Label.new()
	name_label.text = tr(char_name)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	
	# Container'a ekle
	container.add_child(button)
	container.add_child(name_label)
	
	# Sinyalleri bağla
	button.pressed.connect(func(): _on_character_selected(index, description))
	button.focus_entered.connect(func(): _on_character_focused(index, description))
	
	# Array'e ekle
	character_buttons.append(button)
	
	# Selection Indicator
	var indicator = UIThemeManager.create_selection_indicator()
	button.add_child(indicator)
	indicator.visible = false
	selection_indicators.append(indicator)
	
	return container

func _on_character_selected(index: int, _description: String) -> void:
	selected_character_index = index
	
	if index == -1:
		# Rastgele karakter seç
		var random_char = characters[randi() % characters.size()]
		Global.selected_character = random_char[1]
		print("Rastgele karakter seçildi: ", Global.selected_character)
	else:
		# Seçilen karakteri kaydet
		Global.selected_character = characters[index][1]
		print("Karakter seçildi: ", characters[index][2])
	
	_update_selection_indicators()
	
	# Başlangıç seçim ekranına geç (Zorluk seçimi de artık bu ekran içinde)
	get_tree().change_scene_to_file("res://scenes/ui/StartingSelection.tscn")

func _on_character_focused(index: int, description: String) -> void:
	# Özellikleri göster
	if stats_label:
		# Başlık ve açıklama
		var char_name = "?"
		if index >= 0 and index < characters.size():
			char_name = characters[index][2]
		elif index == -1:
			char_name = "CHAR_RANDOM_NAME"
			
		var text = "[b][font_size=24]" + tr(char_name) + "[/font_size][/b]\n\n"
		text += tr(description)
		
		stats_label.text = text
		
	# Focus olduğunda da seçili olanı göster (Opsiyonel: Sadece tıklandığında göstermek istiyorsak bunu eklemeyiz)
	# Ama kullanıcı "select ettiğimiz" dediği için _on_character_selected içine koymak daha doğru.

func _update_selection_indicators() -> void:
	for i in range(selection_indicators.size()):
		# Index -1 rastgele butonudur (griddeki ilk buton)
		# character_buttons ve selection_indicators sırası: [Rastgele, Char1, Char2...]
		# Bu yüzden index'i 1 artırarak veya i'ye göre kontrol ederek ayarlamalıyız.
		# _populate_character_grid önce -1'i (Rastgele) ekliyor, sonra 0, 1, 2...
		var indicator_idx = i - 1
		selection_indicators[i].visible = (indicator_idx == selected_character_index)
