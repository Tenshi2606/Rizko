# res://scripts/player/states/HealState.gd
extends PlayerStateBase
class_name HealState

@export var healing_duration: float = 5.0
@export var attack_duration: float = 0.3
@export var attack_cooldown: float = 0.4

var hits_remaining: int = 0
var heal_per_hit: int = 1
var healing_timer: float = 0.0
var attack_animation_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var is_attacking: bool = false
var ending_healing: bool = false
var attack_requested: bool = false
var end_transition_delay: float = 0.0

# Variables para dash interno
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_speed: float = 350.0
var dash_duration: float = 0.15
var dash_cooldown: float = 0.8
var dash_direction: Vector2 = Vector2.ZERO

# 🆕 REFERENCIAS A HITBOXES
var ground_hitbox: Area2D = null

func start():
	var active_fragment = player.active_healing_fragment
	
	if not active_fragment:
		state_machine.change_to("idle")
		return
	
	_ensure_melee_weapon()
	
	hits_remaining = active_fragment.hits_required
	healing_timer = healing_duration
	attack_animation_timer = 0.0
	attack_cooldown_timer = 0.0
	is_attacking = false
	ending_healing = false
	attack_requested = false
	end_transition_delay = 0.0
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	
	player.is_in_healing_mode = true
	
	# 🆕 OBTENER HITBOX
	var hitbox_container = player.get_node_or_null("HitboxContainer")
	if hitbox_container:
		ground_hitbox = hitbox_container.get_node_or_null("GroundAttackHitbox")
		if ground_hitbox:
			print("  ✅ GroundHitbox encontrado para curación")
		else:
			push_error("  ❌ GroundAttackHitbox no encontrado")
	
	# Activar aura
	var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
	if vfx_manager:
		vfx_manager.activate_healing_aura()
	
	print("🩹 Modo Curación activado!")
	print("  ⚔️ Golpes disponibles: ", hits_remaining)
	print("  ⏱️ Tiempo límite: ", healing_duration, " segundos")

func _ensure_melee_weapon() -> void:
	var weapon_system = player.get_node_or_null("WeaponSystem") as WeaponSystem
	if not weapon_system:
		return
	
	var current_weapon = weapon_system.get_current_weapon()
	if not current_weapon:
		print("  ⚠️ No hay arma equipada - curación cancelada")
		state_machine.change_to("idle")
		return
	
	if current_weapon.has_projectile:
		print("🔄 Arma de rango detectada, cambiando a melee...")
		
		if weapon_system.has_weapon("scythe"):
			var scythe = WeaponDB.get_weapon("scythe")
			if scythe:
				weapon_system.equip_weapon(scythe)
				print("  ✅ Cambiado a: Guadaña Espectral")
				return
		
		print("  ⚠️ No hay arma melee disponible - curación cancelada")
		state_machine.change_to("idle")

func on_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not is_attacking and attack_cooldown_timer <= 0:
		attack_requested = true
	
	if event.is_action_pressed("dash"):
		if dash_cooldown_timer > 0:
			print("⏱️ Dash en cooldown: %.1f" % dash_cooldown_timer, "s")
			return
		
		var ability_system = player.get_node_or_null("AbilitySystem") as AbilitySystem
		if ability_system and ability_system.has_ability("dash"):
			_start_dash()

func on_physics_process(delta: float) -> void:
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	if ending_healing:
		if end_transition_delay > 0:
			end_transition_delay -= delta
			if end_transition_delay <= 0:
				_do_state_transition()
		return
	
	if is_dashing:
		_process_dash(delta)
		return
	
	healing_timer -= delta
	
	if attack_animation_timer > 0:
		attack_animation_timer -= delta
		if attack_animation_timer <= 0:
			is_attacking = false
			_deactivate_hitbox()  # 🆕 Desactivar hitbox al terminar
			_restore_movement_animation()
	
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	if healing_timer <= 0:
		_end_healing("Tiempo agotado")
		return
	
	if hits_remaining <= 0:
		_end_healing("Todos los golpes usados")
		return
	
	if not is_attacking:
		_update_movement_animation()
	
	# Movimiento
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
	
	if input_dir == 0 and abs(player.velocity.x) > 0:
		var dec = player.friction * delta
		if abs(player.velocity.x) <= dec:
			player.velocity.x = 0
		else:
			player.velocity.x -= sign(player.velocity.x) * dec
	
	# Salto
	if Input.is_action_just_pressed("jump") and player.can_jump():
		player.is_jumping = true
		player.jump_time = 0.0
		player.velocity.y = -player.jump_initial_speed
	
	if player.is_jumping:
		if Input.is_action_pressed("jump") and player.jump_time < player.max_jump_hold_time:
			player.velocity.y -= player.jump_hold_accel * delta
			player.jump_time += delta
		else:
			player.is_jumping = false
	
	# Procesar ataque
	if attack_requested and not is_attacking and attack_cooldown_timer <= 0:
		attack_requested = false
		_start_attack()
	
	player.move_and_slide()

func _update_movement_animation() -> void:
	if not anim_controller:
		return
	
	var base_anim = ""
	
	if not player.is_on_floor():
		if player.velocity.y < 0:
			base_anim = "jump"
		else:
			base_anim = "fall"
	else:
		if abs(player.velocity.x) > 10:
			base_anim = "run"
		else:
			base_anim = "idle"
	
	anim_controller.play(base_anim)

func _restore_movement_animation() -> void:
	_update_movement_animation()

func _start_dash() -> void:
	if is_dashing:
		return
	
	print("💨 Dash ejecutado (manteniendo curación)")
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	var input_dir = player.get_movement_input()
	if input_dir != 0:
		dash_direction = Vector2(input_dir, 0).normalized()
	else:
		dash_direction = Vector2(-1 if player.sprite.flip_h else 1, 0)
	
	player.velocity = dash_direction * dash_speed
	player.invulnerable = true

func _process_dash(delta: float) -> void:
	dash_timer -= delta
	
	player.velocity.x = dash_direction.x * dash_speed
	player.velocity.y = 0
	
	player.move_and_slide()
	
	if dash_timer <= 0:
		print("✅ Dash terminado - Curación continúa")
		is_dashing = false
		player.invulnerable = false
		player.velocity.x = 0

func _start_attack() -> void:
	if is_attacking:
		return
	
	print("⚔️ HealState: Iniciando ataque")
	
	is_attacking = true
	attack_animation_timer = attack_duration
	attack_cooldown_timer = attack_cooldown
	
	# 🆕 ACTIVAR HITBOX MANUALMENTE
	_activate_hitbox()
	
	# Reproducir animación
	if anim_controller:
		# Obtener arma actual
		var weapon = player.get_current_weapon()
		var anim_name = "attack"
		
		if weapon and weapon.weapon_id == "scythe":
			anim_name = "scythe_attack_1"
		
		print("  🎬 Reproduciendo: ", anim_name)
		anim_controller.play(anim_name)

# 🆕 ACTIVAR HITBOX MANUALMENTE
func _activate_hitbox() -> void:
	if not ground_hitbox:
		print("  ❌ No hay hitbox para activar")
		return
	
	# Limpiar lista de enemigos golpeados
	if player.attack_component:
		player.attack_component.enemies_hit_this_attack.clear()
		print("  🔄 Lista de golpes limpiada")
	
	# Activar hitbox
	ground_hitbox.monitoring = true
	ground_hitbox.monitorable = true
	print("  ✅ Hitbox activado")

# 🆕 DESACTIVAR HITBOX MANUALMENTE
func _deactivate_hitbox() -> void:
	if not ground_hitbox:
		return
	
	ground_hitbox.monitoring = false
	ground_hitbox.monitorable = false
	print("  ❌ Hitbox desactivado")

# 🆕 REGISTRAR GOLPE (llamado desde AttackComponent)
func register_hit() -> void:
	if not is_attacking or ending_healing:
		return
	
	print("🎯 register_hit() - Golpe aceptado en HealState")
	
	# Curar al jugador
	var health_component = player.get_node_or_null("HealthComponent") as HealthComponent
	if health_component and player.health < player.max_health:
		var old_health = player.health
		player.health = min(player.max_health, player.health + heal_per_hit)
		health_component._update_health_bar()
		
		var healed = player.health - old_health
		if healed > 0:
			print("💚 +", healed, " HP | Golpes restantes: ", hits_remaining - 1)
	
	hits_remaining -= 1
	
	if hits_remaining <= 0:
		_end_healing("Todos los golpes usados")

func _end_healing(reason: String) -> void:
	if ending_healing:
		return
	
	ending_healing = true
	end_transition_delay = 0.15
	
	print("🩹 Curación finalizada: ", reason)
	
	player.is_in_healing_mode = false
	player.active_healing_fragment = null
	is_attacking = false
	attack_animation_timer = 0.0
	attack_cooldown_timer = 0.0
	attack_requested = false
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	
	# Desactivar hitbox
	_deactivate_hitbox()
	
	# Desactivar aura
	var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
	if vfx_manager:
		vfx_manager.deactivate_healing_aura()

func _do_state_transition() -> void:
	if not player.is_on_floor():
		state_machine.change_to("fall")
	elif abs(player.velocity.x) > 10:
		state_machine.change_to("run")
	else:
		state_machine.change_to("idle")

func end():
	if not player:
		return
	
	player.is_in_healing_mode = false
	player.active_healing_fragment = null
	
	# Asegurar que hitbox esté desactivado
	_deactivate_hitbox()
	
	# Desactivar aura
	var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
	if vfx_manager:
		vfx_manager.deactivate_healing_aura()
	
	is_attacking = false
	attack_animation_timer = 0.0
	attack_cooldown_timer = 0.0
	ending_healing = false
	attack_requested = false
	end_transition_delay = 0.0
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
