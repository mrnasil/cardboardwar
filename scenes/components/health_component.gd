extends Node
class_name HealthComponent

signal on_unit_hit
signal on_unit_died
signal on_health_changed(current:int,max:int)

var max_health: int = 1
var current_health: int = 1

func setup(stats:UnitStats) -> void:
	max_health = int(stats.health)
	current_health = max_health
	on_health_changed.emit(current_health,max_health)

func take_damage(value:float) -> void:
	if current_health <= 0:
		return
		
	current_health -= int(value)
	current_health = max(current_health, 0)
	
	on_unit_hit.emit()
	on_health_changed.emit(current_health,max_health)
	
	if current_health <= 0:
		current_health = 0
		on_unit_died.emit()
		die()
		
func heal(amount:float):
	if current_health <= 0:
		return
	current_health += int(amount)
	current_health = min(current_health, max_health)
	on_health_changed.emit(current_health, max_health)

func die() -> void:
	owner.queue_free()
		
	
