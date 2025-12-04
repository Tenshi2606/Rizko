# res://scripts/player/components/MovementComponent.gd
class_name MovementComponent
extends Node

## ============================================
## MOVEMENT COMPONENT
## ============================================
## Centraliza toda la física y movimiento del player
## Maneja: knockback, aceleración, fricción, gravedad

# ============================================
# REFERENCIAS
# ============================================

@onready var player: CharacterBody2D = get_parent()

# ============================================
# CONFIGURACIÓN
# ============================================

## Multiplicador de knockback (ajustable)
@export var knockback_multiplier: float = 1.2  # Aumentado 20%

## Límite vertical de knockback (evita que vuele muy alto)
@export var knockback_vertical_limit: float = 100.0

# ============================================
# KNOCKBACK
# ============================================

## Aplica knockback al player
## @param knockback: Fuerza del knockback (Vector2)
## @param source_pos: Posición de origen del daño (para calcular dirección)
func apply_knockback(knockback: Vector2, source_pos: Vector2) -> void:
	if knockback == Vector2.ZERO:
		return
	
	# Calcular dirección del knockback
	var dir = (player.global_position - source_pos)
	var dir_length = dir.length()
	
	# 🆕 VALIDACIÓN: Evitar NaN cuando están en la misma posición
	if dir_length < 0.01 or is_nan(dir_length):
		dir = Vector2(-0.707, -0.707)  # Diagonal arriba-izquierda por defecto
		print("⚠️ Dirección inválida, usando por defecto")
	else:
		dir = dir.normalized()
	
	# Validación adicional de NaN
	if is_nan(dir.x) or is_nan(dir.y):
		dir = Vector2(-0.707, -0.707)
		print("⚠️ NaN en dirección, usando vector seguro")
	
	# Aplicar knockback
	player.velocity.x = dir.x * abs(knockback.x) * knockback_multiplier
	player.velocity.y = dir.y * abs(knockback.y) * knockback_multiplier
	
	# Limitar knockback vertical para evitar que vuele muy alto
	player.velocity.y = clamp(player.velocity.y, -knockback_vertical_limit, knockback_vertical_limit)
	
	# Debug
	print("🔨 Knockback aplicado:")
	print("  Player pos: ", player.global_position)
	print("  Enemy pos: ", source_pos)
	print("  Direction: ", dir)
	print("  Velocity: ", player.velocity)

# ============================================
# MOVIMIENTO HORIZONTAL
# ============================================

## Aplica movimiento horizontal con aceleración/desaceleración
## @param delta: Delta time
## @param input_dir: Dirección del input (-1, 0, 1)
## @param speed: Velocidad objetivo
func apply_horizontal_movement(delta: float, input_dir: float, speed: float) -> void:
	if not player:
		return
	
	var acceleration = player.acceleration if player.has("acceleration") else 1000.0
	
	if input_dir != 0:
		# Acelerar
		var target_speed = input_dir * speed
		player.velocity.x = move_toward(player.velocity.x, target_speed, acceleration * delta)
	else:
		# Desacelerar (fricción)
		apply_friction(delta)

# ============================================
# FRICCIÓN
# ============================================

## Aplica fricción para desacelerar al player
## @param delta: Delta time
func apply_friction(delta: float) -> void:
	if not player:
		return
	
	var friction = player.friction if player.has("friction") else 800.0
	player.velocity.x = move_toward(player.velocity.x, 0, friction * delta)

# ============================================
# GRAVEDAD
# ============================================

## Aplica gravedad al player
## @param delta: Delta time
func apply_gravity(delta: float) -> void:
	if not player:
		return
	
	if not player.is_on_floor():
		var gravity = player.gravity if player.has("gravity") else 980.0
		player.velocity.y += gravity * delta

# ============================================
# MOVE AND SLIDE
# ============================================

## Mueve al player de forma segura
func move_and_slide_safe() -> void:
	if not player:
		return
	
	player.move_and_slide()

# ============================================
# UTILIDADES
# ============================================

## Detiene todo el movimiento del player
func stop_movement() -> void:
	if not player:
		return
	
	player.velocity = Vector2.ZERO

## Obtiene la velocidad actual
func get_velocity() -> Vector2:
	if not player:
		return Vector2.ZERO
	return player.velocity

## Establece la velocidad
func set_velocity(velocity: Vector2) -> void:
	if not player:
		return
	player.velocity = velocity
