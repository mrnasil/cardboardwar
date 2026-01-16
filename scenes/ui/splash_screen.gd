extends Control

@onready var logo: TextureRect = $Logo

func _ready() -> void:
	# SVG runtime rasterizasyonu kalitesiz olduğu için PNG kullanıyoruz
	var tex = load("res://assets/sprites/clicker-games.png")
	
	if tex:
		logo.texture = tex
		# Ensure smooth scaling
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	
	# Wait for layout to calculate correct size
	await get_tree().process_frame
	
	# Explicitly start invisible AND small (comes from "behind")
	logo.modulate.a = 0.0
	logo.scale = Vector2(0.2, 0.2)
	
	# Set pivot to center for correct scaling
	logo.pivot_offset = logo.size / 2
	
	var tween = create_tween()
	
	# Fade In + Scale Up (Parallel)
	tween.set_parallel(true)
	tween.tween_property(logo, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo, "scale", Vector2(0.5, 0.5), 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)
	
	# Wait
	tween.tween_interval(1.5)
	
	# Fade Out (Slower)
	tween.tween_property(logo, "modulate:a", 0.0, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	# Safety Buffer (Longer)
	tween.tween_interval(0.5)
	
	# Change Scene
	tween.tween_callback(_change_to_main_menu)

func _change_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

var is_skipping = false

func _input(event: InputEvent) -> void:
	if is_skipping:
		return
		
	var should_skip = false
	
	# Klavye: Space
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_SPACE:
			should_skip = true
			
	# Fare: Sol tık
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			should_skip = true
			
	# Gamepad: A butonu (Genelde index 0)
	elif event is InputEventJoypadButton:
		if event.pressed and event.button_index == JOY_BUTTON_A:
			should_skip = true
			
	# Android/Dokunmatik: Herhangi bir dokunuş
	elif event is InputEventScreenTouch:
		if event.pressed:
			should_skip = true
			
	if should_skip:
		is_skipping = true
		_change_to_main_menu()
