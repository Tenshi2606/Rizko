# res://scripts/player/components/AttackComponent.gd
extends Node
class_name AttackComponent

var player: Player

func _ready() -> void:
	await get_tree().process_frame
	
	player = get_parent() as Player
	
	if not player:
		push_error("AttackComponent debe ser hijo de un Player")
		return
	
	if player.attack_hitbox:
		player.attack_hitbox.monitoring = false
		if not player.attack_hitbox.body_entered.is_connected(_on_attack_hitbox_body_entered):
			player.attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)

func _physics_process(_delta: float) -> void:
	if player:
		update_hitbox_position()

# ============================================
# 🆕 ACTUALIZAR POSICIÓN (SIN DEBUG)
# ============================================

func update_hitbox_position() -> void:
	if not player or not player.attack_hitbox:
		return
	
	var collision_shape = player.attack_hitbox.get_node_or_null("CollisionShape2D")
	
	var weapon = player.get_current_weapon()
	var offset = weapon.attack_range if weapon else 25.0
	
	match player.current_attack_direction:
		Player.AttackDirection.FORWARD:
			if player.sprite.flip_h:
				player.attack_hitbox.position = Vector2(-offset, 0)
			else:
				player.attack_hitbox.position = Vector2(offset, 0)
			
			if collision_shape:
				collision_shape.rotation_degrees = 0
		
		Player.AttackDirection.UP:
			player.attack_hitbox.position = Vector2(0, -offset)
			
			if collision_shape:
				collision_shape.rotation_degrees = 90
		
		Player.AttackDirection.DOWN:
			player.attack_hitbox.position = Vector2(0, offset)
			
			if collision_shape:
				collision_shape.rotation_degrees = 90

func get_attack_direction() -> Player.AttackDirection:
	if Input.is_action_pressed("ui_up"):
		return Player.AttackDirection.UP
	elif Input.is_action_pressed("ui_down") and not player.is_on_floor():
		# 🆕 Solo permitir ataque hacia abajo si tiene la Guadaña
		var weapon = player.get_current_weapon()
		if weapon and weapon.weapon_id == "scythe":
			return Player.AttackDirection.DOWN
		else:
			return Player.AttackDirection.FORWARD  # Manos atacan horizontal
	else:
		return Player.AttackDirection.FORWARD

# ============================================
# CALLBACK DE HITBOX
# ============================================

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("enemies"):
		return
	
	if not body.has_method("take_damage"):
		return
	
	# 🆕 POGO SOLO PARA GUADAÑA
	if player.current_attack_direction == Player.AttackDirection.DOWN:
		player.hit_enemy_with_down_attack = true
		
		# Solo aplicar pogo si tiene la Guadaña equipada
		var weapon = player.get_current_weapon()
		if weapon and weapon.weapon_id == "scythe":
			player.velocity.y = player.pogo_bounce_force
	
	# Calcular daño con críticos
	var damage_result = _calculate_damage()
	var final_damage = damage_result["damage"]
	var is_critical = damage_result["is_critical"]
	
	# 🎯 EMITIR EVENTO DE ATAQUE
	EventBus.enemy_attacked.emit(final_damage, body, player)
	
	# Aplicar daño
	var knockback = _calculate_knockback(body)
	body.take_damage(final_damage, knockback)
	
	# 🆕 HIT FREEZE al golpear (congelar pantalla brevemente)
	_apply_hit_freeze(is_critical)
	
	# 🆕 RETROCESO AL GOLPEAR (DESPUÉS de aplicar daño)
	_apply_attack_recoil()
	
	# Efecto visual de impacto
	_show_attack_impact(body.global_position)
	
	# Life steal en crítico
	if is_critical and player.lifesteal_on_crit > 0:
		_apply_lifesteal()
	
	# Feedback visual de crítico
	if is_critical:
		_show_critical_feedback(body)
	
	# Notificar al HealState si está activo
	var state_machine = player.get_node_or_null("StateMachine")
	if state_machine and state_machine.current_state:
		if state_machine.current_state is HealState:
			var heal_state = state_machine.current_state as HealState
			heal_state.register_hit()

# ============================================
# 🆕 RETROCESO AL GOLPEAR (ESTILO HOLLOW KNIGHT)
# ============================================

func _apply_attack_recoil() -> void:
	var weapon = player.get_current_weapon()
	if not weapon:
		return
	
	# Retroceso hacia atrás al golpear (como Hollow Knight)
	if player.current_attack_direction == Player.AttackDirection.FORWARD:
		var knockback_force = 120.0 if weapon.weapon_id == "scythe" else 80.0
		# Aplicar en dirección OPUESTA a donde mira el sprite
		if player.sprite.flip_h:
			player.velocity.x += knockback_force  # Mira izquierda, empujar a la derecha
		else:
			player.velocity.x -= knockback_force  # Mira derecha, empujar a la izquierda

# ============================================
# CALCULAR DAÑO
# ============================================

func _calculate_damage() -> Dictionary:
	var base_damage = player.attack_damage
	var is_crit = randf() < player.crit_chance
	
	var final_damage = base_damage
	if is_crit:
		final_damage = int(base_damage * player.crit_multiplier)
	
	return {
		"damage": final_damage,
		"is_critical": is_crit
	}

func _apply_lifesteal() -> void:
	var health_component = player.get_node_or_null("HealthComponent") as HealthComponent
	
	if health_component and player.health < player.max_health:
		var old_health = player.health
		player.health = min(player.max_health, player.health + player.lifesteal_on_crit)
		health_component._update_health_bar()
		
		var healed = player.health - old_health
		if healed > 0 and player.sprite:
			player.sprite.modulate = Color(0.3, 1, 0.3)
			await get_tree().create_timer(0.1).timeout
			if is_instance_valid(player) and player.sprite:
				player.sprite.modulate = Color(1, 1, 1)

func _show_critical_feedback(enemy: Node2D) -> void:
	var enemy_sprite = enemy.get_node_or_null("AnimatedSprite2D")
	if enemy_sprite:
		enemy_sprite.modulate = Color(1, 1, 0)
		await get_tree().create_timer(0.15).timeout
		if is_instance_valid(enemy) and enemy_sprite:
			enemy_sprite.modulate = Color(1, 1, 1)

func _show_attack_impact(hit_position: Vector2) -> void:
	var vfx_manager = player.get_node_or_null("VFXManager") as VFXManager
	if not vfx_manager:
		return
	
	var offset = hit_position - player.global_position
	var direction = (hit_position - player.global_position).normalized()
	
	vfx_manager.play_attack_impact(offset, direction)

func _calculate_knockback(enemy: Node2D) -> Vector2:
	var weapon = player.get_current_weapon()
	var knockback_force = weapon.knockback_force if weapon else Vector2(400, -200)
	
	match player.current_attack_direction:
		Player.AttackDirection.FORWARD:
			var direction = (enemy.global_position - player.global_position).normalized()
			return Vector2(
				direction.x * knockback_force.x,
				knockback_force.y
			)
		
		Player.AttackDirection.UP:
			return Vector2(0, -knockback_force.x * 0.8)
		
		Player.AttackDirection.DOWN:
			return Vector2(0, knockback_force.x * 0.6)
	
	return Vector2.ZERO

# ============================================
# 🆕 HIT FREEZE (CONGELAR PANTALLA AL GOLPEAR)
# ============================================

func _apply_hit_freeze(is_critical: bool = false) -> void:
	# 🆕 Usar FreezeManager centralizado
	if is_critical:
		FreezeManager.apply_hit_freeze_critical()
	else:
		FreezeManager.apply_hit_freeze_normal()
