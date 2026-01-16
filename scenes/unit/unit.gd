extends Node2D
class_name Unit

@export var stats: UnitStats

@onready var visuals: Node2D = $Visuals
@onready var sprite: Sprite2D = $Visuals/Sprite
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var health_component: HealthComponent = $HealthComponent
@onready var flash_timer: Timer = $FlashTimer


func _ready() -> void:
	health_component.setup(stats)

func set_flash_material() -> void:
	sprite.material = Global.FLASH_MATERIAL
	flash_timer.start()

func _on_hurtbox_component_on_damaged(hitbox: HitboxComponent) -> void:
	if health_component.current_health <= 0:
		return
	
	# Dodge kontrolü (sadece player için)
	var dodged = false
	if self is Player and Global.player.primary_stats:
		var dodge_chance = Global.player.primary_stats.get_dodge_chance()
		dodged = Global.get_chance_sucess(dodge_chance)
		if dodged:
			Global.on_create_block_text.emit(self) # Dodge için de block text göster
			return
	
	# Block kontrolü (armor/block chance)
	var blocked := Global.get_chance_sucess(stats.block_chance / 100)
	if blocked:
		Global.on_create_block_text.emit(self)
		return
	
	set_flash_material()
	
	# Hasar hesaplama
	var final_damage = hitbox.damage
	
	# Armor damage reduction (sadece player için)
	if self is Player and Global.player.primary_stats:
		var armor_reduction = Global.player.primary_stats.get_armor_damage_reduction()
		if armor_reduction > 0.0:
			# Armor hasarı azaltır
			final_damage = final_damage * (1.0 - armor_reduction)
		elif armor_reduction < 0.0:
			# Negatif armor hasarı artırır
			final_damage = final_damage * (1.0 + abs(armor_reduction))
	
	# Minimum damage 1
	final_damage = max(1.0, final_damage)
	
	health_component.take_damage(final_damage)
	Global.on_create_damage_text.emit(self, hitbox)
	
	# Hasarı raporla
	if hitbox.source is Weapon:
		var weapon = hitbox.source as Weapon
		var player = weapon.get_parent() as Player
		if player:
			player.record_damage(final_damage, weapon)
	elif hitbox.source is Player:
		var player = hitbox.source as Player
		player.record_damage(final_damage)


func _on_flash_timer_timeout() -> void:
	sprite.material = null
