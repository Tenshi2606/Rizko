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
var attack_hitbox_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var is_attacking: bool = false
var hitbox_active: bool = false
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

func start():
	
	var active_fragment = player.active_healing_fragment
	
	if not active_fragment:
		state_machine.change_to("idle")
		return
	
	# 🆕 CAMBIAR A ARMA MELEE SI TIENE ARMA DE RANGO
	_ensure_melee_weapon()
	
	hits_remaining = active_fragment.hits_required
	healing_timer = healing_duration
	attack_animation_timer = 0.0
	attack_hitbox_timer = 0.0
	attack_cooldown_timer = 0.0
	is_attacking = false
	hitbox_active = false
	ending_healing = false
	attack_requested = false
	end_transition_delay = 0.0
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	
	player.is_in_healing_mode = true
	
	# 🆕 ACTIVAR AURA DE CURACIÓN VÍA VFXManager
	var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
	if vfx_manager:
		vfx_manager.activate_healing_aura()
		print("✨ Aura de curación activada")
	else:
		push_warning("⚠️ VFXManager no encontrado en Player")
	
	print("🩹 Modo Curación activado!")
	print("  ⚔️ Golpes disponibles: ", hits_remaining)
	print("  ⏱️ Tiempo límite: ", healing_duration, " segundos")
	print("  💨 Puedes usar dash (C) mientras te curas")

# 🆕 ASEGURAR QUE TENGA ARMA MELEE EQUIPADA
func _ensure_melee_weapon() -> void:
	var weapon_system = player.get_node_or_null("WeaponSystem") as WeaponSystem
	if not weapon_system:
		return
	
	var current_weapon = weapon_system.get_current_weapon()
	if not current_weapon:
		return
	
	# Si tiene arma de rango, cambiar a melee
	if current_weapon.has_projectile:
		print("🔄 Arma de rango detectada, cambiando a melee...")
		
		# Prioridad: Guadaña > Manos
		if weapon_system.has_weapon("scythe"):
			var scythe = WeaponDB.get_weapon("scythe")
			if scythe:
				weapon_system.equip_weapon(scythe)
				print("  ✅ Cambiado a: Guadaña Espectral")
				return
		
		# Si no tiene guadaña, usar manos
		var hands = WeaponDB.get_weapon("spectral_hands")
		if hands:
			weapon_system.equip_weapon(hands)
			print("  ✅ Cambiado a: Manos Espectrales")


func on_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack") and not is_attacking and attack_cooldown_timer <= 0:
		attack_requested = true
	
	# Detectar dash (C)
	if event.is_action_pressed("dash"):
		if dash_cooldown_timer > 0:
			print("⏱️ Dash en cooldown: %.1f" % dash_cooldown_timer, "s")
			return
		
		var ability_system = player.get_node_or_null("AbilitySystem") as AbilitySystem
		if ability_system and ability_system.has_ability("dash"):
			_start_dash()

func on_physics_process(delta: float) -> void:
	
	# Actualizar cooldown del dash
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	
	# Si estamos en transición de salida, solo esperar
	if ending_healing:
		if end_transition_delay > 0:
			end_transition_delay -= delta
			if end_transition_delay <= 0:
				_do_state_transition()
		return
	
	# Manejar dash si está activo
	if is_dashing:
		_process_dash(delta)
		return
	
	# Actualizar timers
	healing_timer -= delta
	
	if attack_animation_timer > 0:
		attack_animation_timer -= delta
		if attack_animation_timer <= 0:
			is_attacking = false
			_restore_movement_animation()
	
	if attack_hitbox_timer > 0:
		attack_hitbox_timer -= delta
		if attack_hitbox_timer <= 0:
			_deactivate_hitbox()
	
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
	
	# Verificar condiciones de fin
	if healing_timer <= 0:
		_end_healing("Tiempo agotado")
		return
	
	if hits_remaining <= 0:
		_end_healing("Todos los golpes usados")
		return
	
	# 🆕 ACTUALIZAR ANIMACIÓN DE MOVIMIENTO (sin tocar el aura)
	if not is_attacking:
		_update_movement_animation()
	
	# Movimiento (normal)
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
	
	# Procesar ataque solicitado
	if attack_requested and not is_attacking and attack_cooldown_timer <= 0:
		attack_requested = false
		_start_attack()
	
	player.move_and_slide()

# 🆕 ANIMACIÓN DE MOVIMIENTO CON ARMAS
func _update_movement_animation() -> void:
	if not player.sprite:
		return
	
	# Obtener arma actual para determinar sufijo de animación
	var anim_suffix = _get_animation_suffix()
	
	# Determinar animación base según estado
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
	
	# Construir nombre de animación con sufijo
	var anim_name = base_anim + anim_suffix
	
	# Intentar usar animación con arma, si no existe usar la base
	if player.sprite.sprite_frames.has_animation(anim_name):
		if player.sprite.animation != anim_name:
			player.sprite.play(anim_name)
	elif player.sprite.sprite_frames.has_animation(base_anim):
		if player.sprite.animation != base_anim:
			player.sprite.play(base_anim)

# 🆕 OBTENER SUFIJO DE ANIMACIÓN SEGÚN ARMA
func _get_animation_suffix() -> String:
	var weapon_system = player.get_node_or_null("WeaponSystem") as WeaponSystem
	if not weapon_system:
		return ""
	
	var weapon = weapon_system.get_current_weapon()
	if not weapon:
		return ""
	
	# Sufijos según arma
	match weapon.weapon_id:
		"scythe":
			return "_scythe"
		"spectral_hands":
			return ""  # Animaciones base
		_:
			return ""


func _restore_movement_animation() -> void:
	_update_movement_animation()

# Iniciar dash dentro del estado de curación
func _start_dash() -> void:
	if is_dashing:
		print("⚠️ Ya estás dasheando")
		return
	
	print("💨 Dash ejecutado (manteniendo curación)")
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	
	# Obtener dirección
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
			dash_cooldown = active_dash.cooldown
			dash_timer = dash_duration
			dash_cooldown_timer = dash_cooldown
	
	# Aplicar velocidad
	player.velocity = dash_direction * dash_speed
	player.invulnerable = true

# Procesar dash mientras está en HealState
func _process_dash(delta: float) -> void:
	dash_timer -= delta
	
	player.velocity.x = dash_direction.x * dash_speed
	player.velocity.y = 0
	
	player.move_and_slide()
	
	# Terminar dash
	if dash_timer <= 0:
		print("✅ Dash terminado - Curación continúa")
		is_dashing = false
		player.invulnerable = false
		player.velocity.x = 0

func _start_attack() -> void:
	if is_attacking:
		return
	
	is_attacking = true
	attack_animation_timer = attack_duration
	attack_hitbox_timer = attack_duration
	attack_cooldown_timer = attack_cooldown
	
	var attack_component = player.get_node_or_null("AttackComponent")
	if attack_component:
		player.current_attack_direction = attack_component.get_attack_direction()
	
	_activate_hitbox()
	
	# 🆕 REPRODUCIR ANIMACIÓN DE ATAQUE CON ARMA
	if player.sprite:
		var anim_suffix = _get_animation_suffix()
		var attack_anim = "attack" + anim_suffix
		
		# Intentar animación con arma, si no existe usar la base
		if player.sprite.sprite_frames.has_animation(attack_anim):
			player.sprite.play(attack_anim)
		elif player.sprite.sprite_frames.has_animation("attack"):
			player.sprite.play("attack")

func _activate_hitbox() -> void:
	if player.attack_hitbox and not hitbox_active:
		# ✅ USAR set_deferred PARA EVITAR BLOQUEO
		player.attack_hitbox.set_deferred("monitoring", true)
		hitbox_active = true

func _deactivate_hitbox() -> void:
	if player.attack_hitbox and hitbox_active:
		# ✅ USAR set_deferred PARA EVITAR BLOQUEO
		player.attack_hitbox.set_deferred("monitoring", false)
		hitbox_active = false

func register_hit() -> void:
	
	if not hitbox_active or ending_healing:
		return
	
	print("🎯 register_hit() aceptado")
	
	var health_component = player.get_node_or_null("HealthComponent") as HealthComponent
	if health_component and player.health < player.max_health:
		var old_health = player.health
		player.health = min(player.max_health, player.health + heal_per_hit)
		health_component._update_health_bar()
		
		var healed = player.health - old_health
		if healed > 0:
			print("💚 +", healed, " HP | Golpes: ", hits_remaining - 1)
	
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
	attack_hitbox_timer = 0.0
	attack_cooldown_timer = 0.0
	attack_requested = false
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	
	# ✅ DESACTIVAR HITBOX CON set_deferred
	if player.attack_hitbox:
		player.attack_hitbox.set_deferred("monitoring", false)
		hitbox_active = false
	
	# 🆕 DESACTIVAR AURA VÍA VFXManager
	var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
	if vfx_manager:
		vfx_manager.deactivate_healing_aura()
		print("❌ Aura de curación desactivada")

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
	
	# ✅ DESACTIVAR HITBOX CON set_deferred
	if player.attack_hitbox:
		player.attack_hitbox.set_deferred("monitoring", false)
	
	player.is_jumping = false
	player.active_healing_fragment = null
	
	# 🆕 ASEGURAR QUE EL AURA SE DESACTIVE
	var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
	if vfx_manager:
		vfx_manager.deactivate_healing_aura()
	
	is_attacking = false
	attack_animation_timer = 0.0
	attack_hitbox_timer = 0.0
	attack_cooldown_timer = 0.0
	hitbox_active = false
	ending_healing = false
	attack_requested = false
	end_transition_delay = 0.0
	is_dashing = false
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
