extends ItemBase
class_name ItemWeapon

enum WeaponType{
	MELEE,
	RANGE
}

enum WeaponClass{
	ASSASSIN,  # Hızlı, kritik odaklı
	TANK,      # Savunma odaklı
	WARRIOR,   # Dengeli savaşçı
	MAGE,      # Elemental hasar
	RANGER     # Uzak menzil
}

@export var type:WeaponType
@export var weapon_class: WeaponClass = WeaponClass.WARRIOR  # Varsayılan class
@export var scene:PackedScene
@export var stats: WeaponStats
@export var upgrade_to:ItemWeapon
@export var weapon_level: int = 1  # Silah seviyesi (1-6 arası)
