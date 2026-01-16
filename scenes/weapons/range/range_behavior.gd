extends WeaponBehavior
class_name RangeBehavior

func execute_attack() -> void:
	if not weapon or not is_instance_valid(weapon):
		push_error("RangeBehavior: weapon null veya geçersiz!")
		return
	
	if not weapon.data or not weapon.data.stats:
		push_error("RangeBehavior: weapon.data veya weapon.data.stats null!")
		return
	
	weapon.is_attacking = true
	
	# Projectile spawn et
	if not weapon.data.stats.projectile_scene:
		push_error("Range weapon için projectile_scene tanımlı değil!")
		weapon.is_attacking = false
		return
	
	var projectile = weapon.data.stats.projectile_scene.instantiate()
	if not projectile:
		weapon.is_attacking = false
		return
	
	# Projectile'ı weapon pozisyonuna ekle
	var scene = weapon.get_tree().current_scene
	if not scene:
		weapon.is_attacking = false
		return
	
	scene.add_child(projectile)
	projectile.global_position = weapon.global_position
	
	# Projectile'ın yönünü hedefe doğru ayarla
	var direction = Vector2.ZERO
	if weapon.closest_target and is_instance_valid(weapon.closest_target):
		direction = weapon.global_position.direction_to(weapon.closest_target.global_position)
	else:
		# Hedef yoksa weapon'ın rotation'ına göre
		direction = Vector2.RIGHT.rotated(weapon.rotation)
	
	# Projectile'a hasar ve yön bilgisini ver
	if projectile.has_method("setup"):
		var damage = get_damage()
		var speed = weapon.data.stats.projectile_speed
		projectile.setup(damage, direction, speed, critical, weapon)
	
	# Kısa bir süre sonra attack durumunu sıfırla
	weapon.is_attacking = false
	critical = false
