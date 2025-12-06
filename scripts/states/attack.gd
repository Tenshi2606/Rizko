# res://scripts/states/attack.gd
extends PlayerStateBase
class_name AttackState

var attack_timer: float = 0.0
var attack_component: AttackComponent
var combo_system: ComboSystem
var is_ranged_attack: bool = false

func start():
	print("\n=== ATTACK STATE START ===")
	attack_component = player.get_node("AttackComponent") as AttackComponent
	combo_system = player.get_node_or_null("ComboSystem") as ComboSystem
	
	# 🆕 CRÍTICO: Si ya estamos atacando, NO reiniciar
	# Esto evita que spam o daño reinicien la animación
	if combo_system:
		var is_attacking_now = combo_system.is_currently_attacking()
		print("🔍 is_currently_attacking: ", is_attacking_now)
		if is_attacking_now:
			print("❌ YA ESTÁ ATACANDO - BLOQUEANDO REINICIO")
			return
		else:
			print("✅ No está atacando - permitiendo inicio")
	
	# Detectar tipo de arma
	var weapon = player.get_current_weapon()
	
	# Si no tiene arma, no puede atacar
	if not weapon:
		print("⚠️ No hay arma equipada - no se puede atacar")
		state_machine.change_to("idle")
		return
	
	if weapon.has_projectile:
		# ATAQUE RANGED
		is_ranged_attack = true
		_handle_ranged_attack(weapon)
		return
	
	# ATAQUE MELEE - Usar ComboSystem
	is_ranged_attack = false
	_handle_melee_attack()

# ============================================
# 🔫 ATAQUE RANGED
# ============================================

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
	
	attack_timer = 0.2

# ============================================
# ⚔️ ATAQUE MELEE
# ============================================

func _handle_melee_attack() -> void:
	# Detectar dirección del ataque
	player.current_attack_direction = attack_component.get_attack_direction()
	player.hit_enemy_with_down_attack = false
	
	# Usar ComboSystem para todos los ataques
	if not combo_system:
		print("⚠️ No hay ComboSystem - usando fallback básico")
		_handle_basic_attack()
		return
	
	# Delegar al ComboSystem según dirección
	match player.current_attack_direction:
		Player.AttackDirection.FORWARD:
			# Ataque normal en tierra o aire
			if player.is_on_floor():
				combo_system.try_attack()
			else:
				combo_system.try_air_attack()
			# 🐛 FIX: NO resetear attack_timer para combos
			# El ComboSystem maneja el timing completamente
			# attack_timer = 0.0  ← REMOVIDO
		
		Player.AttackDirection.UP:
			# Ataque launcher
			combo_system.try_launcher_attack()
			# Usar timer para ataques especiales (no son combos)
			attack_timer = 0.5
		
		Player.AttackDirection.DOWN:
			# Ataque pogo
			combo_system.try_pogo_attack()
			# Usar timer para ataques especiales (no son combos)
			attack_timer = 0.5


func _handle_basic_attack() -> void:
	# Fallback si no hay ComboSystem
	attack_timer = player.attack_duration
	
	if anim_controller:
		anim_controller.play("attack_ground_1", true)

# ============================================
# 🔧 PHYSICS PROCESS
# ============================================

func on_physics_process(delta: float) -> void:
	# Procesar inputs de ataque durante el estado de ataque para encolar
	if Input.is_action_just_pressed("attack") and combo_system:
		combo_system.try_attack()
	
	# Actualizar timer solo si no está usando ComboSystem
	if attack_timer > 0:
		attack_timer -= delta
	
	# Salto durante combo: continuar en el aire (estilo DMC)
	if Input.is_action_just_pressed("jump") and player.can_jump():
		if combo_system and combo_system.is_in_combo():
			# Continuar combo en el aire
			player.velocity.y = -player.jump_initial_speed
			return
		else:
			# Jump cancel si no hay combo
			if combo_system:
				combo_system.reset_combo()
			state_machine.change_to("jump")
			return
	
	# Física diferente según tipo
	if is_ranged_attack:
		_handle_ranged_physics(delta)
	else:
		# Física según dirección de ataque melee
		match player.current_attack_direction:
			Player.AttackDirection.FORWARD:
				_handle_forward_attack(delta)
			Player.AttackDirection.UP:
				_handle_up_attack(delta)
			Player.AttackDirection.DOWN:
				_handle_down_attack(delta)
	
	# 🆕 PRIORIDAD 1: Si el ComboSystem está manejando el ataque, esperar
	if combo_system and combo_system.is_currently_attacking():
		return
	
	# Si hay combo activo (ventana de combo), NO SALIR
	if combo_system and combo_system.is_in_combo():
		return
	
	# Terminar ataque solo si el timer expiró y no hay combo activo
	if attack_timer <= 0:
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

# ============================================
# 🎯 FÍSICA POR TIPO DE ATAQUE
# ============================================

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
	
	# Movimiento completo durante ataque (100% velocidad para mejor movilidad)
	if input_dir != 0:
		update_sprite_flip(input_dir)
		var target_speed = input_dir * player.speed
		if abs(target_speed) > abs(player.velocity.x):
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * delta)
	else:
		# Desacelerar si no hay input
		player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
	
	player.move_and_slide()

func _handle_up_attack(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	# Movimiento completo durante launcher (100% velocidad)
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
	
	if player.is_on_floor():
		attack_timer = 0

# ============================================
# 🔚 END
# ============================================

func end():
	player.current_attack_direction = Player.AttackDirection.FORWARD
	player.hit_enemy_with_down_attack = false
	is_ranged_attack = false
