extends CanvasLayer
class_name UpgradeScreen

@onready var upgrade_container: VBoxContainer = $MarginContainer/VBoxContainer/ContentSplit/LeftPanel/UpgradeContainer
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ContentSplit/LeftPanel/ActionsContainer/ContinueButton
@onready var reroll_button: Button = $MarginContainer/VBoxContainer/ContentSplit/LeftPanel/ActionsContainer/RerollButton
@onready var money_label: Label = $MarginContainer/VBoxContainer/Header/MoneyLabel
@onready var stats_container: VBoxContainer = $MarginContainer/VBoxContainer/ContentSplit/RightPanel/StatsContainer

const UIThemeManager = preload("res://autoloads/ui_themes.gd")

signal screen_closed

var available_items: Array = []
var upgrade_buttons: Array[Button] = []
var selected_item_index: int = -1
var selected_button_index: int = 0
var is_on_continue_button: bool = false
var is_on_reroll_button: bool = false

var stats_tooltip: StatsTooltip = null
var hovered_button: Button = null

var is_shop_mode: bool = true

func _ready() -> void:
    # Connect existing buttons from scene
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.focus_entered.connect(_on_continue_focus_entered)
	continue_button.focus_mode = Control.FOCUS_ALL
	
	reroll_button.pressed.connect(_on_reroll_pressed)
	reroll_button.focus_entered.connect(_on_reroll_focus_entered)
	reroll_button.focus_mode = Control.FOCUS_ALL
	
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	setup_stats_tooltip()
	
	call_deferred("_apply_fonts")

func _apply_fonts() -> void:
	await get_tree().process_frame
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(self)

func show_shop(wave: int) -> void:
	is_shop_mode = true
	if not ShopManager.shop_updated.is_connected(_on_shop_updated):
		ShopManager.shop_updated.connect(_on_shop_updated)
	if not ShopManager.reroll_price_updated.is_connected(_on_reroll_price_updated):
		ShopManager.reroll_price_updated.connect(_on_reroll_price_updated)
	if not ShopManager.wallet_updated.is_connected(_on_wallet_updated):
		ShopManager.wallet_updated.connect(_on_wallet_updated)
		
	ShopManager.initialize_shop(wave)
	_update_stats_panel()
	
	visible = true
	get_tree().paused = true
	
	if not upgrade_buttons.is_empty():
		upgrade_buttons[0].grab_focus()

func _update_stats_panel() -> void:
    # Clear existing stats
	for child in stats_container.get_children():
		child.queue_free()
		
	if not is_instance_valid(Global.player):
		return
		
	# Show Player Stats
	var stats_label = Label.new()
	stats_label.text = "Max HP: " + str(Global.player.stats.health) + "\n" + \
	                   "Damage: " + str(Global.player.stats.damage) + "\n" + \
	                   "Speed: " + str(Global.player.stats.speed)
	stats_container.add_child(stats_label)
	
	# Show Weapon List
	var weapons_label = Label.new()
	weapons_label.text = "\nWeapons:"
	stats_container.add_child(weapons_label)
	
	for weapon in Global.player.current_weapons:
		if is_instance_valid(weapon) and weapon.data:
			var w_label = Label.new()
			w_label.text = "- " + weapon.data.item_name
			stats_container.add_child(w_label)


func _on_wallet_updated(amount: int) -> void:
	if money_label:
		money_label.text = "Materials: " + str(amount)

func _on_shop_updated(items: Array) -> void:
	available_items = items
	_rebuild_buttons()
	_update_button_highlight()

func _rebuild_buttons() -> void:
	upgrade_buttons.clear()
	for child in upgrade_container.get_children():
		child.queue_free()
		
	for i in range(available_items.size()):
		var item_data = available_items[i]
		var button = _create_item_button(item_data, i)
		upgrade_container.add_child(button)
		upgrade_buttons.append(button)
	
	_setup_focus_connections()
	
	if has_node("/root/FontManager"):
		var font_mgr = get_node("/root/FontManager")
		font_mgr.apply_fonts_recursive(upgrade_container)

func _create_item_button(item_data: Dictionary, index: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(300, 60)
	button.focus_mode = Control.FOCUS_ALL
	
	var item_name = item_data.get("name", "Unknown")
	var price = item_data.get("price", 0)
	var locked = item_data.get("locked", false)
	
	var text = item_name + "\nPrice: " + str(price)
	if locked:
		text = "[LOCKED] " + text
		
	button.text = text
	
	button.pressed.connect(_on_item_pressed.bind(index))
	button.focus_entered.connect(_on_focus_entered.bind(index))
	button.mouse_entered.connect(_on_mouse_entered.bind(index))
	button.mouse_exited.connect(_on_mouse_exited)
	
	return button

func _on_item_pressed(index: int) -> void:
	if ShopManager.buy_item(index):
		# Success sound?
		pass
	else:
		# Failed sound?
		pass

func _on_reroll_pressed() -> void:
	ShopManager.reroll_shop()

func _on_reroll_price_updated(price: int) -> void:
	if reroll_button:
		reroll_button.text = "Reroll (" + str(price) + ")"

func _setup_focus_connections() -> void:
	# Vertical list navigation for shop items
	for i in range(upgrade_buttons.size()):
		var btn = upgrade_buttons[i]
		if i > 0:
			btn.focus_neighbor_top = upgrade_buttons[i - 1].get_path()
		if i < upgrade_buttons.size() - 1:
			btn.focus_neighbor_bottom = upgrade_buttons[i + 1].get_path()
		else:
			# Last item goes to both buttons below
			btn.focus_neighbor_bottom = reroll_button.get_path()
			
	if not upgrade_buttons.is_empty():
		var last_btn_path = upgrade_buttons.back().get_path()
		reroll_button.focus_neighbor_top = last_btn_path
		continue_button.focus_neighbor_top = last_btn_path
	
	# Actions (Reroll / Go) are side-by-side in HBox
	reroll_button.focus_neighbor_right = continue_button.get_path()
	continue_button.focus_neighbor_left = reroll_button.get_path()
	
	# Horizontal navigation fail-safes
	reroll_button.focus_neighbor_left = reroll_button.get_path()
	continue_button.focus_neighbor_right = continue_button.get_path()
	
	# Vertical navigation fail-safes
	reroll_button.focus_neighbor_bottom = reroll_button.get_path()
	continue_button.focus_neighbor_bottom = continue_button.get_path()

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event.is_action_pressed("ui_focus_next"): # Tab or similar to Toggle Lock?
		# Or generic Lock button
		pass
		
	if event is InputEventJoypadButton:
		# Gamepad X/Square to Lock
		if event.button_index == JOY_BUTTON_X and event.pressed:
			if selected_button_index >= 0 and selected_button_index < available_items.size() and not is_on_continue_button and not is_on_reroll_button:
				ShopManager.toggle_lock(selected_button_index)
				get_viewport().set_input_as_handled()
		
		# Gamepad A/Cross to Select (Explicit handle if ui_accept fails)
		elif event.button_index == JOY_BUTTON_A and event.pressed:
			if is_on_continue_button:
				_on_continue_pressed()
				get_viewport().set_input_as_handled()
			elif is_on_reroll_button:
				_on_reroll_pressed()
				get_viewport().set_input_as_handled()
			elif selected_button_index >= 0 and selected_button_index < available_items.size():
				_on_item_pressed(selected_button_index)
				get_viewport().set_input_as_handled()
		
		# Gamepad Y/Triangle to Go/Continue
		elif event.button_index == JOY_BUTTON_Y and event.pressed:
			if not continue_button.disabled:
				_on_continue_pressed()
				get_viewport().set_input_as_handled()
func _on_focus_entered(index: int) -> void:
	selected_button_index = index
	is_on_continue_button = false
	is_on_reroll_button = false
	_update_button_highlight()
	
	# Show tooltip
	if index < available_items.size():
		var data = available_items[index]
		var button = upgrade_buttons[index]
		if data.item:
			_show_tooltip(data.item, button)

func _on_reroll_focus_entered() -> void:
	is_on_reroll_button = true
	is_on_continue_button = false
	selected_button_index = -1
	_hide_tooltip()
	_update_button_highlight()

func _on_continue_focus_entered() -> void:
	is_on_continue_button = true
	is_on_reroll_button = false
	selected_button_index = -1
	_hide_tooltip()
	_update_button_highlight()

func _update_button_highlight() -> void:
	# Can use UIThemeManager or simple colors
	for i in range(upgrade_buttons.size()):
		var btn = upgrade_buttons[i]
		var data = available_items[i]
		var locked = data.get("locked", false)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2)
		if locked:
			style.bg_color = Color(0.3, 0.3, 0.5) # Blueish for locked
			
		if i == selected_button_index and not is_on_continue_button and not is_on_reroll_button:
			style.border_color = Color.YELLOW
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus", style)

func _show_tooltip(item: ItemBase, button: Button) -> void:
	if stats_tooltip and item:
		var data = StatsTooltip.create_item_stats_data(item)
		if not data.is_empty():
			var pos = button.global_position
			pos.x += button.size.x + 10
			stats_tooltip.show_tooltip(data, pos)

func _hide_tooltip() -> void:
	if stats_tooltip:
		stats_tooltip.hide_tooltip()

func _on_mouse_entered(index: int) -> void:
	_on_focus_entered(index)

func _on_mouse_exited() -> void:
	_hide_tooltip()

func _on_continue_pressed() -> void:
	visible = false
	get_tree().paused = false
	if is_instance_valid(Global.player):
		Global.player.process_mode = Node.PROCESS_MODE_INHERIT
	screen_closed.emit()
	_hide_tooltip()

# Helper for stats tooltip (reused from previous code)
func setup_stats_tooltip() -> void:
	stats_tooltip = _create_stats_tooltip()
	if stats_tooltip:
		get_tree().root.add_child(stats_tooltip)
		stats_tooltip.z_index = 1000

func _create_stats_tooltip() -> StatsTooltip:
	var tooltip = StatsTooltip.new()
	var background = Panel.new()
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	background.add_theme_stylebox_override("panel", bg_style)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	tooltip.add_child(background)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Add margins
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	tooltip.add_child(vbox)
	
	var tooltip_stats_container = VBoxContainer.new()
	tooltip_stats_container.name = "StatsContainer"
	vbox.add_child(tooltip_stats_container)
	
	tooltip.custom_minimum_size = Vector2(300, 300)
	return tooltip
