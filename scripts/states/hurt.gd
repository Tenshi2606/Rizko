# res://scripts/states/HurtState.gd
extends PlayerStateBase
class_name HurtState

# 🆕 DURACIÓN REDUCIDA (era 0.3s, ahora 0.15s)
var hurt_duration: float = 0.15
var hurt_timer: float = 0.0

func start():
	hurt_timer = hurt_duration
	
	# Animación de daño
	if anim_controller:
		anim_controller.play("hurt")
	
	print("💥 Hurt state iniciado - Duración: ", hurt_duration)

func on_physics_process(delta: float) -> void:
	hurt_timer -= delta
	
	# 🆕 CONTROL COMPLETO DURANTE HURT (sin reducción de velocidad)
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var target_speed = input_dir * player.speed  # 100% velocidad (era 70%)
	
	if target_speed > player.velocity.x:
		player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
	elif target_speed < player.velocity.x:
		player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	
	# Sprite flip
	update_sprite_flip(input_dir)
	
	player.move_and_slide()
	
	# 🆕 SALIR MUY RÁPIDO
	if hurt_timer <= 0:
		_end_hurt()

func _end_hurt() -> void:
	print("✅ Hurt state terminado")
	
	# Transición inmediata
	if player.is_on_floor():
		if abs(player.velocity.x) > 10:
			state_machine.change_to("run")
		else:
			state_machine.change_to("idle")
	else:
		state_machine.change_to("fall")

func end():
	pass
