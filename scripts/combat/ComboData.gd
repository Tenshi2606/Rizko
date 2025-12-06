# res://scripts/combat/ComboData.gd
extends Resource
class_name ComboData

## Resource que define una secuencia de ataques (combo)
## Configurable sin tocar código - todo via inspector

# ============================================
# INFORMACIÓN BÁSICA
# ============================================

@export_group("Basic Info")
## Nombre del combo (para debug)
@export var combo_name: String = "Basic Combo"

## Secuencia de ataques que componen el combo
@export var attacks: Array[AttackData] = []

# ============================================
# TIMING
# ============================================

@export_group("Timing")
## Ventana de tiempo para continuar el combo (segundos)
## Si el jugador no ataca en este tiempo, el combo se resetea
@export var combo_window: float = 0.5

## ¿El combo vuelve al inicio después del último golpe?
## true = combo infinito (1-2-3-1-2-3...)
## false = combo termina después del último golpe
@export var loop_combo: bool = false

# ============================================
# CANCELACIÓN
# ============================================

@export_group("Cancellation")
## ¿Se puede cancelar el combo a dash en cualquier momento?
@export var can_cancel_to_dash: bool = true

## ¿Se puede cancelar el combo a salto en cualquier momento?
@export var can_cancel_to_jump: bool = true

# ============================================
# MÉTODOS HELPER
# ============================================

## Obtener el ataque en el índice especificado
func get_attack(index: int) -> AttackData:
	if index >= 0 and index < attacks.size():
		return attacks[index]
	return null

## Obtener el número total de ataques en el combo
func get_attack_count() -> int:
	return attacks.size()

## Verificar si el combo está completo en el índice dado
func is_combo_complete(index: int) -> bool:
	return index >= attacks.size()

# ============================================
# REQUISITOS DE ARMA
# ============================================

@export_group("Weapon Requirements")
## Armas requeridas para este combo (vacío = cualquier arma)
## Ejemplo: ["scythe"] = combo exclusivo de guadaña
@export var required_weapons: Array[String] = []

## Nivel mínimo de upgrade requerido
@export var min_weapon_level: int = 0

# ============================================
# VALIDACIÓN
# ============================================

## Verifica si este combo puede ser usado con el arma actual
func can_use_with_weapon(weapon: WeaponData) -> bool:
	if not weapon:
		return required_weapons.is_empty()
	
	# Verificar arma específica
	if not required_weapons.is_empty():
		if not weapon.weapon_id in required_weapons:
			return false
	
	# Verificar nivel de upgrade
	# WeaponData siempre tiene upgrade_level (definido en WeaponData.gd)
	if weapon.upgrade_level < min_weapon_level:
		return false
	
	return true
