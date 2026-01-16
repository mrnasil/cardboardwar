extends Camera2D
class_name ArenaCamera

func _ready() -> void:
	# Kamerayı aktif yap ve yumuşak takibi aç
	enabled = true
	position_smoothing_enabled = true
	position_smoothing_speed = 10.0

func _process(_delta: float) -> void:
	if is_instance_valid(Global.player):
		# Karakterin tam konumunu takip et
		global_position = Global.player.global_position
