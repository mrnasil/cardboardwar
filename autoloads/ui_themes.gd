extends Object

# Steam-like UI Theme Colors

# Backgrounds
# Backgrounds
const COLOR_BACKGROUND_MAIN = Color(0.05, 0.05, 0.05, 1.0) # Noir Black
const COLOR_BACKGROUND_PANEL = Color(0.1, 0.1, 0.1, 1.0) # Dark Gray
const COLOR_BACKGROUND_OVERLAY = Color(0.0, 0.0, 0.0, 0.9) # Deep Black Overlay

# Buttons (Noir Style)
const COLOR_BUTTON_NORMAL = Color(0.1, 0.1, 0.1, 1.0) # Dark Gray
const COLOR_BUTTON_HOVER = Color(0.8, 0.8, 0.8, 1.0) # Light Gray/White
const COLOR_BUTTON_PRESSED = Color(0.0, 0.0, 0.0, 1.0) # Black
const COLOR_BUTTON_DISABLED = Color(0.05, 0.05, 0.05, 0.5)

# Selection & Focus
const COLOR_SELECTION_ACTIVE = Color(0.5, 0.5, 0.5, 1.0) # Gray
const COLOR_FOCUS_BORDER = Color(1.0, 1.0, 1.0, 1.0) # White Focus

# Text
const COLOR_TEXT_PRIMARY = Color(1.0, 1.0, 1.0, 1.0) # White
const COLOR_TEXT_SECONDARY = Color(0.7, 0.7, 0.7, 1.0) # Light Gray

# Helper for Button Styles
static func create_stylebox(bg_color: Color, border_color: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 4) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	return style

static func apply_theme_to_button(button: Button) -> void:
	if not button: return
	
	button.add_theme_stylebox_override("normal", create_stylebox(COLOR_BUTTON_NORMAL))
	button.add_theme_stylebox_override("hover", create_stylebox(COLOR_BUTTON_HOVER))
	button.add_theme_stylebox_override("pressed", create_stylebox(COLOR_BUTTON_PRESSED))
	button.add_theme_stylebox_override("disabled", create_stylebox(COLOR_BUTTON_DISABLED))
	
	# Focus style (Border only usually, or modified normal)
	var focus_style = create_stylebox(COLOR_BUTTON_NORMAL, COLOR_FOCUS_BORDER, 2)
	button.add_theme_stylebox_override("focus", focus_style)
	
	button.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)

static func create_selection_indicator() -> Control:
	var indicator = Control.new()
	indicator.name = "SelectionIndicator"
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Circle
	var circle = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(20) # Round
	circle.add_theme_stylebox_override("panel", style)
	circle.custom_minimum_size = Vector2(18, 18)
	circle.size = Vector2(18, 18)
	# Position inside the button to avoid clipping
	circle.position = Vector2(4, 4)
	indicator.add_child(circle)
	
	# Tick (Drawing with Line2D for better compatibility)
	var tick = Line2D.new()
	tick.points = PackedVector2Array([
		Vector2(4, 9), # Start
		Vector2(8, 13), # Bottom
		Vector2(14, 5) # Top right
	])
	tick.width = 2.0
	tick.default_color = Color.BLACK
	tick.begin_cap_mode = Line2D.LINE_CAP_ROUND
	tick.end_cap_mode = Line2D.LINE_CAP_ROUND
	tick.joint_mode = Line2D.LINE_JOINT_ROUND
	tick.antialiased = true
	circle.add_child(tick)
	
	return indicator
