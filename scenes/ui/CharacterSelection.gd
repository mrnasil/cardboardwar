extends Control

@onready var back_button: Button = $TopBar/BackButton
@onready var character_grid: GridContainer = $CenterContainer/CharacterGrid

# Karakter bilgileri: [sprite_path, scene_path, name]
var characters = [
	["res://assets/sprites/Players/Player_1.png", "res://scenes/unit/players/player_well_rounded.tscn", "Well Rounded"],
	["res://assets/sprites/Players/Player_2.png", "res://scenes/unit/players/player_brawler.tscn", "Brawler"],
	["res://assets/sprites/Players/Player_3}.png", "res://scenes/unit/players/player_crazy.tscn", "Crazy"],
	["res://assets/sprites/Players/Player_4.png", "res://scenes/unit/players/player_bunny.tscn", "Bunny"],
	["res://assets/sprites/Players/Player_5.png", "res://scenes/unit/players/player_kninght.tscn", "Knight"],
	["res://assets/sprites/Players/Player_6.png", "res://scenes/unit/players/player_cardboard.tscn", "Cardboard"]
]

var character_buttons: Array[TextureButton] = []

func _ready() -> void:
	print("CharacterSelection _ready() başladı")
	
	# Grid'in var olup olmadığını kontrol et
	if not character_grid:
		print("HATA: character_grid bulunamadı!")
		return
	
	print("character_grid bulundu, visible: ", character_grid.visible)
	print("character_grid size: ", character_grid.size)
	
	# Geri butonunu sinyale bağla
	if back_button:
		back_button.pressed.connect(_on_back_button_pressed)
		back_button.focus_mode = Control.FOCUS_ALL
		print("Back button bağlandı")
	else:
		print("HATA: back_button bulunamadı!")
	
	# Karakter grid'ini doldur
	_populate_character_grid()
	
	# Focus bağlantılarını ayarla
	_setup_focus_connections()
	
	# Input işlemlerini etkinleştir
	set_process_unhandled_input(true)
	
	# İlk karakter butonuna focus ver
	if character_buttons.size() > 0:
		# Bir frame bekle ki layout tamamlanmış olsun
		await get_tree().process_frame
		character_buttons[0].grab_focus()
		print("İlk karakter butonuna focus verildi")
	else:
		print("UYARI: Hiç karakter butonu yok!")
		if back_button:
			back_button.grab_focus()
	
	# Font'ları uygula
	call_deferred("_apply_fonts")

func _apply_fonts() -> void:
	# Bir frame bekle (font'ların yüklenmesi için)
	await get_tree().process_frame
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)

func _unhandled_input(event: InputEvent) -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	
	# Gamepad B butonu kontrolü (button_index 1)
	if event is InputEventJoypadButton:
		var joypad_event = event as InputEventJoypadButton
		if joypad_event.pressed and joypad_event.button_index == 1:  # B butonu
			_on_back_button_pressed()
			viewport.set_input_as_handled()
			return
	
	# ESC tuşu ile geri dön
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()
		viewport.set_input_as_handled()
		return
	
	# Gamepad A butonu kontrolü (button_index 0)
	if event is InputEventJoypadButton:
		var joypad_event = event as InputEventJoypadButton
		if joypad_event.pressed and joypad_event.button_index == 0:  # A butonu
			var focused = viewport.gui_get_focus_owner()
			if focused is TextureButton:
				focused.pressed.emit()
				viewport.set_input_as_handled()
				return
			elif focused is Button:
				focused.pressed.emit()
				viewport.set_input_as_handled()
				return
	
	# Gamepad ve klavye desteği - Enter/Space
	if event.is_action_pressed("ui_accept"):
		var focused = viewport.gui_get_focus_owner()
		if focused is TextureButton:
			focused.pressed.emit()
			viewport.set_input_as_handled()
		elif focused is Button:
			focused.pressed.emit()
			viewport.set_input_as_handled()
		return
	
	# Gamepad D-pad veya analog stick ile navigasyon (eğer focus yoksa)
	if not viewport.gui_get_focus_owner():
		# Gamepad D-pad kontrolü (Godot 4'te D-pad butonları: 11=UP, 12=DOWN, 13=LEFT, 14=RIGHT)
		if event is InputEventJoypadButton:
			var joypad_event = event as InputEventJoypadButton
			if joypad_event.pressed:
				# D-pad butonları
				if joypad_event.button_index == 11 or \
				   joypad_event.button_index == 12 or \
				   joypad_event.button_index == 13 or \
				   joypad_event.button_index == 14:
					if character_buttons.size() > 0:
						character_buttons[0].grab_focus()
						viewport.set_input_as_handled()
		# Gamepad analog stick kontrolü
		elif event is InputEventJoypadMotion:
			var motion_event = event as InputEventJoypadMotion
			# Analog stick deadzone kontrolü
			if abs(motion_event.axis_value) > 0.5:
				if character_buttons.size() > 0:
					character_buttons[0].grab_focus()
					viewport.set_input_as_handled()
		# Klavye ile ok tuşları ile navigasyon
		elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
		     event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			if character_buttons.size() > 0:
				character_buttons[0].grab_focus()
				viewport.set_input_as_handled()
		return

func _on_back_button_pressed() -> void:
	# Ana menüye geri dön
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _start_game(character_scene: String = "") -> void:
	# Seçilen karakteri kaydet (eğer belirtilmişse)
	if character_scene != "":
		Global.selected_character = character_scene
		print("Karakter seçildi: ", character_scene)
	else:
		# Rastgele karakter seç
		var random_char = characters[randi() % characters.size()]
		Global.selected_character = random_char[1]
		print("Rastgele karakter seçildi: ", Global.selected_character)
	
	# Global.selected_character'ın doğru set edildiğini kontrol et
	print("Global.selected_character set edildi: ", Global.selected_character)
	
	# Zorluk seçim ekranına geç
	get_tree().change_scene_to_file("res://scenes/ui/difficulty_selection.tscn")

func _populate_character_grid() -> void:
	print("_populate_character_grid() başladı")
	
	# Grid'in görünür olduğundan emin ol
	character_grid.visible = true
	print("Grid visible yapıldı")
	
	# İlk karakter olarak rastgele butonu ekle (sprite_path boş, özel görünüm için)
	print("Rastgele buton oluşturuluyor...")
	var random_button = _create_character_button("", "", "?")
	if random_button:
		character_grid.add_child(random_button)
		print("Rastgele buton eklendi")
	else:
		print("HATA: Rastgele buton oluşturulamadı!")
	
	# Diğer karakterleri ekle
	print("Karakter sayısı: ", characters.size())
	for i in range(characters.size()):
		var char_data = characters[i]
		print("Karakter ", i, " oluşturuluyor: ", char_data[0])
		var char_button = _create_character_button(char_data[0], char_data[1], str(i + 1))
		if char_button:
			character_grid.add_child(char_button)
			print("Karakter ", i, " eklendi")
		else:
			print("HATA: Karakter ", i, " oluşturulamadı!")
	
	print("Karakter grid'ine toplam ", character_grid.get_child_count(), " buton eklendi")
	print("character_buttons array size: ", character_buttons.size())

func _create_character_button(sprite_path: String, scene_path: String, label_text: String) -> Control:
	print("_create_character_button çağrıldı - sprite_path: ", sprite_path, ", scene_path: ", scene_path)
	
	# Ana container - Panel ile çerçeve oluştur
	var container = Panel.new()
	container.custom_minimum_size = Vector2(60, 60)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.visible = true
	container.focus_mode = Control.FOCUS_NONE  # Panel focus almasın, TextureButton alsın
	container.clip_contents = true  # İçeriğin kutunun dışına taşmasını engelle
	
	# Panel'in görünür olması için stil ekle (normal durum)
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Koyu gri arka plan
	style_box.border_color = Color(0.5, 0.2, 0.8, 1.0)  # Mor kenarlık
	style_box.border_width_left = 2
	style_box.border_width_top = 2
	style_box.border_width_right = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 5
	style_box.corner_radius_top_right = 5
	style_box.corner_radius_bottom_left = 5
	style_box.corner_radius_bottom_right = 5
	container.add_theme_stylebox_override("panel", style_box)
	
	# Panel için focus stili (seçildiğinde arka plan değişsin)
	var focus_style_box = StyleBoxFlat.new()
	focus_style_box.bg_color = Color(0.4, 0.3, 0.5, 0.9)  # Daha açık mor arka plan
	focus_style_box.border_color = Color(1.0, 0.8, 0.0, 1.0)  # Altın sarısı kenarlık
	focus_style_box.border_width_left = 3
	focus_style_box.border_width_top = 3
	focus_style_box.border_width_right = 3
	focus_style_box.border_width_bottom = 3
	focus_style_box.corner_radius_top_left = 5
	focus_style_box.corner_radius_top_right = 5
	focus_style_box.corner_radius_bottom_left = 5
	focus_style_box.corner_radius_bottom_right = 5
	# Not: Panel focus almadığı için bu stili TextureButton focus değişikliğinde kullanacağız
	
	# TextureButton oluştur - Panel'in tamamını kaplasın
	var button = TextureButton.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_ALL
	button.visible = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# TextureButton'u şeffaf yap (normal durum)
	var normal_style = StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", normal_style)
	button.add_theme_stylebox_override("pressed", normal_style)
	
	# Focus stilini ekle (TextureButton için)
	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = Color(0.4, 0.3, 0.5, 0.3)  # Hafif mor arka plan
	focus_style.border_color = Color(1.0, 0.8, 0.0, 1.0)  # Altın sarısı kenarlık
	focus_style.border_width_left = 4
	focus_style.border_width_top = 4
	focus_style.border_width_right = 4
	focus_style.border_width_bottom = 4
	focus_style.corner_radius_top_left = 3
	focus_style.corner_radius_top_right = 3
	focus_style.corner_radius_bottom_left = 3
	focus_style.corner_radius_bottom_right = 3
	button.add_theme_stylebox_override("focus", focus_style)
	
	# Focus değişikliğini dinle - Panel'in arka plan rengini değiştir
	button.focus_entered.connect(func(): _on_button_focus_entered(container))
	button.focus_exited.connect(func(): _on_button_focus_exited(container))
	
	# TextureButton'u önce ekle (alt katmanda)
	container.add_child(button)
	
	# Sprite'ı yükle - Panel'in içine ekle (üst katmanda)
	if sprite_path != "":
		if ResourceLoader.exists(sprite_path):
			print("Sprite yükleniyor: ", sprite_path)
			var texture = load(sprite_path) as Texture2D
			if texture:
				# CenterContainer ile görseli ortalı küçük göster
				var center = CenterContainer.new()
				center.set_anchors_preset(Control.PRESET_FULL_RECT)
				center.mouse_filter = Control.MOUSE_FILTER_IGNORE
				center.z_index = 1  # TextureButton'un üstünde görünsün
				container.add_child(center)
				
				# Küçük TextureRect oluştur
				var texture_rect = TextureRect.new()
				texture_rect.texture = texture
				texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				texture_rect.custom_minimum_size = Vector2(30, 30)  # Küçük boyut
				texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				center.add_child(texture_rect)
				print("Sprite yüklendi: ", sprite_path)
			else:
				print("HATA: Texture yüklenemedi: ", sprite_path)
		else:
			print("HATA: Sprite dosyası bulunamadı: ", sprite_path)
	else:
		# Rastgele için özel görünüm
		print("Rastgele buton için label oluşturuluyor")
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.z_index = 1  # TextureButton'un üstünde görünsün
		container.add_child(center)
		
		var random_label = Label.new()
		random_label.text = "?"
		random_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		random_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		random_label.add_theme_font_size_override("font_size", 40)
		random_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(random_label)
	
	# Butonu array'e ekle (focus için)
	character_buttons.append(button)
	print("Button array'e eklendi, toplam: ", character_buttons.size())
	
	# Tıklama sinyalini bağla
	if scene_path != "":
		button.pressed.connect(func(): _start_game(scene_path))
	else:
		button.pressed.connect(func(): _start_game())
	
	print("Container oluşturuldu, size: ", container.size)
	return container

func _setup_focus_connections() -> void:
	var columns = character_grid.columns  # Grid sütun sayısını grid'den al
	
	# Karakter butonları arası focus bağlantılarını ayarla
	# TextureButton'lar Panel içinde olduğu için path'leri doğru almak gerekiyor
	for i in range(character_buttons.size()):
		var button = character_buttons[i]
		if not is_instance_valid(button):
			continue
			
		var row = i / columns
		var col = i % columns
		
		# Sol komşu
		if col > 0 and i > 0:
			var left_button = character_buttons[i - 1]
			if is_instance_valid(left_button):
				button.focus_neighbor_left = left_button.get_path()
		else:
			# İlk sütun - geri butonuna
			if is_instance_valid(back_button):
				button.focus_neighbor_left = back_button.get_path()
		
		# Sağ komşu
		if col < columns - 1 and i < character_buttons.size() - 1:
			var right_button = character_buttons[i + 1]
			if is_instance_valid(right_button):
				button.focus_neighbor_right = right_button.get_path()
		else:
			# Son sütun - ilk sütuna döngü
			var first_in_row = row * columns
			if first_in_row < character_buttons.size():
				var first_button = character_buttons[first_in_row]
				if is_instance_valid(first_button):
					button.focus_neighbor_right = first_button.get_path()
		
		# Üst komşu
		if row > 0:
			var top_index = (row - 1) * columns + col
			if top_index < character_buttons.size():
				var top_button = character_buttons[top_index]
				if is_instance_valid(top_button):
					button.focus_neighbor_top = top_button.get_path()
		else:
			# İlk satır - geri butonuna
			if is_instance_valid(back_button):
				button.focus_neighbor_top = back_button.get_path()
		
		# Alt komşu
		var bottom_index = (row + 1) * columns + col
		if bottom_index < character_buttons.size():
			var bottom_button = character_buttons[bottom_index]
			if is_instance_valid(bottom_button):
				button.focus_neighbor_bottom = bottom_button.get_path()
		else:
			# Son satır - yukarı döngü (ilk satırdaki aynı sütun)
			var top_index_loop = col
			if top_index_loop < character_buttons.size():
				var top_button = character_buttons[top_index_loop]
				if is_instance_valid(top_button):
					button.focus_neighbor_bottom = top_button.get_path()
	
	# Geri butonundan ilk karakter butonuna
	if character_buttons.size() > 0 and is_instance_valid(character_buttons[0]):
		if is_instance_valid(back_button):
			back_button.focus_neighbor_right = character_buttons[0].get_path()
			back_button.focus_neighbor_bottom = character_buttons[0].get_path()

func _on_button_focus_entered(panel: Panel) -> void:
	# Panel'in arka plan rengini değiştir (seçildiğinde)
	var focus_style_box = StyleBoxFlat.new()
	focus_style_box.bg_color = Color(0.4, 0.3, 0.5, 0.9)  # Daha açık mor arka plan
	focus_style_box.border_color = Color(1.0, 0.8, 0.0, 1.0)  # Altın sarısı kenarlık
	focus_style_box.border_width_left = 3
	focus_style_box.border_width_top = 3
	focus_style_box.border_width_right = 3
	focus_style_box.border_width_bottom = 3
	focus_style_box.corner_radius_top_left = 5
	focus_style_box.corner_radius_top_right = 5
	focus_style_box.corner_radius_bottom_left = 5
	focus_style_box.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", focus_style_box)

func _on_button_focus_exited(panel: Panel) -> void:
	# Panel'in arka plan rengini normale döndür
	var normal_style_box = StyleBoxFlat.new()
	normal_style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Koyu gri arka plan
	normal_style_box.border_color = Color(0.5, 0.2, 0.8, 1.0)  # Mor kenarlık
	normal_style_box.border_width_left = 2
	normal_style_box.border_width_top = 2
	normal_style_box.border_width_right = 2
	normal_style_box.border_width_bottom = 2
	normal_style_box.corner_radius_top_left = 5
	normal_style_box.corner_radius_top_right = 5
	normal_style_box.corner_radius_bottom_left = 5
	normal_style_box.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", normal_style_box)
