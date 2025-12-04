extends PlayerStateBase
class_name AttackState

var attack_timer: float = 0.0
var attack_component: AttackComponent
var is_ranged_attack: bool = false  # 🆕 Flag para ataques a distancia

func start():
	attack_component = player.get_node("AttackComponent") as AttackComponent
	
	# 🆕 DETECTAR TIPO DE ARMA
	var weapon = player.get_current_weapon()
	
	if weapon and weapon.has_projectile:
		# =============================
		# ATAQUE RANGED (DISPARAR)
		# =============================
		is_ranged_attack = true
		_handle_ranged_attack(weapon)
		return
	else:
		# =============================
		# ATAQUE MELEE (NORMAL)
		# =============================
		is_ranged_attack = false
		_handle_melee_attack()

# 🆕 MANEJAR ATAQUE A DISTANCIA
func _handle_ranged_attack(weapon: WeaponData) -> void:
	print("🔫 Ataque ranged detectado: ", weapon.weapon_name)
	
	# Determinar dirección de disparo
	var direction = Vector2.RIGHT if not player.sprite.flip_h else Vector2.LEFT
	
	# Disparar proyectil
	if player.weapon_system:
		player.weapon_system.fire_projectile(direction)
	
	# Animación de disparo (si existe)
	if weapon.attack_animation and player.sprite.sprite_frames.has_animation(weapon.attack_animation):
		player.sprite.play(weapon.attack_animation)
	else:
		player.sprite.play("attack")  # Fallback
	
	# Duración del ataque (más corta para armas ranged)
	attack_timer = 0.2  # 0.2s para volver a moverse
	
	# NO activar hitbox melee
	player.attack_hitbox.monitoring = false

# 🆕 MANEJAR ATAQUE MELEE (EXISTENTE)
func _handle_melee_attack() -> void:
	# Detectar dirección del ataque
	player.current_attack_direction = attack_component.get_attack_direction()
	player.hit_enemy_with_down_attack = false
	
	attack_timer = player.attack_duration
	player.attack_hitbox.monitoring = true
	
	# 🔧 Reproducir animación usando AnimationController
	if anim_controller:
		match player.current_attack_direction:
			Player.AttackDirection.FORWARD:
				anim_controller.play("attack", true)
			Player.AttackDirection.UP:
				anim_controller.play("attack_up", true)
			Player.AttackDirection.DOWN:
				anim_controller.play("attack_down", true)
	else:
		# Fallback - reproducir animación directamente
		match player.current_attack_direction:
			Player.AttackDirection.FORWARD:
				player.sprite.play("attack")
			Player.AttackDirection.UP:
				if player.sprite.sprite_frames.has_animation("attack_up"):
					player.sprite.play("attack_up")
				else:
					player.sprite.play("attack")
			Player.AttackDirection.DOWN:
				if player.sprite.sprite_frames.has_animation("attack_down"):
					player.sprite.play("attack_down")
					player.sprite.play("attack")

func on_physics_process(delta: float) -> void:
	
	attack_timer -= delta
	
	# 🆕 Comportamiento diferente para ranged vs melee
	if is_ranged_attack:
		_handle_ranged_physics(delta)
	else:
		# Comportamiento según tipo de ataque melee
		match player.current_attack_direction:
			Player.AttackDirection.FORWARD:
				_handle_forward_attack(delta)
			Player.AttackDirection.UP:
				_handle_up_attack(delta)
			Player.AttackDirection.DOWN:
				_handle_down_attack(delta)
	
	# Terminar ataque
	if attack_timer <= 0:
		player.attack_hitbox.monitoring = false
		
		if player.is_on_floor():
			var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
			if input_dir != 0:
				state_machine.change_to("run")
			else:
				state_machine.change_to("idle")
		else:
			state_machine.change_to("fall")
		return

# 🆕 FÍSICA PARA ATAQUE RANGED (permite movimiento)
func _handle_ranged_physics(delta: float) -> void:
	# Permitir movimiento horizontal mientras dispara
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var target_speed = input_dir * player.speed * 0.5  # 50% de velocidad mientras dispara
	
	if target_speed > player.velocity.x:
		player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
	elif target_speed < player.velocity.x:
		player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	
	# Flip sprite según dirección
	if input_dir > 0:
		player.sprite.flip_h = false
	elif input_dir < 0:
		player.sprite.flip_h = true
	
	player.move_and_slide()

# FÍSICA PARA ATAQUE MELEE (código existente)
func _handle_forward_attack(delta: float) -> void:
	# ✅ REMOVIDA LA VARIABLE NO USADA "original_flip"
	
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var target_speed = input_dir * player.speed
	
	if target_speed > player.velocity.x:
		player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
	elif target_speed < player.velocity.x:
		player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	
	# 🆕 Solo cambiar flip si hay INPUT del jugador (no por retroceso)
	if input_dir > 0:
		player.sprite.flip_h = false
	elif input_dir < 0:
		player.sprite.flip_h = true
	# Si no hay input, mantener la dirección actual
	
	player.move_and_slide()

func _handle_up_attack(delta: float) -> void:
	# 🆕 Permitir movimiento horizontal durante ataque hacia arriba
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var target_speed = input_dir * player.speed * 0.7  # 70% de velocidad
	
	if target_speed > player.velocity.x:
		player.velocity.x = min(player.velocity.x + player.acceleration * delta, target_speed)
	elif target_speed < player.velocity.x:
		player.velocity.x = max(player.velocity.x - player.acceleration * delta, target_speed)
	
	# Flip sprite según dirección
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

func end():
	player.attack_hitbox.monitoring = false
	player.current_attack_direction = Player.AttackDirection.FORWARD
	player.hit_enemy_with_down_attack = false
	is_ranged_attack = false  # 🆕 Resetear
