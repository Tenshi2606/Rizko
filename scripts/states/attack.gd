# res://scripts/states/attack.gd
extends PlayerStateBase
class_name AttackState

var attack_component: AttackComponent
var combo_system: ComboSystem
var is_ranged_attack: bool = false

# 🆕 NUEVO: Forzar salida cuando termina animación
var should_exit: bool = false
var exit_timer: float = 0.0

# 🆕 RED DE SEGURIDAD: Máximo tiempo en estado de ataque
var max_attack_duration: float = 3.0  # 3 segundos máximo
var time_in_state: float = 0.0

func start():
	print("\n=== ATTACK STATE START ===")
	attack_component = player.get_node("AttackComponent") as AttackComponent
	combo_system = player.get_node_or_null("ComboSystem") as ComboSystem
	
	# 🆕 RESET FLAGS
	should_exit = false
	exit_timer = 0.0
	time_in_state = 0.0  # 🆕 Reset del timer de seguridad
	
	# Verificar si ya está atacando
	if combo_system and combo_system.is_currently_attacking():
		print("  ⚠️ Ya hay ataque en progreso - NO reiniciar")
		return
	
	# Detectar tipo de arma
	var weapon = player.get_current_weapon()
	
	if not weapon:
		print("  ⚠️ No hay arma equipada")
		state_machine.change_to("idle")
		return
	
	if weapon.has_projectile:
		# ATAQUE RANGED
		is_ranged_attack = true
		_handle_ranged_attack(weapon)
		# 🆕 SALIR INMEDIATAMENTE DESPUÉS DE DISPARAR
		should_exit = true
		exit_timer = 0.3  # Esperar 0.3s para que se vea la animación
		return
	
	# ATAQUE MELEE - Usar ComboSystem
	is_ranged_attack = false
	_handle_melee_attack()

func _handle_ranged_attack(weapon: WeaponData) -> void:
	print("🔫 Ataque ranged: ", weapon.weapon_name)
	
	var direction = Vector2.RIGHT if not player.sprite.flip_h else Vector2.LEFT
	
	if player.weapon_system:
		player.weapon_system.fire_projectile(direction)
	
	if weapon.attack_animation and player.animation_controller:
		player.animation_controller.play(weapon.attack_animation)
	else:
		if player.animation_controller:
			player.animation_controller.play("attack")

func _handle_melee_attack() -> void:
	if not combo_system:
		print("  ⚠️ No hay ComboSystem")
		state_machine.change_to("idle")
		return
	
	# Detectar dirección del ataque
	player.current_attack_direction = attack_component.get_attack_direction()
	
	# Delegar al ComboSystem según dirección
	var success = false
	
	match player.current_attack_direction:
		Player.AttackDirection.FORWARD:
			if player.is_on_floor():
				success = combo_system.try_attack()
			else:
				success = combo_system.try_air_attack()
		
		Player.AttackDirection.UP:
			success = combo_system.try_launcher_attack()
		
		Player.AttackDirection.DOWN:
			success = combo_system.try_pogo_attack()
	
	if not success:
		print("  ⚠️ No se pudo ejecutar ataque")
		# 🆕 SALIR SI FALLA
		should_exit = true
		exit_timer = 0.1

func on_physics_process(delta: float) -> void:
	# 🆕 RED DE SEGURIDAD: Salir si lleva demasiado tiempo
	time_in_state += delta
	if time_in_state > max_attack_duration:
		print("⚠️ TIMEOUT: Salida forzada por exceder ", max_attack_duration, "s")
		if combo_system:
			combo_system.reset_combo()
		_transition_out()
		return
	
	# 🆕 SALIDA FORZADA
	if should_exit:
		exit_timer -= delta
		if exit_timer <= 0:
			_transition_out()
			return
	
	# Procesar spam de input (ComboSystem lo maneja)
	if Input.is_action_just_pressed("attack") and combo_system:
		combo_system.try_attack()
	
	# Salto durante combo
	if Input.is_action_just_pressed("jump") and player.can_jump():
		if combo_system and combo_system.is_in_combo():
			# Continuar combo en el aire
			player.velocity.y = -player.jump_initial_speed
			return
		else:
			# Jump cancel
			if combo_system:
				combo_system.reset_combo()
			state_machine.change_to("jump")
			return
	
	# Física diferente según tipo
	if is_ranged_attack:
		_handle_ranged_physics(delta)
	else:
		# Física melee
		match player.current_attack_direction:
			Player.AttackDirection.FORWARD:
				_handle_forward_attack(delta)
			Player.AttackDirection.UP:
				_handle_up_attack(delta)
			Player.AttackDirection.DOWN:
				_handle_down_attack(delta)
	
	# 🆕 VERIFICACIÓN MEJORADA DE SALIDA
	if combo_system:
		# Salir SI:
		# 1. NO está atacando actualmente
		# 2. NO está en ventana de combo (esperando siguiente golpe)
		# 3. NO hay input bufferado
		var can_exit = (
			not combo_system.is_currently_attacking() and
			not combo_system.is_in_combo() and
			not combo_system.input_buffer_active
		)
		
		if can_exit:
			print("✅ Condiciones de salida cumplidas - Transicionando")
			_transition_out()

func _transition_out() -> void:
	if player.is_on_floor():
		var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		if input_dir != 0:
			state_machine.change_to("run")
		else:
			state_machine.change_to("idle")
	else:
		state_machine.change_to("fall")

func _handle_ranged_physics(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var target_speed = input_dir * player.speed * 0.5
	
	if target_speed > player.velocity.x:
		player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
	elif target_speed < player.velocity.x:
		player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	
	if input_dir > 0:
		player.sprite.flip_h = false
	elif input_dir < 0:
		player.sprite.flip_h = true
	
	player.move_and_slide()

func _handle_forward_attack(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	# Movimiento completo durante ataque
	if input_dir != 0:
		update_sprite_flip(input_dir)
		var target_speed = input_dir * player.speed
		if abs(target_speed) > abs(player.velocity.x):
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
	
	player.move_and_slide()

func _handle_up_attack(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var target_speed = input_dir * player.speed
	
	if target_speed > player.velocity.x:
		player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
	elif target_speed < player.velocity.x:
		player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	
	if input_dir > 0:
		player.sprite.flip_h = false
	elif input_dir < 0:
		player.sprite.flip_h = true
	
	player.move_and_slide()

func _handle_down_attack(delta: float) -> void:
	if player.hit_enemy_with_down_attack:
		var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		var target_speed = input_dir * player.speed * 0.7
		
		if target_speed > player.velocity.x:
			player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
		elif target_speed < player.velocity.x:
			player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	else:
		player.velocity.x *= 0.98
	
	player.move_and_slide()

func end():
	player.current_attack_direction = Player.AttackDirection.FORWARD
	player.hit_enemy_with_down_attack = false
	is_ranged_attack = false
	should_exit = false
	exit_timer = 0.0
	time_in_state = 0.0  # 🆕 Reset del timer
