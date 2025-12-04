class_name PlayerStateBase
extends StateBase

## ============================================
## CLASE BASE PARA TODOS LOS ESTADOS DEL PLAYER
## ============================================
## Contiene métodos comunes que todos los estados pueden usar
## para evitar duplicación de código

# ============================================
# VARIABLES
# ============================================

## Referencia al player (se obtiene de controlled_node)
var player: Player:
	get:
		return controlled_node as Player

## Referencia opcional al MovementComponent
var movement_component: MovementComponent:
	get:
		if player:
			return player.get_node_or_null("MovementComponent") as MovementComponent
		return null

## Referencia opcional al AnimationController
var anim_controller: AnimationController:
	get:
		if player:
			return player.get_node_or_null("AnimationController") as AnimationController
		return null

# ============================================
# MÉTODOS COMUNES - SPRITE FLIP
# ============================================

## Actualiza la dirección del sprite basándose en el input del jugador
## Solo cambia si hay input (no se voltea por knockback)
func update_sprite_flip(input_dir: float) -> void:
	if input_dir > 0:
		player.sprite.flip_h = false
	elif input_dir < 0:
		player.sprite.flip_h = true

# ============================================
# MÉTODOS COMUNES - INPUT
# ============================================

## Obtiene la dirección del input horizontal (-1, 0, 1)
func get_input_direction() -> float:
	return Input.get_axis("ui_left", "ui_right")

## Verifica si el jugador está presionando el botón de salto
func is_jump_pressed() -> bool:
	return Input.is_action_just_pressed("ui_accept")

## Verifica si el jugador está presionando el botón de ataque
func is_attack_pressed() -> bool:
	return Input.is_action_just_pressed("attack")

# ============================================
# MÉTODOS COMUNES - MOVIMIENTO
# ============================================

## Aplica movimiento horizontal con aceleración/desaceleración
func apply_horizontal_movement(delta: float, input_dir: float, speed: float = 0.0) -> void:
	var target_speed = speed if speed > 0 else player.speed
	
	if input_dir != 0:
		# Acelerar
		player.velocity.x = move_toward(player.velocity.x, input_dir * target_speed, player.acceleration * delta)
	else:
		# Desacelerar (fricción)
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)

## Aplica gravedad al jugador
func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += player.gravity * delta

# ============================================
# MÉTODOS COMUNES - TRANSICIONES
# ============================================

## Verifica si el jugador debe cambiar a estado de caída
func should_transition_to_fall() -> bool:
	return not player.is_on_floor() and player.velocity.y >= 0

## Verifica si el jugador debe cambiar a estado idle
func should_transition_to_idle(input_dir: float) -> bool:
	return player.is_on_floor() and input_dir == 0

## Verifica si el jugador debe cambiar a estado run
func should_transition_to_run(input_dir: float) -> bool:
	return player.is_on_floor() and input_dir != 0
