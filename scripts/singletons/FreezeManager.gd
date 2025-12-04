# res://scripts/singletons/FreezeManager.gd
extends Node

## ============================================
## FREEZE MANAGER - SINGLETON
## ============================================
## Centraliza todos los efectos de freeze del juego
## Controla Engine.time_scale de forma segura

# ============================================
# CONSTANTES - DURACIONES
# ============================================

## Freeze al golpear enemigo (normal)
const HIT_FREEZE_NORMAL: float = 0.0425  # 42.5ms

## Freeze al golpear enemigo (crítico)
const HIT_FREEZE_CRITICAL: float = 0.1275  # 127.5ms

## Freeze al recibir daño
const DAMAGE_FREEZE: float = 0.2  # 200ms

# ============================================
# CONSTANTES - INTENSIDADES
# ============================================

## Pausa total (time_scale = 0.0)
const FREEZE_FULL: float = 0.0

## Slow motion leve (time_scale = 0.7)
const FREEZE_SLIGHT: float = 0.7

## Slow motion medio (time_scale = 0.5)
const FREEZE_MEDIUM: float = 0.5

## Slow motion fuerte (time_scale = 0.3)
const FREEZE_SLOW: float = 0.3

# ============================================
# VARIABLES INTERNAS
# ============================================

## Si hay un freeze activo
var _is_frozen: bool = false

## Intensidad actual del freeze (time_scale)
var _current_intensity: float = 1.0

# ============================================
# MÉTODOS PÚBLICOS
# ============================================

## Aplica un efecto de freeze
## @param duration: Duración del freeze en segundos
## @param intensity: Intensidad (0.0 = pausa total, 1.0 = velocidad normal)
func apply_freeze(duration: float, intensity: float = FREEZE_FULL) -> void:
	if duration <= 0:
		return
	
	# Si ya hay un freeze activo, usar el más intenso
	if _is_frozen and intensity < _current_intensity:
		# El nuevo freeze es más intenso, reemplazar
		_current_intensity = intensity
		Engine.time_scale = intensity
		_start_freeze_timer(duration)
		print("🧊 Freeze actualizado: %.3fs @ %.1f%%" % [duration, intensity * 100])
	elif not _is_frozen:
		# Activar nuevo freeze
		_current_intensity = intensity
		_is_frozen = true
		Engine.time_scale = intensity
		_start_freeze_timer(duration)
		print("🧊 Freeze activado: %.3fs @ %.1f%%" % [duration, intensity * 100])

## Cancela el freeze actual inmediatamente
func cancel_freeze() -> void:
	if _is_frozen:
		_end_freeze()

## Verifica si hay un freeze activo
func is_frozen() -> bool:
	return _is_frozen

## Obtiene el time_scale actual
func get_current_time_scale() -> float:
	return Engine.time_scale

# ============================================
# MÉTODOS HELPER - FREEZES PREDEFINIDOS
# ============================================

## Aplica freeze de golpe normal
func apply_hit_freeze_normal() -> void:
	apply_freeze(HIT_FREEZE_NORMAL, FREEZE_FULL)

## Aplica freeze de golpe crítico
func apply_hit_freeze_critical() -> void:
	apply_freeze(HIT_FREEZE_CRITICAL, FREEZE_FULL)

## Aplica freeze de daño recibido
func apply_damage_freeze() -> void:
	apply_freeze(DAMAGE_FREEZE, FREEZE_FULL)

# ============================================
# MÉTODOS INTERNOS
# ============================================

func _start_freeze_timer(duration: float) -> void:
	# Usar create_timer con process_always = true (no afectado por time_scale)
	await get_tree().create_timer(duration, true, false, true).timeout
	_end_freeze()

func _end_freeze() -> void:
	if _is_frozen:
		_current_intensity = 1.0
		_is_frozen = false
		Engine.time_scale = 1.0
		print("✅ Freeze terminado")

# ============================================
# READY
# ============================================

func _ready() -> void:
	# Asegurar que time_scale esté en 1.0 al inicio
	Engine.time_scale = 1.0
	print("✅ FreezeManager inicializado")
