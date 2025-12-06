# res://scripts/player/components/AttackComponent.gd
extends Node
class_name AttackComponent

## ============================================
## ATTACK COMPONENT - VERSIÓN ARREGLADA
## ============================================

var player: Player

# Referencias a hitboxes
var ground_hitbox: Area2D = null
var air_hitbox: Area2D = null
var pogo_hitbox: Area2D = null
var launcher_hitbox: Area2D = null

# Estado actual
var current_active_hitbox: Area2D = null
var is_attacking: bool = false
var enemies_hit_this_attack: Array = []  # 🆕 Evitar golpear múltiples veces

func _ready() -> void:
	await get_tree().process_frame
	
	player = get_parent() as Player
	
	if not player:
		push_error("AttackComponent debe ser hijo de un Player")
		return
	
	# Buscar y conectar hitboxes
	_find_all_hitboxes()
	_connect_all_hitboxes()
	
	print("✅ AttackComponent inicializado")
	_print_hitbox_status()

# ============================================
# 🔍 BUSCAR Y CONECTAR HITBOXES
# ============================================

func _find_all_hitboxes() -> void:
	var hitbox_container = player.get_node_or_null("HitboxContainer")
	
	if not hitbox_container:
		push_warning("⚠️ HitboxContainer no encontrado")
		return
	
	ground_hitbox = hitbox_container.get_node_or_null("GroundAttackHitbox")
	air_hitbox = hitbox_container.get_node_or_null("AirAttackHitbox")
	pogo_hitbox = hitbox_container.get_node_or_null("PogoHitbox")
	launcher_hitbox = hitbox_container.get_node_or_null("LauncherHitbox")
	
	# Los hitboxes ya están disabled por defecto en el .tscn
	# AnimationPlayer los activará cuando sea necesario

func _connect_all_hitboxes() -> void:
	if ground_hitbox:
		if not ground_hitbox.body_entered.is_connected(_on_ground_hitbox_entered):
			ground_hitbox.body_entered.connect(_on_ground_hitbox_entered)
		print("  ✅ GroundHitbox conectado")
	
	if air_hitbox:
		if not air_hitbox.body_entered.is_connected(_on_air_hitbox_entered):
			air_hitbox.body_entered.connect(_on_air_hitbox_entered)
		print("  ✅ AirHitbox conectado")
	
	if pogo_hitbox:
		if not pogo_hitbox.body_entered.is_connected(_on_pogo_hitbox_entered):
			pogo_hitbox.body_entered.connect(_on_pogo_hitbox_entered)
		print("  ✅ PogoHitbox conectado")
	
	if launcher_hitbox:
		if not launcher_hitbox.body_entered.is_connected(_on_launcher_hitbox_entered):
			launcher_hitbox.body_entered.connect(_on_launcher_hitbox_entered)
		print("  ✅ LauncherHitbox conectado")

func _print_hitbox_status() -> void:
	print("  📦 Hitboxes encontrados:")
	print("    Ground: ", ground_hitbox != null)
	print("    Air: ", air_hitbox != null)
	print("    Pogo: ", pogo_hitbox != null)
	print("    Launcher: ", launcher_hitbox != null)

# ============================================
# 🎯 CALLBACKS DE HITBOXES
# ============================================
# Las señales body_entered de los hitboxes llaman a estas funciones
# Los hitboxes se activan/desactivan SOLO por AnimationPlayer tracks

func _on_ground_hitbox_entered(body: Node2D) -> void:
	print("🎯 GroundHitbox detectó: ", body.name)
	_handle_hit(body, "ground")

func _on_air_hitbox_entered(body: Node2D) -> void:
	print("🎯 AirHitbox detectó: ", body.name)
	_handle_hit(body, "air")

func _on_pogo_hitbox_entered(body: Node2D) -> void:
	print("🎯 PogoHitbox detectó: ", body.name)
	_handle_hit(body, "pogo")

func _on_launcher_hitbox_entered(body: Node2D) -> void:
	print("🎯 LauncherHitbox detectó: ", body.name)
	_handle_hit(body, "launcher")

# ============================================
# 💥 PROCESAR GOLPE
# ============================================

func _handle_hit(body: Node2D, attack_type: String) -> void:
	if not body.is_in_group("enemies"):
		return
	
	if not body.has_method("take_damage"):
		return
	
	# 🆕 EVITAR GOLPEAR MÚLTIPLES VECES
	if body in enemies_hit_this_attack:
		return
	
	enemies_hit_this_attack.append(body)
	
	print("💥 Golpe registrado [", attack_type, "] a ", body.name)
	
	# Calcular daño
	var damage_result = _calculate_damage()
	var final_damage = damage_result["damage"]
	var is_critical = damage_result["is_critical"]
	
	if is_critical:
		print("  ⚡ CRÍTICO! Daño: ", final_damage)
	
	# Calcular knockback
	var knockback = _calculate_knockback(body, attack_type)
	
	# Aplicar daño (solo 2 parámetros: damage y knockback)
	body.take_damage(final_damage, knockback)
	
	# Efectos especiales según tipo
	_apply_special_effects(body, attack_type)
	
	# Life steal en críticos
	if is_critical and player.lifesteal_on_crit > 0:
		_apply_lifesteal(final_damage)
	
	# Camera shake
	_apply_camera_shake(is_critical)
	
	# Registrar en HealState si está curándose
	var state_machine = player.get_node_or_null("StateMachine")
	if state_machine and state_machine.current_state is HealState:
		state_machine.current_state.register_hit()

# ============================================
# 📊 CÁLCULOS
# ============================================

func _calculate_damage() -> Dictionary:
	var weapon = player.get_current_weapon()
	var base_damage = weapon.base_damage if weapon else player.base_attack_damage
	
	# 🐛 DEBUG
	print("🔍 DEBUG _calculate_damage:")
	print("  Weapon: ", weapon)
	if weapon:
		print("  Weapon base_damage: ", weapon.base_damage)
	print("  Player base_attack_damage: ", player.base_attack_damage)
	print("  Calculated base_damage: ", base_damage)
	
	var total_crit_chance = player.base_crit_chance
	if weapon:
		total_crit_chance += weapon.crit_chance_bonus
	
	var is_crit = randf() < total_crit_chance
	
	var final_damage = base_damage
	if is_crit:
		var crit_mult = player.base_crit_multiplier
		if weapon:
			crit_mult += weapon.crit_multiplier_bonus
		final_damage = int(base_damage * crit_mult)
	
	print("  Final damage: ", final_damage)
	print("  Is critical: ", is_crit)
	
	return {
		"damage": final_damage,
		"is_critical": is_crit
	}

func _calculate_knockback(body: Node2D, attack_type: String) -> Vector2:
	var knockback = Vector2.ZERO
	
	match attack_type:
		"ground":
			knockback = Vector2(200, -100)
		"air":
			knockback = Vector2(150, -150)
		"pogo":
			knockback = Vector2(0, 300)
		"launcher":
			knockback = Vector2(0, -400)
	
	var dir = (body.global_position - player.global_position).normalized()
	knockback.x = abs(knockback.x) * sign(dir.x)
	
	return knockback

# ============================================
# ✨ EFECTOS ESPECIALES
# ============================================

func _apply_special_effects(_body: Node2D, attack_type: String) -> void:
	match attack_type:
		"pogo":
			# Rebote del player
			player.velocity.y = -400.0
			player.hit_enemy_with_down_attack = true
			print("  🦘 POGO BOUNCE!")
		
		"launcher":
			# Impulsar al player
			player.velocity.y = -300
			print("  🚀 LAUNCHER!")

func _apply_lifesteal(damage: int) -> void:
	var health_component = player.get_health_component()
	
	if health_component and player.health < player.max_health:
		var heal_amount = max(1, int(damage * 0.2))
		health_component.heal(heal_amount)
		print("  💚 Life Steal: +", heal_amount, " HP")

func _apply_camera_shake(is_critical: bool) -> void:
	var camera = player.get_node_or_null("Camera2D") as CameraController
	if camera and camera.has_method("shake_camera"):
		var intensity = 20.0 if is_critical else 10.0
		camera.shake_camera(intensity, 0.2)

# ============================================
# 🎮 API PÚBLICA
# ============================================

## Detectar dirección de ataque según input
func get_attack_direction() -> Player.AttackDirection:
	if Input.is_action_pressed("ui_up"):
		return Player.AttackDirection.UP
	elif Input.is_action_pressed("ui_down") and not player.is_on_floor():
		var weapon = player.get_current_weapon()
		if weapon and weapon.weapon_id == "scythe":
			return Player.AttackDirection.DOWN
		else:
			return Player.AttackDirection.FORWARD
	else:
		return Player.AttackDirection.FORWARD

## Verificar si está atacando
func is_currently_attacking() -> bool:
	return is_attacking
