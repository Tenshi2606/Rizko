# res://scripts/combat/AttackData.gd
extends Resource
class_name AttackData

## Resource que define un ataque individual
## Configurable sin tocar código - todo via inspector

enum AttackType { 
	GROUND,    # Ataque en tierra
	AIR,       # Ataque aéreo
	LAUNCHER,  # Lanza enemigos al aire (uppercut)
	POGO,      # Ataque hacia abajo con rebote
	DASH,      # Ataque mientras corre
	CHARGE     # Ataque cargado
}

# ============================================
# INFORMACIÓN BÁSICA
# ============================================

@export_group("Basic Info")
## Nombre del ataque (para debug)
@export var attack_name: String = "Attack"

## Tipo de ataque
@export var attack_type: AttackType = AttackType.GROUND

# ============================================
# DAÑO Y KNOCKBACK
# ============================================

@export_group("Damage")
## Multiplicador de daño (1.0 = daño base del arma)
@export var damage_multiplier: float = 1.0

## Fuerza de knockback (X, Y)
@export var knockback_force: Vector2 = Vector2(200, -100)

## ¿Este ataque lanza enemigos al aire? (para uppercut)
@export var launches_enemy: bool = false

## Fuerza de lanzamiento si launches_enemy = true
@export var launch_force: Vector2 = Vector2(0, -400)

# ============================================
# ANIMACIÓN Y TIMING
# ============================================

@export_group("Animation")
## Nombre de la animación a reproducir
@export var animation_name: String = "attack"

## Duración total del ataque (segundos)
@export var duration: float = 0.3

# ============================================
# HITBOX
# ============================================

@export_group("Hitbox")
## Offset del hitbox desde el player
@export var hitbox_offset: Vector2 = Vector2(30, 0)

## Tamaño del hitbox
@export var hitbox_size: Vector2 = Vector2(40, 40)

# ============================================
# FEEL Y JUICE
# ============================================

@export_group("Feel")
## Duración del freeze frame al golpear
@export var freeze_duration: float = 0.05

## Intensidad del camera shake (0.0 - 1.0)
@export var shake_intensity: float = 0.3

## ¿Puede moverse durante el ataque?
@export var can_move_during: bool = false

## ¿Puede cancelar a salto?
@export var can_cancel_to_jump: bool = false

## ¿Puede cancelar a dash?
@export var can_cancel_to_dash: bool = false

# ============================================
# EFECTOS ESPECIALES
# ============================================

@export_group("Special Effects")
## ¿Rebota sobre enemigos? (para pogo)
@export var bounces_on_hit: bool = false

## Fuerza de rebote si bounces_on_hit = true
@export var bounce_force: float = -400.0

# ============================================
# REQUISITOS DE ARMA Y UPGRADES
# ============================================

@export_group("Weapon Requirements")
## Armas requeridas para este ataque (vacío = cualquier arma)
## Ejemplo: ["scythe"] = solo funciona con guadaña
@export var required_weapons: Array[String] = []

## Nivel mínimo de upgrade del arma requerido (0 = sin requisito)
## Ejemplo: 2 = requiere arma nivel 2+
@export var min_weapon_level: int = 0

## ¿Este ataque solo funciona con armas melee?
@export var melee_only: bool = false

## ¿Este ataque solo funciona con armas ranged?
@export var ranged_only: bool = false

# ============================================
# MÉTODOS HELPER
# ============================================

## Verifica si este ataque puede ser usado con el arma actual
func can_use_with_weapon(weapon: WeaponData) -> bool:
	if not weapon:
		return required_weapons.is_empty()
	
	# Verificar tipo de arma
	if melee_only and weapon.weapon_type != WeaponData.WeaponType.MELEE:
		return false
	if ranged_only and weapon.weapon_type != WeaponData.WeaponType.RANGED:
		return false
	
	# Verificar arma específica
	if not required_weapons.is_empty():
		if not weapon.weapon_id in required_weapons:
			return false
	
	# Verificar nivel de upgrade
	# WeaponData siempre tiene upgrade_level (definido en WeaponData.gd)
	if weapon.upgrade_level < min_weapon_level:
		return false
	
	return true
