extends Resource
class_name WeaponData

enum WeaponType { MELEE, RANGED, AREA }
enum BreakableType { NONE, WOOD, STONE, METAL_LIGHT, METAL_HEAVY, ICE, CRYSTAL }

@export var weapon_id: String = ""
@export var weapon_name: String = "Arma"
@export var description: String = "Una arma misteriosa"
@export var icon: Texture2D = null

@export_group("Stats Base")
@export var weapon_type: WeaponType = WeaponType.MELEE
@export var base_damage: float = 10.0
@export var attack_speed_multiplier: float = 1.0
@export var attack_range: float = 50.0
@export var knockback_force: Vector2 = Vector2(200, -150)

@export_group("Proyectiles")
@export var has_projectile: bool = false
@export var projectile_scene: PackedScene = null
@export var projectile_speed: float = 300.0
@export var fire_rate: float = 0.5  # Cooldown entre disparos
@export var burst_count: int = 1  # Cantidad de balas por ráfaga
@export var burst_delay: float = 0.1  # Delay entre balas de la ráfaga
@export var projectile_piercing: bool = false

@export_group("Área de Efecto")
@export var has_area_damage: bool = false
@export var area_radius: float = 0.0
@export var area_damage_per_sec: float = 0.0
@export var area_duration: float = 0.0

@export_group("Efectos Especiales")
@export var has_dot: bool = false  # Damage Over Time (quemaduras)
@export var dot_damage: float = 0.0
@export var dot_duration: float = 0.0
@export var has_stun: bool = false
@export var stun_duration: float = 0.0

@export_group("Bonuses")
@export var crit_chance_bonus: float = 0.0
@export var crit_multiplier_bonus: float = 0.0
@export var lifesteal_bonus: int = 0

@export_group("Upgrade System")
## Nivel de upgrade actual del arma (0 = base, 1+ = mejorado)
@export var upgrade_level: int = 0

## Nivel máximo de upgrade posible
@export var max_upgrade_level: int = 3

## Bonificación de daño por nivel de upgrade (%)
@export var damage_per_upgrade: float = 10.0

## ¿Esta arma puede ser mejorada?
@export var can_be_upgraded: bool = true

@export_group("Obstáculos")
@export var can_break: BreakableType = BreakableType.NONE

@export_group("Animaciones")
@export var attack_animation: String = "attack"
@export var attack_up_animation: String = "attack_up"
@export var attack_down_animation: String = "attack_down"

@export_group("Efectos Visuales")
@export var muzzle_flash: PackedScene = null
@export var hand_sprite: String = ""  # 🆕 Sprite de las manos transformadas

func get_effective_damage(base: float = 0.0) -> float:
	return base_damage + base

func get_attack_duration() -> float:
	return 0.3 / attack_speed_multiplier
