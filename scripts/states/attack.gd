# res://scripts/states/AttackState.gd
extends PlayerStateBase
class_name AttackState

## ============================================
## ATTACK STATE - UP SLASH Y LAUNCHER
## ============================================

var attack_component: AttackComponent
var combo_system: ComboSystem
var is_ranged_attack: bool = false

var should_exit: bool = false
var exit_timer: float = 0.0

var max_attack_duration: float = 2.5
var time_in_state: float = 0.0

var is_aerial_attacking: bool = false
var aerial_freeze_active: bool = false
var aerial_freeze_timer: float = 0.0
const AERIAL_FREEZE_DURATION: float = 0.2
const AERIAL_GRAVITY_REDUCTION: float = 0.25
var aerial_attack_duration: float = 0.0

var is_pogo_attacking: bool = false
var is_launcher_attacking: bool = false  # 🆕

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
	is_pogo_attacking = false
	is_launcher_attacking = false  # 🆕
	
	# 🆕 DETECCIÓN INMEDIATA (prioridad)
	# 1. POGO (↓+X en aire)
	if not player.is_on_floor() and Input.is_action_pressed("ui_down"):
		print("🦘 POGO (↓+X en aire)")
		player.current_attack_direction = Player.AttackDirection.DOWN
		is_pogo_attacking = true
		
		if combo_system:
			combo_system.try_pogo_attack()
		return
	
	# 2. LAUNCHER (↓+X en tierra)
	if player.is_on_floor() and Input.is_action_pressed("ui_down"):
		print("🚀 LAUNCHER (↓+X en tierra)")
		player.current_attack_direction = Player.AttackDirection.LAUNCHER
		is_launcher_attacking = true
		
		if combo_system:
			combo_system.try_launcher_attack()
		return
	
	# Ya está atacando
	if combo_system and combo_system.is_currently_attacking():
		print("  ⚠️ Ya atacando")
		return
	
	# Detectar arma
	var weapon = player.get_current_weapon()
	
	if not weapon:
		print("  ⚠️ Sin arma")
		state_machine.change_to("idle")
		return
	
	if weapon.has_projectile:
		is_ranged_attack = true
		_handle_ranged_attack(weapon)
		should_exit = true
		exit_timer = 0.3
		return
	
	is_ranged_attack = false
	_handle_melee_attack()

func _handle_ranged_attack(weapon: WeaponData) -> void:
	print("🔫 Ranged: ", weapon.weapon_name)
	
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
		print("  ⚠️ No ComboSystem")
		state_machine.change_to("idle")
		return
	
	player.current_attack_direction = attack_component.get_attack_direction()
	
	print("  🎯 Dirección: ", player.current_attack_direction)
	
	var success = false
	
	match player.current_attack_direction:
		Player.AttackDirection.FORWARD:
			if player.is_on_floor():
				print("    → Ground")
				success = combo_system.try_attack()
			else:
				print("    → Air")
				success = combo_system.try_air_attack()
				if success:
					_start_aerial_rave()
		
		Player.AttackDirection.UP:
			print("    → Up Slash")  # 🆕
			success = combo_system.try_up_slash_attack()
		
		Player.AttackDirection.DOWN:
			print("    → Pogo")
			success = combo_system.try_pogo_attack()
			if success:
				is_pogo_attacking = true
		
		Player.AttackDirection.LAUNCHER:
			print("    → Launcher")  # 🆕
			success = combo_system.try_launcher_attack()
			if success:
				is_launcher_attacking = true
	
	if not success:
		print("  ⚠️ No ejecutado")
		should_exit = true
		exit_timer = 0.1

func _start_aerial_rave() -> void:
	print("✨ AERIAL RAVE")
	is_aerial_attacking = true
	aerial_freeze_active = true
	aerial_freeze_timer = AERIAL_FREEZE_DURATION
	aerial_attack_duration = 0.35

func _end_aerial_rave() -> void:
	print("❄️ AERIAL END")
	is_aerial_attacking = false
	aerial_freeze_active = false
	aerial_freeze_timer = 0.0
	aerial_attack_duration = 0.0

func on_input(event: InputEvent) -> void:
	# 🆕 DETECCIÓN CONTINUA
	if event.is_action_pressed("attack"):
		# POGO (aire + abajo)
		if not player.is_on_floor() and Input.is_action_pressed("ui_down"):
			print("🦘 POGO (mid-air)")
			player.current_attack_direction = Player.AttackDirection.DOWN
			is_pogo_attacking = true
			is_launcher_attacking = false
			
			if is_aerial_attacking:
				_end_aerial_rave()
			
			if combo_system:
				combo_system.try_pogo_attack()
		
		# LAUNCHER (tierra + abajo)
		elif player.is_on_floor() and Input.is_action_pressed("ui_down"):
			print("🚀 LAUNCHER (ground)")
			player.current_attack_direction = Player.AttackDirection.LAUNCHER
			is_launcher_attacking = true
			is_pogo_attacking = false
			
			if combo_system:
				combo_system.try_launcher_attack()

func on_physics_process(delta: float) -> void:
	time_in_state += delta
	if time_in_state > max_attack_duration:
		print("⚠️ TIMEOUT")
		if combo_system:
			combo_system.reset_combo()
		_transition_out()
		return
	
	if should_exit:
		exit_timer -= delta
		if exit_timer <= 0:
			_transition_out()
			return
	
	# AERIAL RAVE (solo si NO es pogo ni launcher)
	if is_aerial_attacking and not is_pogo_attacking and not is_launcher_attacking:
		aerial_freeze_timer -= delta
		aerial_attack_duration -= delta
		
		var reduced_gravity = player.gravity_falling * AERIAL_GRAVITY_REDUCTION
		player.velocity.y += reduced_gravity * delta
		
		var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		if input_dir != 0:
			var target_speed = input_dir * player.speed * 0.85
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * 0.85 * delta)
			update_sprite_flip(input_dir)
		
		player.move_and_slide()
		
		if aerial_freeze_timer <= 0 or aerial_attack_duration <= 0:
			_end_aerial_rave()
		
		if Input.is_action_just_pressed("attack") and combo_system:
			if not Input.is_action_pressed("ui_down"):
				if combo_system.try_air_attack():
					aerial_freeze_timer = AERIAL_FREEZE_DURATION
					aerial_attack_duration = 0.35
					print("  🔄 Air extendido")
		
		return
	
	if Input.is_action_just_pressed("attack") and combo_system:
		combo_system.try_attack()
	
	if Input.is_action_just_pressed("jump") and player.can_jump():
		if combo_system and combo_system.is_in_combo():
			player.velocity.y = -player.jump_initial_speed
			return
		else:
			if combo_system:
				combo_system.reset_combo()
			state_machine.change_to("jump")
			return
	
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
			Player.AttackDirection.LAUNCHER:
				_handle_launcher_attack(delta)  # 🆕
	
	if combo_system and combo_system.can_exit_attack_state():
		print("✅ Salida rápida")
		_transition_out()

func _transition_out() -> void:
	is_aerial_attacking = false
	aerial_freeze_active = false
	is_pogo_attacking = false
	is_launcher_attacking = false  # 🆕
	
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
	
	update_sprite_flip(input_dir)
	
	player.move_and_slide()

func _handle_forward_attack(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	if not player.is_on_floor():
		if input_dir != 0:
			update_sprite_flip(input_dir)
			var target_speed = input_dir * player.speed * 0.92
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * 0.92 * delta)
	else:
		if input_dir != 0:
			update_sprite_flip(input_dir)
			var target_speed = input_dir * player.speed
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * delta)
		else:
			player.velocity.x = move_toward(player.velocity.x, 0, player.friction * delta)
	
	player.move_and_slide()

func _handle_up_attack(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	# 🆕 Control completo en up slash (85%)
	if input_dir != 0:
		var target_speed = input_dir * player.speed * 0.85
		player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * delta)
		update_sprite_flip(input_dir)
	
	player.move_and_slide()

func _handle_down_attack(delta: float) -> void:
	if not player.hit_enemy_with_down_attack:
		var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		if input_dir != 0:
			player.velocity.x *= 0.97
			update_sprite_flip(input_dir)
	else:
		var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		if input_dir != 0:
			var target_speed = input_dir * player.speed * 0.75
			player.velocity.x = move_toward(player.velocity.x, target_speed, player.acceleration * 0.6 * delta)
			update_sprite_flip(input_dir)
	
	player.move_and_slide()

# 🆕 FÍSICA DE LAUNCHER
func _handle_launcher_attack(delta: float) -> void:
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	# Control reducido durante launcher (50%)
	if input_dir != 0:
		var target_speed = input_dir * player.speed * 0.5
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
	is_launcher_attacking = false  # 🆕
