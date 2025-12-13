# res://scripts/states/HurtState.gd
extends PlayerStateBase
class_name HurtState

var hurt_duration: float = 0.08
var hurt_timer: float = 0.0

func start():
	hurt_timer = hurt_duration
	
	# 🔥 CRÍTICO: DESACTIVAR TODAS LAS HITBOXES AL RECIBIR DAÑO
	_force_deactivate_all_hitboxes()
	
	# Animación de daño
	if anim_controller:
		anim_controller.play("hurt")
	
	print("💥 Hurt state iniciado - Duración: ", hurt_duration)

# 🆕 DESACTIVAR HITBOXES FORZADAMENTE
func _force_deactivate_all_hitboxes() -> void:
	var hitbox_container = player.get_node_or_null("HitboxContainer")
	if not hitbox_container:
		return
	
	for hitbox in hitbox_container.get_children():
		if hitbox is Area2D:
			hitbox.monitoring = false
			hitbox.monitorable = false
	
	print("  🛡️ Todas las hitboxes desactivadas")
	
	# Limpiar lista de enemigos golpeados
	if player.attack_component:
		player.attack_component.enemies_hit_this_attack.clear()
		print("  🧹 Lista de golpes limpiada")

func on_physics_process(delta: float) -> void:
	hurt_timer -= delta
	
	# Control completo durante hurt
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var target_speed = input_dir * player.speed
	
	if target_speed > player.velocity.x:
		player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
	elif target_speed < player.velocity.x:
		player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	
	# Sprite flip
	update_sprite_flip(input_dir)
	
	player.move_and_slide()
	
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
	# Asegurar que hitboxes sigan desactivadas al salir
	_force_deactivate_all_hitboxes()
