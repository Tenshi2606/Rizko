# res://scripts/player/states/DashState.gd
extends PlayerStateBase
class_name DashState

var dash_speed: float = 350.0
var dash_duration: float = 0.15
var dash_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

var was_healing: bool = false

func start():
	
	# 🆕 CANCELAR RECARGA SI ESTÁ ACTIVA
	if player.weapon_system:
		if player.weapon_system.is_reloading:
			print("💨 Dash ejecutado - Cancelando recarga...")
			player.weapon_system.cancel_reload()
	
	# 🔧 Detectar si está curándose
	was_healing = player.is_in_healing_mode
	if was_healing:
		print("💨 Dash activado (manteniendo modo curación)")
		# Pausar HealState sin limpiarlo
		var heal_state = state_machine.get_node_or_null("Heal") as HealState
		if heal_state:
			heal_state.pause_for_dash()
	
	# Obtener dirección del input
	var input_dir = player.get_movement_input()
	
	if input_dir != 0:
		dash_direction = Vector2(input_dir, 0).normalized()
	else:
		dash_direction = Vector2(-1 if player.sprite.flip_h else 1, 0)
	
	# Obtener stats del dash
	var ability_system = player.get_node_or_null("AbilitySystem") as AbilitySystem
	if ability_system:
		var dash_ability = ability_system.get_ability("dash")
		if dash_ability and dash_ability is ActiveAbility:
			var active_dash = dash_ability as ActiveAbility
			dash_speed = active_dash.dash_speed
			dash_duration = active_dash.dash_duration
	
	dash_timer = dash_duration
	player.velocity = dash_direction * dash_speed
	player.invulnerable = true
	
	# 🆕 ACTIVAR ESTELA DE DASH
	var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
	if vfx_manager:
		vfx_manager.activate_dash_trail()
	
	# Animación de dash
	if anim_controller:
		anim_controller.play("dash")
		# Fallback: usar run o jump según contexto si "dash" no existe o si se quiere un comportamiento específico
		# La lógica de fallback debería estar dentro del AnimationController o manejarse aquí si es necesario.
		# Por ahora, asumo que "dash" siempre existe o que el AnimationController maneja el fallback.
		# Si se necesita un fallback explícito aquí, sería algo como:
		# if not anim_controller.has_animation("dash"):
		# 	if player.is_on_floor():
		# 		anim_controller.play("run")
		# 	else:
		# 		anim_controller.play("jump")
	
		# Efecto visual: brillo azul durante dash (si NO está curándose)
		if not was_healing:
			player.sprite.modulate = Color(0.7, 0.7, 1.0)

func on_physics_process(delta: float) -> void:
	
	dash_timer -= delta
	player.velocity.x = dash_direction.x * dash_speed
	player.velocity.y = 0
	player.move_and_slide()
	
	if dash_timer <= 0:
		_end_dash()

func _end_dash() -> void:
	player.invulnerable = false
	
	# 🆕 DESACTIVAR ESTELA DE DASH
	var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
	if vfx_manager:
		vfx_manager.deactivate_dash_trail()
	
	# 🔧 Volver a Heal si estaba curándose
	if was_healing:
		print("✅ Dash terminado - Volviendo a curación")
		state_machine.change_to("Heal")
	else:
		# Restaurar color normal
		if player.sprite:
			player.sprite.modulate = Color(1, 1, 1)
		
		if player.is_on_floor():
			if abs(player.velocity.x) > 50:
				state_machine.change_to("run")
			else:
				state_machine.change_to("idle")
		else:
			state_machine.change_to("fall")

func end():
	
	if player:
		# 🆕 ASEGURAR QUE LA ESTELA SE DESACTIVE
		var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
		if vfx_manager:
			vfx_manager.deactivate_dash_trail()
		
		if not was_healing:
			player.invulnerable = false
			if player.sprite:
				player.sprite.modulate = Color(1, 1, 1)
