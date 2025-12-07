# res://scripts/states/AttackState.gd
extends PlayerStateBase
class_name AttackState

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
const AERIAL_FREEZE_DURATION: float = 0.25  # Tiempo flotando por golpe
const AERIAL_GRAVITY_REDUCTION: float = 0.3 # 70% menos gravedad durante ataque
var aerial_attack_duration: float = 0.0

# 🆕 POGO INSTANT
var pogo_requested: bool = false
var is_pogo_attacking: bool = false

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
	aerial_attack_duration = 0.0
	pogo_requested = false
	is_pogo_attacking = false
	
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
				print("    → Air Attack")
				success = combo_system.try_air_attack()
				# 🆕 ACTIVAR AERIAL RAVE SOLO EN ATAQUES FORWARD AÉREOS
				if success:
					_start_aerial_rave()
		
		Player.AttackDirection.UP:
			print("    → Launcher Attack")
			success = combo_system.try_launcher_attack()
		
		Player.AttackDirection.DOWN:
			print("    → Pogo Attack (INSTANT)")
			success = combo_system.try_pogo_attack()
			if success:
				is_pogo_attacking = true  # 🆕 Marcar como pogo
				# NO activar aerial rave para pogo
	
	if not success:
		print("  ⚠️ No se pudo ejecutar ataque")
		should_exit = true
		exit_timer = 0.1

# 🆕 ACTIVAR AERIAL RAVE (Estilo DMC) - SOLO REDUCIR GRAVEDAD
func _start_aerial_rave() -> void:
	print("✨ AERIAL RAVE ACTIVADO - Gravedad reducida")
	is_aerial_attacking = true
	aerial_freeze_active = true
	aerial_freeze_timer = AERIAL_FREEZE_DURATION
	aerial_attack_duration = 0.4  # Duración del ataque aéreo
	
	# NO detener caída, solo reducir gravedad
	# player.velocity.y se maneja en _handle_aerial_physics()

# 🆕 DESACTIVAR AERIAL RAVE
func _end_aerial_rave() -> void:
	print("❄️ AERIAL RAVE TERMINADO - Gravedad normal")
	is_aerial_attacking = false
	aerial_freeze_active = false
	aerial_freeze_timer = 0.0
	aerial_attack_duration = 0.0

func on_input(event: InputEvent) -> void:
	# 🆕 POGO INSTANT - Detectar ↓+X en cualquier momento
	if event.is_action_pressed("attack"):
		if not player.is_on_floor() and Input.is_action_pressed("ui_down"):
			print("🦘 POGO INSTANT DETECTADO")
			player.current_attack_direction = Player.AttackDirection.DOWN
			is_pogo_attacking = true
			
			# Si está en aerial rave, cancelarlo para pogo
			if is_aerial_attacking:
				_end_aerial_rave()
			
			# Ejecutar pogo inmediatamente
			if combo_system:
				combo_system.try_pogo_attack()

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
	
	# 🆕 MANEJAR AERIAL RAVE - SOLO SI NO ES POGO
	if is_aerial_attacking and not is_pogo_attacking:
		aerial_freeze_timer -= delta
		aerial_attack_duration -= delta
		
		# Aplicar gravedad reducida en lugar de detener completamente
		var reduced_gravity = player.gravity_falling * AERIAL_GRAVITY_REDUCTION
		player.velocity.y += reduced_gravity * delta
		
		# Control horizontal (80%)
		var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		if input_dir != 0:
			var target_speed = input_dir * player.speed * 0.8
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * 0.8 * delta)
			update_sprite_flip(input_dir)
		
		player.move_and_slide()
		
		# Terminar aerial rave cuando termine el timer O la animación
		if aerial_freeze_timer <= 0 or aerial_attack_duration <= 0:
			_end_aerial_rave()
		
		# Si presiona X de nuevo durante aerial rave, extender combo
		if Input.is_action_just_pressed("attack") and combo_system:
			if not Input.is_action_pressed("ui_down"):  # No pogo
				if combo_system.try_air_attack():
					# Reiniciar timers para siguiente golpe
					aerial_freeze_timer = AERIAL_FREEZE_DURATION
					aerial_attack_duration = 0.4
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
	# Resetear aerial rave y pogo
	is_aerial_attacking = false
	aerial_freeze_active = false
	is_pogo_attacking = false
	
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
# ELIMINADA - Ya no se usa, la gravedad se reduce en el main loop

func _handle_forward_attack(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	if not player.is_on_floor():
		# 🆕 EN EL AIRE: MANTENER MOMENTUM COMPLETO (90%)
		if input_dir != 0:
			update_sprite_flip(input_dir)
			var target_speed = input_dir * player.speed * 0.9  # ERA 0.7
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * 0.9 * delta)
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
	
	# Control completo en launcher
	if input_dir != 0:
		var target_speed = input_dir * player.speed * 0.8
		player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * delta)
		update_sprite_flip(input_dir)
	
	player.move_and_slide()

func _handle_down_attack(delta: float) -> void:
	# 🆕 POGO - Mantener velocidad de caída normal hasta golpear
	if not player.hit_enemy_with_down_attack:
		# Caída normal durante pogo (antes de golpear)
		# Control horizontal mínimo
		var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		if input_dir != 0:
			player.velocity.x *= 0.95  # Fricción leve
			update_sprite_flip(input_dir)
	else:
		# Ya golpeó - El rebote se aplica en AttackComponent
		# Solo permitir control horizontal después del rebote
		var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		if input_dir != 0:
			var target_speed = input_dir * player.speed * 0.7
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * 0.5 * delta)
			update_sprite_flip(input_dir)
	
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
	aerial_attack_duration = 0.0
	is_pogo_attacking = false
