extends Unit
class_name Player

const PrimaryStatsResource = preload("res://resources/unit/primary_stats.gd")

@export var dash_duration := 0.5
@export var dash_speed_multi := 2.5
@export var dash_cooldown := 0.5

@onready var dash_cooldown_timer: Timer = $DashCooldwnTimer
@onready var dash_timer: Timer = $DashTimer
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var trail: Trail = %Trail
@onready var weapon_container: WeaponContainer = $WeaponContainer
@onready var dash_smoke: CPUParticles2D = %DashSmoke

var current_weapons: Array[Weapon] = []

var move_dir: Vector2
var is_dashing := false
var dash_available := false

# Level ve Experience sistemi
signal on_level_up(new_level: int)
signal on_experience_gained(current_exp: int, exp_needed: int)
signal on_cardboard_changed(cardboard: int)
signal on_damage_dealt(total_damage: float, weapon_damage: float, weapon: Weapon)

var level: int = 1
var experience: int = 0
var experience_needed: int = 10 # İlk level için gerekli exp
var cardboard: int = 0
var total_damage_dealt: float = 0.0

# Level başına stat artışları
@export var health_per_level: float = 5.0
@export var damage_per_level: float = 1.0
@export var speed_per_level: float = 10.0

# Class buff sistemi
var class_bonuses: Dictionary = {} # Class -> bonus multiplier'ları
var base_stats: Dictionary = {} # Base stat değerleri (class bonusları uygulanmadan önce)

# Primary Stats sistemi
var primary_stats: PrimaryStats = PrimaryStats.new()
var hp_regeneration_timer: float = 0.0
var life_steal_cooldown_timer: float = 0.0
const LIFE_STEAL_COOLDOWN: float = 0.1 # Life steal max 10HP/second (0.1s cooldown)
var life_steal_healed_this_second: float = 0.0
var life_steal_second_timer: float = 0.0

func _ready() -> void:
	super._ready()
	dash_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	
	# Level sistemi başlangıç
	level = 1
	experience = 0
	experience_needed = get_experience_needed_for_level(level)
	cardboard = 0
	
	# Base stats'ları initialize et (class bonusları uygulanmadan önce)
	if stats:
		base_stats["health"] = stats.health
		base_stats["damage"] = stats.damage
		base_stats["speed"] = stats.speed
		base_stats["armor"] = stats.block_chance
	else:
		push_error("Player: Stats resource is NULL in _ready!")
		
		# Primary stats'ı initialize et
		primary_stats.max_hp = stats.health
		primary_stats.speed = 0.0 # Base speed zaten stats.speed'de
		
		# Health component'i primary stats'a göre güncelle
		update_health_from_primary_stats()
	
	# Default weapon kaldırıldı - sadece seçilen weapon eklenecek
	#add_weapon(preload("uid://d1go7qyiyhwib"))

func _process(delta: float) -> void:
	# Pause durumunda veya upgrade ekranı açıkken hareket etme
	if get_tree().paused:
		# Pause durumunda animasyonu da durdur
		if anim_player and anim_player.is_playing():
			anim_player.stop()
		return
	
	# Upgrade ekranı kontrolü
	var upgrade_screen = get_tree().root.get_node_or_null("UpgradeScreen")
	if upgrade_screen and upgrade_screen.visible:
		# Upgrade ekranı açıkken animasyonu durdur
		if anim_player and anim_player.is_playing():
			anim_player.stop()
		return
	
	# Primary stats sistemlerini güncelle
	update_hp_regeneration(delta)
	update_life_steal_timer(delta)
	
	if not stats:
		return
		
	# Speed'i primary stats'a göre güncelle
	var speed_multiplier = primary_stats.get_speed_multiplier()
	var effective_speed = stats.speed * speed_multiplier
	
	# Hareket girişi (Önce klavye/gamepad, sonra dokunmatik)
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var arena = get_parent()
	
	if input_dir != Vector2.ZERO:
		move_dir = input_dir
	else:
		if arena:
			move_dir = arena.touch_move_dir
		else:
			move_dir = Vector2.ZERO
	
	var current_velocity: Vector2 = move_dir * effective_speed
	if is_dashing:
		current_velocity *= dash_speed_multi
	
	position += current_velocity * delta
	
	# Harita sınırlarına göre sınırla (Arena'dan al)
	if arena:
		var bounds = arena.get_map_bounds()
		# Perspektif paylı sınırlandırma (Yamuk şekle göre)
		var top_w = bounds.size.x * 0.82
		var bot_w = bounds.size.x * 1.18
		var cx = bounds.get_center().x
		
		# Y eksenindeki konumuna göre o andaki genişliği hesapla (lerp)
		var progress = (position.y - bounds.position.y) / bounds.size.y
		var current_w = lerp(top_w, bot_w, clamp(progress, 0.0, 1.0))
		
		var margin = 60.0
		position.x = clamp(position.x, cx - current_w / 2 + margin, cx + current_w / 2 - margin)
		position.y = clamp(position.y, bounds.position.y + margin, bounds.end.y - margin)
	else:
		# Fallback
		position.x = clamp(position.x, -1600, 1600)
		position.y = clamp(position.y, -1600, 1600)
	
	if can_dash():
		start_dash()
	
	update_animations()
	update_rotation()

func add_weapon(data: ItemWeapon) -> void:
	# Önce birleştirme kontrolü yap
	if try_merge_weapon(data):
		return # Birleştirme başarılı oldu, yeni weapon ekleme
	
	# Birleştirme yoksa normal ekleme
	var weapon := data.scene.instantiate() as Weapon
	add_child(weapon)
	
	weapon.setup_weapon(data)
	current_weapons.append(weapon)
	weapon_container.update_weapons_position(current_weapons)
	
	# Class bonuslarını güncelle
	update_class_bonuses()

func try_merge_weapon(new_weapon_data: ItemWeapon) -> bool:
	# Aynı seviye ve aynı isim weapon var mı kontrol et
	var same_weapon: Weapon = null
	
	for weapon in current_weapons:
		if not is_instance_valid(weapon) or not weapon.data:
			continue
		
		# Aynı seviye ve aynı isim mi kontrol et (item_name ile)
		if weapon.data.weapon_level == new_weapon_data.weapon_level and \
		   weapon.data.item_name == new_weapon_data.item_name:
			same_weapon = weapon
			break
	
	# Aynı seviye weapon varsa birleştir
	if same_weapon:
		# Yeni weapon'ı da ekle
		var new_weapon := new_weapon_data.scene.instantiate() as Weapon
		add_child(new_weapon)
		new_weapon.setup_weapon(new_weapon_data)
		current_weapons.append(new_weapon)
		
		# İki weapon'ı birleştir
		merge_weapons(same_weapon, new_weapon)
		return true
	
	return false

func merge_weapons(weapon1: Weapon, weapon2: Weapon) -> void:
	if not is_instance_valid(weapon1) or not is_instance_valid(weapon2):
		return
	
	if not weapon1.data or not weapon2.data:
		return
	
	# Aynı seviye olmalı
	if weapon1.data.weapon_level != weapon2.data.weapon_level:
		return
	
	# Maksimum seviye kontrolü
	if weapon1.data.weapon_level >= 6:
		print("Weapon zaten maksimum seviyede, birleştirilemez")
		return
	
	# Maksimum seviye kontrolü
	if weapon1.data.weapon_level >= 6:
		print("Weapon zaten maksimum seviyede, birleştirilemez")
		return
	
	# Eski weapon'ları sil
	var accumulated_damage = weapon1.total_damage_dealt + weapon2.total_damage_dealt
	weapon1.queue_free()
	weapon2.queue_free()
	current_weapons.erase(weapon1)
	current_weapons.erase(weapon2)
	
	# Yeni seviye weapon oluştur (upgrade_to varsa kullan, yoksa dinamik oluştur)
	var upgraded_data: ItemWeapon
	if weapon1.data.upgrade_to:
		upgraded_data = weapon1.data.upgrade_to.duplicate(true)
	else:
		# Upgrade_to yoksa base weapon'dan dinamik oluştur
		upgraded_data = weapon1.data.duplicate(true)
		# Stats'ı seviyeye göre artır
		if upgraded_data.stats:
			var level_multiplier = 1.0 + (weapon1.data.weapon_level * 0.3) # Her seviyede %30 artış
			upgraded_data.stats = upgraded_data.stats.duplicate(true)
			upgraded_data.stats.damage *= level_multiplier
			upgraded_data.stats.cooldown *= 0.9 # Cooldown azalır
			upgraded_data.stats.max_range *= 1.1 # Menzil artar
	
	upgraded_data.weapon_level = weapon1.data.weapon_level + 1
	
	# İsim güncelle (seviye ekle)
	if upgraded_data.item_name:
		# Base ismi al (seviye bilgisi varsa kaldır)
		var base_name = upgraded_data.item_name.split(" (Seviye")[0]
		# Yeni seviye ile güncelle
		upgraded_data.item_name = base_name + " (Seviye " + str(upgraded_data.weapon_level) + ")"
	
	var new_weapon := upgraded_data.scene.instantiate() as Weapon
	add_child(new_weapon)
	new_weapon.setup_weapon(upgraded_data)
	new_weapon.total_damage_dealt = accumulated_damage
	current_weapons.append(new_weapon)
	
	weapon_container.update_weapons_position(current_weapons)
	
	print("Weapon birleştirildi: ", weapon1.data.item_name, " (Seviye ", weapon1.data.weapon_level, ") -> ", upgraded_data.item_name, " (Seviye ", upgraded_data.weapon_level, ")")
	
	# Class bonuslarını güncelle
	update_class_bonuses()
	
	# Birleştirme sonrası tekrar birleştirme kontrolü yap (3. weapon varsa)
	call_deferred("check_auto_merge")

func check_auto_merge() -> void:
	# Tüm weapon'ları seviye ve isim bazında grupla
	var weapon_groups: Dictionary = {}
	
	for weapon in current_weapons:
		if not is_instance_valid(weapon) or not weapon.data:
			continue
		
		var key = str(weapon.data.weapon_level) + "_" + weapon.data.item_name
		if not weapon_groups.has(key):
			weapon_groups[key] = []
		weapon_groups[key].append(weapon)
	
	# Her grup için 2 veya daha fazla weapon varsa birleştir
	for key in weapon_groups:
		var weapons = weapon_groups[key] as Array
		if weapons.size() >= 2:
			merge_weapons(weapons[0], weapons[1])
			return # Bir seferde bir birleştirme yap

func update_animations() -> void:
	if move_dir.length() > 0:
		anim_player.play("move")
	else:
		anim_player.play("idle")

func update_rotation() -> void:
	if move_dir == Vector2.ZERO:
		return
		
	if move_dir.x >= 0.1:
		visuals.scale = Vector2(0.5, 0.5) # Sağa giderken sağa dön
	else:
		visuals.scale = Vector2(-0.5, 0.5) # Sola giderken sola dön

func start_dash() -> void:
	is_dashing = true
	dash_timer.start()
	trail.start_trail()
	visuals.modulate.a = 0.5
	collision.set_deferred("disabled", true)
	
	# Bulut efekti - dash başladığında arkasında beyaz bulut
	if dash_smoke:
		dash_smoke.global_position = global_position
		# Dash yönüne göre bulut yönünü ayarla
		if move_dir != Vector2.ZERO:
			var dash_angle_rad = move_dir.angle() + PI # Arkaya doğru (radyan)
			dash_smoke.direction = Vector2.from_angle(dash_angle_rad)
		dash_smoke.emitting = true
	
	
func can_dash(ignore_input: bool = false) -> bool:
	return not is_dashing and \
	 dash_cooldown_timer.is_stopped() and \
	 (ignore_input or Input.is_action_just_pressed("dash")) and \
	 move_dir != Vector2.ZERO

# 朝向
func is_facing_right() -> bool:
	return visuals.scale.x == 0.5
	
func _on_dash_timer_timeout() -> void:
	is_dashing = false
	visuals.modulate.a = 1.0
	move_dir = Vector2.ZERO
	collision.set_deferred("disabled", false)
	dash_cooldown_timer.stop()

func record_damage(amount: float, weapon: Weapon = null) -> void:
	total_damage_dealt += amount
	var weapon_dmg = 0.0
	if is_instance_valid(weapon):
		weapon.total_damage_dealt += amount
		weapon_dmg = weapon.total_damage_dealt
	
	on_damage_dealt.emit(total_damage_dealt, weapon_dmg, weapon)

# Level ve Experience fonksiyonları
func get_experience_needed_for_level(lvl: int) -> int:
	# Her level için gerekli exp artışı (Noir Arena tarzı)
	# Level 1: 10, Level 2: 15, Level 3: 22, vb.
	return int(10 + (lvl - 1) * 5 + (lvl - 1) * (lvl - 1) * 0.5)

func add_experience(amount: int) -> void:
	experience += amount
	on_experience_gained.emit(experience, experience_needed)
	
	# Level up kontrolü
	while experience >= experience_needed:
		level_up()

func level_up() -> void:
	experience -= experience_needed
	level += 1
	experience_needed = get_experience_needed_for_level(level)
	
	# Stat artışları (base_stats'a ekle)
	if stats:
		base_stats["health"] += health_per_level
		base_stats["damage"] += damage_per_level
		base_stats["speed"] += speed_per_level
		
		# Primary stats'a da ekle
		if primary_stats:
			primary_stats.max_hp += health_per_level
			# Damage ve speed zaten base_stats'tan geliyor, primary stats'ta sadece modifier olarak kullanılıyor
		
		# Class bonuslarını yeniden uygula (base stats değişti)
		apply_class_bonuses()
		
		# Primary stats efektlerini uygula
		apply_primary_stats_effects()
	
	on_level_up.emit(level)
	on_experience_gained.emit(experience, experience_needed)
	
	print("Level Up! Yeni Level: %d" % level)

var material_bag: int = 0

# Cardboard (Karton) fonksiyonları
func add_cardboard(amount: int) -> void:
	cardboard += amount
	
	# Material Bag Logic: Eğer çantada malzeme varsa, 1 tane de oradan ekle
	if material_bag > 0:
		cardboard += 1
		material_bag -= 1
		
	on_cardboard_changed.emit(cardboard)

func spend_cardboard(amount: int) -> bool:
	if cardboard >= amount:
		cardboard -= amount
		on_cardboard_changed.emit(cardboard)
		return true
	return false

# Class Buff Sistemi
func update_class_bonuses() -> void:
	# Her class için silah sayısını say
	var class_counts: Dictionary = {}
	for weapon in current_weapons:
		if not is_instance_valid(weapon) or not weapon.data:
			continue
		
		var weapon_class = weapon.data.weapon_class
		if not class_counts.has(weapon_class):
			class_counts[weapon_class] = 0
		class_counts[weapon_class] += 1
	
	# Base stats'ları ilk kez kaydet
	if base_stats.is_empty() and stats:
		base_stats["health"] = stats.health
		base_stats["damage"] = stats.damage
		base_stats["speed"] = stats.speed
		base_stats["armor"] = stats.block_chance
		base_stats["crit_chance"] = 0.0 # Base crit chance (weapon stats'tan gelir)
		base_stats["range"] = 0.0 # Base range (weapon stats'tan gelir)
		base_stats["elemental_damage"] = 0.0 # Base elemental damage
		base_stats["dodge"] = 0.0 # Base dodge chance
		base_stats["attack_speed"] = 1.0 # Base attack speed multiplier
	
	# Class bonuslarını hesapla ve uygula
	class_bonuses.clear()
	
	for class_type in class_counts:
		var count = class_counts[class_type]
		if count < 2:
			continue # En az 2 silah gerekli
		
		var bonus_multiplier = 1.0
		var bonus_attack_speed = 0.0
		var bonus_crit_chance = 0.0
		var bonus_range = 0.0
		var bonus_movement_speed = 0.0
		var bonus_hp = 0.0
		var bonus_armor = 0.0
		var bonus_elemental_damage = 0.0
		var bonus_dodge = 0.0
		
		# 2 aynı class silah: +10% damage
		if count >= 2:
			bonus_multiplier = 1.10
		
		# 4 aynı class silah: +20% damage, +5% attack speed
		if count >= 4:
			bonus_multiplier = 1.20
			bonus_attack_speed = 0.05
		
		# 6 aynı class silah: +35% damage, +10% attack speed, özel class bonusu
		if count >= 6:
			bonus_multiplier = 1.35
			bonus_attack_speed = 0.10
			
			# Özel class bonusları
			match class_type:
				ItemWeapon.WeaponClass.TANK:
					bonus_hp = base_stats["health"] * 0.20 # +20% HP
					bonus_armor = base_stats["armor"] * 0.10 # +10% Armor
				ItemWeapon.WeaponClass.WARRIOR:
					bonus_crit_chance = 0.15 # +15% Crit chance
				ItemWeapon.WeaponClass.RANGER:
					bonus_range = 0.20 # +20% Range
					bonus_movement_speed = base_stats["speed"] * 0.10 # +10% movement speed
				ItemWeapon.WeaponClass.MAGE:
					bonus_elemental_damage = 0.25 # +25% Elemental damage
				ItemWeapon.WeaponClass.ASSASSIN:
					bonus_attack_speed += 0.20 # +20% Attack speed (ek olarak)
					bonus_dodge = 0.10 # +10% Dodge
		
		class_bonuses[class_type] = {
			"damage_multiplier": bonus_multiplier,
			"attack_speed": bonus_attack_speed,
			"crit_chance": bonus_crit_chance,
			"range": bonus_range,
			"movement_speed": bonus_movement_speed,
			"hp": bonus_hp,
			"armor": bonus_armor,
			"elemental_damage": bonus_elemental_damage,
			"dodge": bonus_dodge
		}
	
	# Bonusları uygula
	apply_class_bonuses()

func apply_class_bonuses() -> void:
	if not stats or base_stats.is_empty():
		return
	
	# Base stats'ları geri yükle
	stats.health = base_stats["health"]
	stats.damage = base_stats["damage"]
	stats.speed = base_stats["speed"]
	stats.block_chance = base_stats["armor"]
	
	# Class bonuslarını uygula
	var total_damage_multiplier = 1.0
	var total_attack_speed = 0.0
	var total_crit_chance = 0.0
	var _total_range = 0.0
	var total_movement_speed = 0.0
	var total_hp = 0.0
	var total_armor = 0.0
	var _total_elemental_damage = 0.0
	var _total_dodge = 0.0
	
	for class_type in class_bonuses:
		var bonuses = class_bonuses[class_type]
		total_damage_multiplier *= bonuses["damage_multiplier"]
		total_attack_speed += bonuses["attack_speed"]
		total_crit_chance += bonuses["crit_chance"]
		_total_range += bonuses["range"]
		total_movement_speed += bonuses["movement_speed"]
		total_hp += bonuses["hp"]
		total_armor += bonuses["armor"]
		_total_elemental_damage += bonuses["elemental_damage"]
		_total_dodge += bonuses["dodge"]
	
	# Stats'ları güncelle
	stats.damage = base_stats["damage"] * total_damage_multiplier
	stats.speed = base_stats["speed"] + total_movement_speed
	stats.health = base_stats["health"] + total_hp
	stats.block_chance = base_stats["armor"] + total_armor
	
	# Health component'i güncelle
	if health_component:
		var old_max = health_component.max_health
		health_component.max_health = int(stats.health)
		# Mevcut health'i orantılı olarak koru
		if old_max > 0:
			var health_ratio = float(health_component.current_health) / float(old_max)
			health_component.current_health = int(stats.health * health_ratio)
		else:
			health_component.current_health = int(stats.health)
		health_component.on_health_changed.emit(health_component.current_health, health_component.max_health)
	
	# Weapon'lara attack speed ve crit chance bonuslarını uygula
	# Not: Weapon stats'ları için base değerleri saklamak karmaşık olduğundan,
	# bu bonuslar weapon behavior'da veya damage hesaplamasında uygulanabilir
	# Şimdilik sadece player stats'larına odaklanıyoruz
	
	print("Class bonusları uygulandı. Damage: x", total_damage_multiplier, ", Attack Speed: +", total_attack_speed * 100, "%, Crit: +", total_crit_chance * 100, "%")

# Primary Stats Fonksiyonları
func update_health_from_primary_stats() -> void:
	if not health_component or not primary_stats:
		return
	
	# Max HP'yi primary stats'a göre güncelle
	# Negatif max_hp durumunda 1'e eşit davran
	var effective_max_hp = max(1.0, primary_stats.max_hp)
	
	var old_max = health_component.max_health
	health_component.max_health = int(effective_max_hp)
	
	# Mevcut health'i orantılı olarak koru
	if old_max > 0:
		var health_ratio = float(health_component.current_health) / float(old_max)
		health_component.current_health = int(effective_max_hp * health_ratio)
	else:
		health_component.current_health = int(effective_max_hp)
	
	health_component.on_health_changed.emit(health_component.current_health, health_component.max_health)

func update_hp_regeneration(delta: float) -> void:
	if not health_component or not primary_stats:
		return
	
	# HP Regeneration negatifse 0 gibi davran
	if primary_stats.hp_regeneration <= 0.0:
		return
	
	var regen_per_second = primary_stats.get_hp_regeneration_per_second()
	var regen_amount = regen_per_second * delta
	
	if regen_amount > 0.0 and health_component.current_health < health_component.max_health:
		health_component.heal(regen_amount)

func update_life_steal_timer(delta: float) -> void:
	life_steal_cooldown_timer = max(0.0, life_steal_cooldown_timer - delta)
	life_steal_second_timer += delta
	
	# Her saniye life steal sayacını sıfırla
	if life_steal_second_timer >= 1.0:
		life_steal_healed_this_second = 0.0
		life_steal_second_timer = 0.0

func try_life_steal() -> bool:
	if not health_component or not primary_stats:
		return false
	
	# Life steal negatifse minimum 0
	if primary_stats.life_steal <= 0.0:
		return false
	
	# Cooldown kontrolü (max 10HP/second)
	if life_steal_cooldown_timer > 0.0:
		return false
	
	# Saniye başına max 10HP kontrolü
	if life_steal_healed_this_second >= 10.0:
		return false
	
	# Life steal şansı kontrolü
	var life_steal_chance = primary_stats.get_life_steal_chance()
	if not Global.get_chance_sucess(life_steal_chance):
		return false
	
	# Life steal uygula
	life_steal_cooldown_timer = LIFE_STEAL_COOLDOWN
	life_steal_healed_this_second += 1.0
	health_component.heal(1.0)
	return true

# Primary stat modifier fonksiyonları
func modify_primary_stat(stat_name: String, value: float) -> void:
	primary_stats.add_stat(stat_name, value)
	apply_primary_stats_effects()

func set_primary_stat(stat_name: String, value: float) -> void:
	primary_stats.set_stat(stat_name, value)
	apply_primary_stats_effects()

func apply_primary_stats_effects() -> void:
	# Max HP'yi güncelle
	update_health_from_primary_stats()
	
	# Speed zaten _process'te uygulanıyor
	# Weapon range'lerini güncelle
	update_all_weapon_ranges()
	
	# Diğer statlar weapon damage hesaplamalarında kullanılacak

func update_all_weapon_ranges() -> void:
	for weapon in current_weapons:
		if is_instance_valid(weapon) and weapon.has_method("update_weapon_range"):
			weapon.update_weapon_range()
