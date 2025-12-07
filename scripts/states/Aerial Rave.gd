extends PlayerStateBase

var attack_component: AttackComponent
var combo_system: ComboSystem
var is_ranged_attack: bool = false

var should_exit: bool = false
var exit_timer: float = 0.0

var max_attack_duration: float = 3.0
var time_in_state: float = 0.0

# 🆕 AERIAL RAVE (DMC STYLE)
var is_aerial_attacking: bool = false
var aerial_freeze_active: bool = false
var aerial_freeze_timer: float = 0.0
const AERIAL_FREEZE_DURATION: float = 0.3  # Tiempo flotando por golpe
const AERIAL_FALL_SPEED: float = 50.0      # Caída lenta después del golpe

func start():
	print("\n=== ATTACK STATE START ===")
	attack_component = player.get_node("AttackComponent") as AttackComponent
	combo_system = player.get_node_or_null("ComboSystem") as ComboSystem
	
	should_exit = false
	exit_timer = 0.0
	time_in_state = 0.0
	is_aerial_attacking = false
	aerial_freeze_active = false
	aerial_freeze_timer = 0.0
	
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
		should_exit = true
		exit_timer = 0.3
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
	
	print("  🎯 Dirección detectada: ", player.current_attack_direction)
	
	var success = false
	
	match player.current_attack_direction:
		Player.AttackDirection.FORWARD:
			if player.is_on_floor():
				print("    → Ground Attack")
				success = combo_system.try_attack()
			else:
				print("    → Air Attack (DMC Style)")
				success = combo_system.try_air_attack()
				# 🆕 ACTIVAR AERIAL RAVE
				if success:
					_start_aerial_rave()
		
		Player.AttackDirection.UP:
			print("    → Launcher Attack")
			success = combo_system.try_launcher_attack()
		
		Player.AttackDirection.DOWN:
			print("    → Pogo Attack")
			success = combo_system.try_pogo_attack()
	
	if not success:
		print("  ⚠️ No se pudo ejecutar ataque")
		should_exit = true
		exit_timer = 0.1

# 🆕 ACTIVAR AERIAL RAVE (Estilo DMC)
func _start_aerial_rave() -> void:
	print("✨ AERIAL RAVE ACTIVADO")
	is_aerial_attacking = true
	aerial_freeze_active = true
	aerial_freeze_timer = AERIAL_FREEZE_DURATION
	
	# Detener caída completamente
	player.velocity.y = 0
	
	# Efecto visual (opcional)
	if player.sprite:
		player.sprite.modulate = Color(0.7, 0.9, 1.0)  # Azul claro

# 🆕 DESACTIVAR AERIAL RAVE
func _end_aerial_rave() -> void:
	print("❄️ AERIAL RAVE TERMINADO")
	aerial_freeze_active = false
	aerial_freeze_timer = 0.0
	
	# Empezar caída lenta
	player.velocity.y = AERIAL_FALL_SPEED
	
	# Restaurar color
	if player.sprite:
		player.sprite.modulate = Color(1, 1, 1)

func on_physics_process(delta: float) -> void:
	# RED DE SEGURIDAD
	time_in_state += delta
	if time_in_state > max_attack_duration:
		print("⚠️ TIMEOUT: Salida forzada")
		if combo_system:
			combo_system.reset_combo()
		_transition_out()
		return
	
	# SALIDA FORZADA
	if should_exit:
		exit_timer -= delta
		if exit_timer <= 0:
			_transition_out()
			return
	
	# 🆕 MANEJAR AERIAL RAVE
	if is_aerial_attacking and aerial_freeze_active:
		aerial_freeze_timer -= delta
		
		# Mantener flotando
		player.velocity.y = 0
		
		# Control horizontal limitado (50%)
		var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		if input_dir != 0:
			var target_speed = input_dir * player.speed * 0.5
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * 0.5 * delta)
			update_sprite_flip(input_dir)
		
		player.move_and_slide()
		
		# Terminar freeze
		if aerial_freeze_timer <= 0:
			_end_aerial_rave()
		
		# Si presiona X de nuevo durante aerial rave, extender combo
		if Input.is_action_just_pressed("attack") and combo_system:
			if combo_system.try_air_attack():
				# Reiniciar freeze para siguiente golpe
				aerial_freeze_timer = AERIAL_FREEZE_DURATION
				player.velocity.y = 0
				print("  🔄 Aerial Rave extendido")
		
		return
	
	# Spam de input (ComboSystem lo maneja)
	if Input.is_action_just_pressed("attack") and combo_system:
		combo_system.try_attack()
	
	# Salto durante combo
	if Input.is_action_just_pressed("jump") and player.can_jump():
		if combo_system and combo_system.is_in_combo():
			player.velocity.y = -player.jump_initial_speed
			return
		else:
			if combo_system:
				combo_system.reset_combo()
			state_machine.change_to("jump")
			return
	
	# Física según tipo
	if is_ranged_attack:
		_handle_ranged_physics(delta)
	elif is_aerial_attacking and not aerial_freeze_active:
		# Caída lenta después de aerial rave
		_handle_aerial_physics(delta)
	else:
		match player.current_attack_direction:
			Player.AttackDirection.FORWARD:
				_handle_forward_attack(delta)
			Player.AttackDirection.UP:
				_handle_up_attack(delta)
			Player.AttackDirection.DOWN:
				_handle_down_attack(delta)
	
	# SALIDA RÁPIDA
	if combo_system and combo_system.can_exit_attack_state():
		print("✅ Salida rápida del AttackState")
		_transition_out()

func _transition_out() -> void:
	# Resetear aerial rave
	is_aerial_attacking = false
	aerial_freeze_active = false
	
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

# 🆕 FÍSICA DURANTE AERIAL RAVE (caída lenta)
func _handle_aerial_physics(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	# Control horizontal (70%)
	if input_dir != 0:
		var target_speed = input_dir * player.speed * 0.7
		player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * 0.7 * delta)
		update_sprite_flip(input_dir)
	
	# Caída lenta constante
	player.velocity.y = AERIAL_FALL_SPEED
	
	player.move_and_slide()

func _handle_forward_attack(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	if not player.is_on_floor():
		# En el aire: control reducido (70%)
		if input_dir != 0:
			update_sprite_flip(input_dir)
			var target_speed = input_dir * player.speed * 0.7
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * 0.7 * delta)
	else:
		# En suelo: control completo
		if input_dir != 0:
			update_sprite_flip(input_dir)
			var target_speed = input_dir * player.speed
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * delta)
		else:
			player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
	
	player.move_and_slide()

func _handle_up_attack(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	if input_dir != 0:
		var target_speed = input_dir * player.speed * 0.8
		player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * delta)
		update_sprite_flip(input_dir)
	
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
	time_in_state = 0.0
	is_aerial_attacking = false
	aerial_freeze_active = false
	aerial_freeze_timer = 0.0
