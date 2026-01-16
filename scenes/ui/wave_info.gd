extends Control
class_name WaveInfo

@onready var wave_label: Label = $VBoxContainer/WaveLabel
@onready var timer_label: Label = $VBoxContainer/TimerLabel
@onready var enemies_label: Label = $VBoxContainer/EnemiesLabel

var wave_manager: Node = null

func _ready() -> void:
	# WaveManager'ı bul
	if has_node("/root/WaveManager"):
		wave_manager = get_node("/root/WaveManager")
		# Sinyallere bağlan
		wave_manager.wave_started.connect(_on_wave_started)
		wave_manager.wave_completed.connect(_on_wave_completed)
		wave_manager.wave_timer_updated.connect(_on_timer_updated)
		wave_manager.enemy_count_updated.connect(_on_enemy_count_updated)
	else:
		push_error("WaveInfo: WaveManager bulunamadı!")
		visible = false
		return
	
	# İlk güncelleme
	update_display()

func _process(_delta: float) -> void:
	if wave_manager:
		update_display()

func update_display() -> void:
	if not wave_manager:
		return
	
	var wave_num = wave_manager.get_current_wave()
	var timer = wave_manager.get_wave_timer()
	var enemies = wave_manager.get_enemies_alive()
	var state = wave_manager.get_wave_state()
	
	# Wave numarası
	if wave_num > 0:
		wave_label.text = "%s %d" % [tr("WAVE_INFO_WAVE"), wave_num]
	else:
		wave_label.text = "%s -" % tr("WAVE_INFO_WAVE")
	
	# Timer
	if state == 1: # WaveState.ACTIVE = 1
		var minutes = int(timer / 60)
		var seconds = int(timer) % 60
		timer_label.text = "%s %02d:%02d" % [tr("WAVE_INFO_TIME"), minutes, seconds]
	else:
		timer_label.text = "%s --:--" % tr("WAVE_INFO_TIME")
	
	# Kalan düşmanlar
	enemies_label.text = "%s %d" % [tr("WAVE_INFO_ENEMIES"), enemies]

func _on_wave_started(_wave_number: int) -> void:
	update_display()

func _on_wave_completed(_wave_number: int) -> void:
	update_display()

func _on_timer_updated(_time_remaining: float) -> void:
	update_display()

func _on_enemy_count_updated(_count: int) -> void:
	update_display()
