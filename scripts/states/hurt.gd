extends PlayerStateBase
class_name HurtState

var hurt_duration: float = 0.3  # 🔧 Duración corta del estado
var hurt_timer: float = 0.0

func start():
	hurt_timer = hurt_duration
	
	# Animación de daño si existe
	if player.sprite:
		if player.sprite.sprite_frames.has_animation("hurt"):
			player.sprite.play("hurt")
	
	print("💥 Hurt state iniciado - Duración: ", hurt_duration)

func on_physics_process(delta: float) -> void:
	hurt_timer -= delta
	
	# 🔧 PERMITIR MOVIMIENTO DURANTE HURT
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var target_speed = input_dir * player.speed * 0.7  # 70% de velocidad
	
	if target_speed > player.velocity.x:
		player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
	elif target_speed < player.velocity.x:
		player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	
	# ✅ Usar método de la clase base para sprite flip
	update_sprite_flip(input_dir)
	
	# Aplicar gravedad (ya se aplica en Player._physics_process)
	player.move_and_slide()
	
	# 🔧 Salir rápido del estado Hurt
	if hurt_timer <= 0:
		_end_hurt()

func _end_hurt() -> void:
	print("✅ Hurt state terminado")
	
	# Transición al estado apropiado
	if player.is_on_floor():
		if abs(player.velocity.x) > 10:
			state_machine.change_to("run")
		else:
			state_machine.change_to("idle")
	else:
		state_machine.change_to("fall")

func end():
	pass
