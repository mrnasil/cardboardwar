extends CanvasLayer

signal touch_move(dir: Vector2)
signal touch_dash

var left_touch_id = -1
var right_touch_id = -1
var start_pos = Vector2.ZERO
var current_pos = Vector2.ZERO

func _ready():
	# Sadece mobil cihazlarda veya touch emülasyonu açıkken çalışsın
	if OS.get_name() != "Android" and OS.get_name() != "iOS" and not DisplayServer.is_touchscreen_available():
		# Geliştirme aşamasında görünür bırakabiliriz veya silebiliriz
		pass

func _input(event):
	if event is InputEventScreenTouch:
		var screen_width = get_viewport().get_visible_rect().size.x
		
		if event.pressed:
			if event.position.x < screen_width / 2.0:
				# Sol taraf: Hareket
				if left_touch_id == -1:
					left_touch_id = event.index
					start_pos = event.position
					current_pos = event.position
			else:
				# Sağ taraf: Dash
				if right_touch_id == -1:
					right_touch_id = event.index
					touch_dash.emit()
					# Tek tık yeterli olduğu için hemen serbest bırakabiliriz 
					# ama release event'ini beklemek daha güvenli/standart.
		else:
			if event.index == left_touch_id:
				left_touch_id = -1
				touch_move.emit(Vector2.ZERO)
			elif event.index == right_touch_id:
				right_touch_id = -1

	elif event is InputEventScreenDrag:
		if event.index == left_touch_id:
			current_pos = event.position
			_update_movement()

func _process(_delta):
	if left_touch_id != -1:
		_update_movement()

func _update_movement():
	var diff = current_pos - start_pos
	var length = diff.length()
	
	if length > 20: # Ölü bölge
		# Normale çekip hareketi gönderiyoruz (full 360 derece hareket)
		# Eğer sadece 8 yöne sınırlamak isterseniz normalleştirip yuvarlayabiliriz
		var dir = diff.normalized()
		touch_move.emit(dir)
	else:
		touch_move.emit(Vector2.ZERO)
