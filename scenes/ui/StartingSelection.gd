extends Control
class_name StartingSelection

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var item_container: GridContainer = $MarginContainer/VBoxContainer/ContentSplit/LeftPanel/ItemContainer
@onready var difficulty_container: HBoxContainer = $MarginContainer/VBoxContainer/ContentSplit/LeftPanel/DifficultyContainer
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ActionsContainer/ContinueButton
@onready var stats_container: VBoxContainer = $MarginContainer/VBoxContainer/ContentSplit/RightPanel/StatsContainer

const UIThemeManager = preload("res://autoloads/ui_themes.gd")

signal item_selected(item_data)

var available_items: Array = []
var item_buttons: Array[Button] = []
var selected_item = null
var selected_button_index: int = 0
var is_on_continue_button: bool = false
var active_selection_index: int = -1
var is_on_difficulty_selection: bool = false

var stats_tooltip: StatsTooltip = null
var tooltips_enabled: bool = true
var helper_label: Label = null
var selection_indicators: Array[Control] = []

# Difficulty Selection
var difficulty_buttons: Array[Button] = []
var difficulty_indicators: Array[Control] = []
var active_difficulty_index: int = 0

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.focus_entered.connect(_on_continue_focus_entered)
	continue_button.disabled = true
	continue_button.focus_mode = Control.FOCUS_ALL
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	_show_starting_items()
	_setup_difficulty_selection()
	_update_character_stats()
	_setup_stats_tooltip()
	_create_helper_label()
	
	call_deferred("_apply_fonts")
	_update_button_highlight()

func _update_character_stats() -> void:
	if not stats_container:
		return
		
	for child in stats_container.get_children():
		child.queue_free()
		
	# Load selected character data to display stats
	print("StartingSelection: Karakter stats güncelleniyor. Karakter: ", Global.selected_character)
	if Global.selected_character:
		# 1. Image & Name Container
		var char_info_container = VBoxContainer.new()
		char_info_container.alignment = BoxContainer.ALIGNMENT_CENTER
		char_info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats_container.add_child(char_info_container)
		
		# Load Scene
		var char_scene = load(Global.selected_character) as PackedScene
		if char_scene:
			var char_instance = char_scene.instantiate()
			
			# 2. Character Image
			var texture: Texture2D = null
			
			# Try to find sprite node (Unified path for unit/player scenes)
			var sprite_node = char_instance.get_node_or_null("Visuals/Sprite")
			if not sprite_node:
				# Recursive search as fallback
				for child in char_instance.find_children("*", "Sprite2D", true):
					if child.name == "Sprite" or child.name == "Sprite2D":
						sprite_node = child
						break
			
			if sprite_node and "texture" in sprite_node:
				texture = sprite_node.texture
			
			if texture:
				print("StartingSelection: Karakter görseli bulundu: ", texture.resource_path)
				var tex_rect = TextureRect.new()
				tex_rect.texture = texture
				tex_rect.custom_minimum_size = Vector2(160, 160)
				tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				char_info_container.add_child(tex_rect)
			else:
				print("StartingSelection: Karakter görseli bulunamadı! Yol: ", Global.selected_character)
				# Fallback text if image missing
				var placeholder = Label.new()
				placeholder.text = "[No Image]"
				char_info_container.add_child(placeholder)
			
			# 3. Character Name (from scene name or property?)
			# Assuming scene filename or custom property 'char_name'
			var char_name_text = "Unknown"
			# Try to map filename to name if possible, or use class name
			# For now, let's look for translation key logic or just use scene name
			# Simpler: Map path to known names used in CharacterSelection
			# But CharacterSelection didn't save name globally, only path.
			# Let's try to deduce from path or just skip name if hard.
			# User asked for "image ... below name ... below stats"
			
			# Attempt to deduce name from file path
			var path_str = Global.selected_character
			if "well_rounded" in path_str: char_name_text = "CHAR_WELL_ROUNDED_NAME"
			elif "brawler" in path_str: char_name_text = "CHAR_BRAWLER_NAME"
			elif "crazy" in path_str: char_name_text = "CHAR_CRAZY_NAME"
			elif "bunny" in path_str: char_name_text = "CHAR_BUNNY_NAME"
			elif "knight" in path_str: char_name_text = "CHAR_KNIGHT_NAME"
			elif "cardboard" in path_str: char_name_text = "CHAR_CARDBOARD_NAME"
			
			var name_label = Label.new()
			name_label.text = tr(char_name_text)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.theme_type_variation = "HeaderLarge" # Or bold if possible
			# If FontManager overrides, let it be. But we can add styling.
			name_label.add_theme_font_size_override("font_size", 24)
			char_info_container.add_child(name_label)
			
			# Spacer
			var spacer = Control.new()
			spacer.custom_minimum_size.y = 20
			stats_container.add_child(spacer)

			# 4. Stats
			# ... existing stat logic ...
			if "stats" in char_instance and char_instance.stats:
				var s = char_instance.stats
				var txt = ""
				# Use property access but wrap in safety or verify class
				
				# Health
				var hp = s.max_hp if "max_hp" in s else 0
				txt += "Max HP: " + str(hp) + "\n"
				
				# Damage
				var dmg = s.damage if "damage" in s else 0
				txt += "Damage: " + str(dmg) + "\n"
				
				# Melee
				if "melee_damage" in s:
					txt += "Melee Dmg: " + str(s.melee_damage) + "\n"
				
				# Ranged
				if "ranged_damage" in s:
					txt += "Ranged Dmg: " + str(s.ranged_damage) + "\n"
					
				# Speed
				var spd = s.speed if "speed" in s else 0
				txt += "Speed: " + str(spd) + "\n"
				
				# Armor
				var arm = s.armor if "armor" in s else 0
				txt += "Armor: " + str(arm)
				
				var label = Label.new()
				label.text = txt
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				stats_container.add_child(label)
				
			char_instance.queue_free()

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
		
		# Zorluk butonlarına da font uygula (sayılar için)
		for button in difficulty_buttons:
			if is_instance_valid(button) and font_mgr.number_font:
				button.add_theme_font_override("font", font_mgr.number_font)

func _apply_font_to_button(button: Button) -> void:
	if not button or not is_instance_valid(button):
		return
	
	if not has_node("/root/FontManager"):
		return
	
	var font_mgr = get_node("/root/FontManager")
	if not font_mgr:
		return
	
	# FontManager'ın apply_font_to_button metodunu kullan
	font_mgr.apply_font_to_button(button)

func _show_starting_items() -> void:
	# İlk eşya seçiminde weapon seçimi yapılacak
	var weapons: Array[ItemWeapon] = []
	
	# Weapon resource'larını bul (sadece seviye 1 weapon'lar)
	var weapon_paths = [
		"res://resources/items/weapons/melee/punch/item_punch_1.tres",
		"res://resources/items/weapons/melee/knife/item_knife_1.tres",
		"res://resources/items/weapons/range/pistol/item_pistol_1.tres"
	]
	
	# Mevcut weapon'ları yükle
	for path in weapon_paths:
		if ResourceLoader.exists(path):
			var weapon = load(path) as ItemWeapon
			if weapon:
				weapons.append(weapon)
				print("StartingSelection: Weapon yüklendi: ", weapon.item_name, " (", path, ")")
			else:
				print("StartingSelection: Uyarı - Weapon yüklenemedi (null): ", path)
		else:
			print("StartingSelection: Uyarı - Weapon dosyası bulunamadı: ", path)
	
	print("StartingSelection: Toplam ", weapons.size(), " weapon yüklendi")
	
	# İlk round'da TÜM silahları göster
	var selected_weapons: Array[ItemWeapon] = weapons.duplicate()
	
	print("StartingSelection: İlk round - Tüm ", selected_weapons.size(), " weapon gösteriliyor:")
	for weapon in selected_weapons:
		print("  - ", weapon.item_name)
	
	# Item formatına çevir (weapon seçimi için)
	var items = []
	for weapon in selected_weapons:
		var weapon_name = weapon.item_name if weapon.item_name else "Weapon"
		var item = {
			"name": weapon_name,
			"type": "weapon",
			"weapon_data": weapon
		}
		items.append(item)
	
	show_items(items)

func show_items(items: Array) -> void:
	available_items = items
	selected_item = null
	continue_button.disabled = true
	selected_button_index = 0
	active_selection_index = -1
	is_on_continue_button = false
	item_buttons.clear()
	selection_indicators.clear()
	
	# Mevcut item butonlarını temizle
	for child in item_container.get_children():
		child.queue_free()
	
	# Item butonlarını oluştur
	for i in range(items.size()):
		var item = items[i]
		
		# Container (Card)
		var card = VBoxContainer.new()
		card.custom_minimum_size = Vector2(110, 140)
		card.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Button (Icon Container)
		var button = Button.new()
		button.custom_minimum_size = Vector2(100, 100)
		button.focus_mode = Control.FOCUS_ALL
		button.clip_contents = true
		
		# Icon
		var icon_tex = null
		if item.weapon_data:
			if "item_icon" in item.weapon_data and item.weapon_data.item_icon:
				icon_tex = item.weapon_data.item_icon
			elif "icon" in item.weapon_data and item.weapon_data.icon:
				icon_tex = item.weapon_data.icon
			elif "texture" in item.weapon_data and item.weapon_data.texture:
				icon_tex = item.weapon_data.texture
			
		if icon_tex:
			var center = CenterContainer.new()
			center.set_anchors_preset(Control.PRESET_FULL_RECT)
			button.add_child(center)
			
			var tex_rect = TextureRect.new()
			tex_rect.texture = icon_tex
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(64, 64)
			center.add_child(tex_rect)
		else:
			button.text = "?"
		
		# Name Label
		var label = Label.new()
		label.text = item.name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 100
		
		card.add_child(button)
		card.add_child(label)
		item_container.add_child(card)
		
		item_buttons.append(button)
		
		# Selection Indicator
		var indicator = UIThemeManager.create_selection_indicator()
		button.add_child(indicator)
		indicator.visible = false
		selection_indicators.append(indicator)
		
		# Events
		button.pressed.connect(_on_item_selected.bind(item, button))
		button.focus_entered.connect(_on_focus_entered.bind(i))
		button.mouse_entered.connect(_on_mouse_entered.bind(i))
		button.mouse_exited.connect(_on_mouse_exited)
		
		# Basic Style
		if not UIThemeManager:
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.2, 0.2, 1.0)
			button.add_theme_stylebox_override("normal", style)
		else:
			UIThemeManager.apply_theme_to_button(button)
			
		# Apply Font
		call_deferred("_apply_font_to_button", button)
	
	# Focus Connections (Grid to Continue Button)
	# Grid internal navigation is automatic. We only need to handle escaping to Continue.
	
	# İlk butonu vurgula
	if item_buttons.size() > 0:
		_update_button_highlight()
		await get_tree().process_frame
		item_buttons[0].grab_focus()
	
	# Ekranı göster
	visible = true

func _setup_difficulty_selection() -> void:
	# Zorluk butonlarını oluştur (0-5)
	for child in difficulty_container.get_children():
		child.queue_free()
	
	difficulty_buttons.clear()
	difficulty_indicators.clear()
	
	# Global'den mevcut zorluğu al
	active_difficulty_index = Global.selected_difficulty
	
	for i in range(6):
		var button = Button.new()
		button.text = str(i)
		button.custom_minimum_size = Vector2(50, 40)
		button.focus_mode = Control.FOCUS_ALL
		button.pressed.connect(_on_difficulty_selected.bind(i))
		button.focus_entered.connect(_on_difficulty_focus_entered.bind(i))
		button.mouse_entered.connect(_on_difficulty_focus_entered.bind(i))
		difficulty_container.add_child(button)
		difficulty_buttons.append(button)
		
		UIThemeManager.apply_theme_to_button(button)
		
		# Indicator
		var indicator = UIThemeManager.create_selection_indicator()
		button.add_child(indicator)
		indicator.visible = (i == active_difficulty_index)
		difficulty_indicators.append(indicator)

func _on_difficulty_selected(index: int) -> void:
	active_difficulty_index = index
	Global.selected_difficulty = index
	print("Zorluk seçildi: ", index)
	_update_button_highlight()

func _on_difficulty_focus_entered(index: int) -> void:
	selected_button_index = index # Reuse index for visual focus if helpful or just use for logic
	is_on_difficulty_selection = true
	is_on_continue_button = false
	_update_button_highlight()
	_hide_tooltip()

func _setup_focus_connections() -> void:
	# Grid Container handles internal arrow navigation reasonably well.
	# We mainly need to ensure down from bottom row goes to Continue Button.
	pass

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	var viewport = get_viewport()
	
	# Gamepad A/X butonu veya klavye Enter/Space - SEÇİM İŞLEMİ
	var is_accept = false
	
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.pressed:
			if joy_event.button_index == 0: # A/X button
				is_accept = true
			elif joy_event.button_index == JOY_BUTTON_X: # X/Square button
				# X tuşu ile tooltip'leri aç/kapat
				tooltips_enabled = !tooltips_enabled
				if not tooltips_enabled:
					_hide_tooltip()
				elif not is_on_continue_button and selected_button_index < item_buttons.size():
					_show_tooltip_for_index(selected_button_index)
				
				_update_helper_label()
				if viewport:
					viewport.set_input_as_handled()
				return
	elif event.is_action_pressed("ui_accept"):
		is_accept = true
	elif event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed:
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE:
				is_accept = true
			elif key_event.keycode == KEY_X:
				# X tuşu ile tooltip'leri aç/kapat
				tooltips_enabled = !tooltips_enabled
				if not tooltips_enabled:
					_hide_tooltip()
				elif not is_on_continue_button and selected_button_index < item_buttons.size():
					_show_tooltip_for_index(selected_button_index)
				
				_update_helper_label()
				viewport.set_input_as_handled()
				return
	
	if is_accept:
		# Odaklanılan butona göre işlem yap
		# (Focus sistemi ile selected_button_index güncelleniyor)
		if is_on_continue_button and not continue_button.disabled:
			_on_continue_pressed()
		elif not is_on_continue_button and selected_button_index < item_buttons.size():
			var button = item_buttons[selected_button_index]
			var item = available_items[selected_button_index]
			_on_item_selected(item, button)
		
		# Input'u handle et
		if viewport:
			viewport.set_input_as_handled()
		return
	
	# Y tuşu basılı tutulduğunda devam et
	if event is InputEventJoypadButton:
		var joy_event = event as InputEventJoypadButton
		if joy_event.button_index == JOY_BUTTON_Y and joy_event.pressed: # Y/Triangle
			if not continue_button.disabled:
				_on_continue_pressed()
			
			if viewport:
				viewport.set_input_as_handled()
			return

	# Navigation manuel olarak YAPILMIYOR, Godot'un focus sistemi hallediyor.

func _on_focus_entered(index: int) -> void:
	selected_button_index = index
	is_on_continue_button = false
	is_on_difficulty_selection = false
	_update_button_highlight()
	
	if tooltips_enabled:
		_show_tooltip_for_index(index)

func _on_mouse_entered(index: int) -> void:
	selected_button_index = index
	is_on_continue_button = false
	is_on_difficulty_selection = false
	_update_button_highlight()
	
	if tooltips_enabled:
		_show_tooltip_for_index(index)

func _on_mouse_exited() -> void:
	_hide_tooltip()

func _show_tooltip_for_index(index: int) -> void:
	if not stats_tooltip or index >= available_items.size():
		return
		
	var item = available_items[index]
	var button = item_buttons[index]
	
	if item.has("weapon_data") and item.weapon_data:
		var data = StatsTooltip.create_item_weapon_stats_data(item.weapon_data)
		if not data.is_empty():
			var pos = button.global_position
			pos.x += button.size.x + 20
			stats_tooltip.show_tooltip(data, pos)

func _hide_tooltip() -> void:
	if stats_tooltip:
		stats_tooltip.hide_tooltip()

func _on_continue_focus_entered() -> void:
	is_on_continue_button = true
	_update_button_highlight()
	_hide_tooltip()

func _on_item_selected(item_data, button: Button) -> void:
	selected_item = item_data
	
	# Seçili butonun index'ini bul
	for i in range(item_buttons.size()):
		if item_buttons[i] == button:
			active_selection_index = i
			
			# Eğer mouse ile seçildiyse selected_button_index'i de güncelle
			# ki klavye/gamepad o noktadan devam edebilsin
			selected_button_index = i
			break
	
	is_on_continue_button = false
	
	# Görünümü güncelle
	_update_button_highlight()
	
	continue_button.disabled = false
	continue_button.modulate = Color.WHITE
	
	item_selected.emit(item_data)
	print("İlk eşya seçildi: ", item_data)

func _update_button_highlight() -> void:
	# Tüm item butonlarını güncelle
	# Tüm item butonlarını güncelle
	for i in range(item_buttons.size()):
		var button = item_buttons[i]
		
		# Renkleri belirle (UIThemeManager varsa)
		var bg_color = Color(0.2, 0.2, 0.2, 1.0)
		var border_color = Color.TRANSPARENT
		var border_width = 0
		
		if UIThemeManager:
			bg_color = UIThemeManager.COLOR_BUTTON_NORMAL
			
			# 1. Durum: Bu item SEÇİLMİŞ item mi? (Active Selection)
			if i == active_selection_index:
				bg_color = UIThemeManager.COLOR_SELECTION_ACTIVE
			
			# 2. Durum: Bu item üzerinde FOCUS var mı? (Gezinme imleci)
			if i == selected_button_index and not is_on_continue_button and not is_on_difficulty_selection:
				border_color = UIThemeManager.COLOR_FOCUS_BORDER
				border_width = 2
		else:
			# Fallback
			if i == active_selection_index:
				bg_color = Color(0.0, 0.5, 0.0, 1.0)
			
			if i == selected_button_index and not is_on_continue_button and not is_on_difficulty_selection:
				border_color = Color(1.0, 1.0, 0.0, 1.0)
				border_width = 2
				
		# Stili oluştur
		var style: StyleBoxFlat
		if UIThemeManager:
			style = UIThemeManager.create_stylebox(bg_color, border_color, border_width)
		else:
			style = StyleBoxFlat.new()
			style.bg_color = bg_color
			style.border_color = border_color
			style.border_width_left = border_width
			style.border_width_top = border_width
			style.border_width_right = border_width
			style.border_width_bottom = border_width
			
		# Stili diğer durumlara da uygula ki renk değişimi her durumda görünsün
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("disabled", style)
		button.add_theme_stylebox_override("focus", style)
		
		# Tick işaretini göster/gizle
		if i < selection_indicators.size():
			selection_indicators[i].visible = (i == active_selection_index)
	
	# Zorluk butonlarını güncelle
	for i in range(difficulty_buttons.size()):
		var button = difficulty_buttons[i]
		var bg_color = UIThemeManager.COLOR_BUTTON_NORMAL
		var border_color = Color.TRANSPARENT
		var border_width = 0
		
		if i == active_difficulty_index:
			bg_color = UIThemeManager.COLOR_SELECTION_ACTIVE
			
		# Focus highlight
		if i == selected_button_index and is_on_difficulty_selection:
			border_color = UIThemeManager.COLOR_FOCUS_BORDER
			border_width = 2
			
		var style = UIThemeManager.create_stylebox(bg_color, border_color, border_width)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("focus", style)
		
		if i < difficulty_indicators.size():
			difficulty_indicators[i].visible = (i == active_difficulty_index)
	
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

func _setup_stats_tooltip() -> void:
	stats_tooltip = _create_stats_tooltip()
	if stats_tooltip:
		add_child(stats_tooltip)
		stats_tooltip.z_index = 100
		stats_tooltip.visible = false

func _create_stats_tooltip() -> StatsTooltip:
	var tooltip = StatsTooltip.new()
	
	var background = Panel.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.3, 0.3, 0.3, 1.0)
	bg_style.set_corner_radius_all(5)
	background.add_theme_stylebox_override("panel", bg_style)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	tooltip.add_child(background)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 15
	vbox.offset_top = 15
	vbox.offset_right = -15
	vbox.offset_bottom = -15
	tooltip.add_child(vbox)
	
	var title = Label.new()
	title.name = "TitleLabel"
	title.theme_type_variation = "HeaderMedium"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)
	
	var tooltip_stats_container = VBoxContainer.new()
	tooltip_stats_container.name = "StatsContainer"
	vbox.add_child(tooltip_stats_container)
	
	tooltip.custom_minimum_size = Vector2(250, 0) # Sadece genişlik sabit, yükseklik içeriğe göre
	return tooltip

func _create_helper_label() -> void:
	helper_label = Label.new()
	helper_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	helper_label.modulate = Color(0.7, 0.7, 0.7)
	_update_helper_label()
	
	$MarginContainer/VBoxContainer.add_child(helper_label)
	$MarginContainer/VBoxContainer.move_child(helper_label, $MarginContainer/VBoxContainer.get_child_count() - 2)

func _update_helper_label() -> void:
	if not helper_label:
		return
		
	if tooltips_enabled:
		helper_label.text = "Press [X] to Hide Details"
	else:
		helper_label.text = "Press [X] to Show Details"
