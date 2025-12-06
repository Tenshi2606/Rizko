# res://scripts/player/components/WeaponSystem.gd
extends Node
class_name WeaponSystem

signal weapon_equipped(weapon: WeaponData)
signal weapon_unlocked(weapon: WeaponData)
signal weapon_changed(old_weapon: WeaponData, new_weapon: WeaponData)
signal projectile_fired(projectile: Node2D)

var player: Player
var unlocked_weapons: Dictionary = {}
var current_weapon: WeaponData = null
var current_weapon_index: int = 0
var available_weapons: Array[WeaponData] = []

# Cooldown de disparo
var fire_cooldown: float = 0.0
var burst_shots_remaining: int = 0
var burst_timer: float = 0.0

# Sistema de recarga
var current_ammo: int = 3
var max_ammo: int = 3
var is_reloading: bool = false
var reload_timer: float = 0.0
var reload_duration: float = 2.5

# 🆕 REFERENCIA AL MARKER2D (no crearlo, buscarlo)
var projectile_spawn: Marker2D = null

# Sprite de las manos
var hand_sprite: Sprite2D = null

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("WeaponSystem debe ser hijo de un Player")
		return
	
	# Obtener sprite de manos
	hand_sprite = player.get_node_or_null("HandSprite") as Sprite2D
	
	# 🆕 BUSCAR MARKER2D EXISTENTE (no crearlo)
	projectile_spawn = player.get_node_or_null("ProjectileSpawn") as Marker2D
	
	if not projectile_spawn:
		# Solo mostrar en debug builds (normal para armas melee)
		if OS.is_debug_build():
			print("ℹ️ ProjectileSpawn no encontrado (normal para armas melee)")
	else:
		print("  ✅ ProjectileSpawn encontrado en posición: ", projectile_spawn.position)
	
	# Jugador empieza sin arma - debe recoger una
	# var default_weapon = null
	# if default_weapon:
	# 	unlock_weapon(default_weapon, false)
	# 	equip_weapon(default_weapon)
	
	print("🗡️ WeaponSystem inicializado")

# ============================================
# 🆕 ACTUALIZAR POSICIÓN DEL SPAWN (SOLO FLIP)
# ============================================

func _process(delta: float) -> void:
	# Actualizar cooldown de disparo
	if fire_cooldown > 0:
		fire_cooldown -= delta
	
	# Manejar ráfaga
	if burst_shots_remaining > 0:
		burst_timer -= delta
		if burst_timer <= 0:
			_fire_burst_shot()
	
	# Manejar recarga
	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0:
			_finish_reload()
	
	# 🆕 FLIP HORIZONTAL DEL SPAWN SEGÚN DIRECCIÓN
	if projectile_spawn and player and player.sprite:
		# Solo invertir X, mantener Y fijo
		var base_x = abs(projectile_spawn.position.x)
		projectile_spawn.position.x = -base_x if player.sprite.flip_h else base_x

# ============================================
# DESBLOQUEAR Y EQUIPAR ARMAS
# ============================================

func unlock_weapon(weapon: WeaponData, notify: bool = true) -> bool:
	if not weapon:
		return false
	
	if unlocked_weapons.has(weapon.weapon_id):
		return false
	
	unlocked_weapons[weapon.weapon_id] = weapon
	available_weapons.append(weapon)
	
	if notify:
		weapon_unlocked.emit(weapon)
		_show_weapon_unlock_notification(weapon)
		
		# 🎯 EMITIR EVENTO A EVENTBUS
		EventBus.weapon_changed.emit(null, weapon)
	
	return true

func equip_weapon(weapon: WeaponData) -> void:
	if not weapon or not unlocked_weapons.has(weapon.weapon_id):
		return
	
	var old_weapon = current_weapon
	current_weapon = weapon
	current_weapon_index = available_weapons.find(weapon)
	
	_change_hand_sprite()
	_apply_weapon_stats()
	
	# 🆕 ACTUALIZAR HITBOX SOLO AL CAMBIAR ARMA
	# _update_attack_hitbox()  # TODO: Migrar a AnimationPlayer
	
	weapon_equipped.emit(weapon)
	if old_weapon:
		weapon_changed.emit(old_weapon, weapon)
		
	# 🎯 EMITIR EVENTO A EVENTBUS
	EventBus.weapon_changed.emit(old_weapon, weapon)

func cycle_weapon(direction: int = 1) -> void:
	if available_weapons.size() <= 1:
		return
	
	current_weapon_index = (current_weapon_index + direction) % available_weapons.size()
	if current_weapon_index < 0:
		current_weapon_index = available_weapons.size() - 1
	
	equip_weapon(available_weapons[current_weapon_index])

# ============================================
# 🆕 ACTUALIZAR HITBOX (SOLO AL CAMBIAR ARMA)
# ============================================

# TODO: Esta función usa el viejo sistema de attack_hitbox
# Ahora los hitboxes se manejan via AnimationPlayer
# func _update_attack_hitbox() -> void:
# 	if not player or not player.attack_hitbox:
# 		return
# 	
# 	var collision_shape = player.attack_hitbox.get_node_or_null("CollisionShape2D")
# 	if not collision_shape or not current_weapon:
# 		return
# 	
# 	var shape = collision_shape.shape
# 	if not shape:
# 		return
# 	
# 	# Ajustar tamaño según rango del arma
# 	if shape is RectangleShape2D:
# 		var rect_shape = shape as RectangleShape2D
# 		var size_multiplier = current_weapon.attack_range / 25.0
# 		rect_shape.size = Vector2(30 * size_multiplier, 30 * size_multiplier)
# 	elif shape is CircleShape2D:
# 		var circle_shape = shape as CircleShape2D
# 		var radius_multiplier = current_weapon.attack_range / 25.0
# 		circle_shape.radius = 15 * radius_multiplier

func _change_hand_sprite() -> void:
	if not hand_sprite or not current_weapon:
		return
	
	if current_weapon.hand_sprite.is_empty():
		return
	
	var texture = load(current_weapon.hand_sprite) as Texture2D
	if texture:
		hand_sprite.texture = texture

func get_current_weapon() -> WeaponData:
	return current_weapon

func has_weapon(weapon_id: String) -> bool:
	return unlocked_weapons.has(weapon_id)

func can_fire() -> bool:
	return fire_cooldown <= 0

# ============================================
# DISPARAR
# ============================================

func fire_projectile(direction: Vector2) -> void:
	if not current_weapon or not current_weapon.has_projectile:
		return
	
	if is_reloading:
		return
	
	# Verificar munición (solo M16)
	if current_weapon.weapon_id == "m16":
		if current_ammo <= 0:
			start_reload()
			return
	
	if not can_fire():
		return
	
	# Freeze aéreo (solo M16)
	if current_weapon.weapon_id == "m16" and player.can_aerial_freeze():
		player.start_aerial_freeze(0.8)
	
	# Consumir munición (solo M16)
	if current_weapon.weapon_id == "m16":
		current_ammo -= 1
	
	# Iniciar ráfaga
	if current_weapon.burst_count > 1:
		burst_shots_remaining = current_weapon.burst_count
		burst_timer = 0.0
		_fire_burst_shot()
	else:
		_spawn_projectile(direction)
		fire_cooldown = current_weapon.fire_rate

func _fire_burst_shot() -> void:
	if burst_shots_remaining <= 0:
		return
	
	var direction = Vector2.RIGHT
	if player.sprite:
		direction = Vector2.RIGHT if not player.sprite.flip_h else Vector2.LEFT
	_spawn_projectile(direction)
	
	burst_shots_remaining -= 1
	
	if burst_shots_remaining > 0:
		burst_timer = current_weapon.burst_delay
	else:
		fire_cooldown = current_weapon.fire_rate

# ============================================
# 🔥 SPAWN PROYECTIL (DESDE MARKER2D)
# ============================================

func _spawn_projectile(direction: Vector2) -> void:
	if not current_weapon.projectile_scene:
		return
	
	var projectile = current_weapon.projectile_scene.instantiate()
	
	if not projectile is Projectile:
		projectile.queue_free()
		return
	
	# 🔥 USAR POSICIÓN GLOBAL DEL MARKER2D
	if projectile_spawn:
		projectile.global_position = projectile_spawn.global_position
	else:
		# Fallback si no hay Marker2D (centro del player)
		projectile.global_position = player.global_position
	
	get_tree().current_scene.add_child(projectile)
	
	# Configurar proyectil
	projectile.direction = direction.normalized()
	projectile.speed = current_weapon.projectile_speed
	projectile.damage = float(player.attack_damage)
	
	# DOT
	if current_weapon.has_dot:
		projectile.has_dot = true
		projectile.dot_damage = current_weapon.dot_damage
		projectile.dot_duration = current_weapon.dot_duration
	
	# Piercing
	if current_weapon.projectile_piercing:
		projectile.piercing = true
	
	projectile_fired.emit(projectile)

# ============================================
# APLICAR STATS DEL ARMA
# ============================================

func _apply_weapon_stats() -> void:
	if not player or not current_weapon:
		return
	
	# 🆕 APLICAR STATS DESDE EL INSPECTOR DEL PLAYER (base)
	# + bonus del arma actual
	player.attack_damage = int(current_weapon.base_damage)
	player.attack_knockback_force = current_weapon.knockback_force
	player.attack_duration = 0.3 / current_weapon.attack_speed_multiplier
	
	player.crit_chance = player.base_crit_chance + current_weapon.crit_chance_bonus
	player.crit_multiplier = player.base_crit_multiplier + current_weapon.crit_multiplier_bonus
	player.lifesteal_on_crit = player.base_lifesteal + current_weapon.lifesteal_bonus

func can_break_obstacle(obstacle_type: WeaponData.BreakableType) -> bool:
	if not current_weapon:
		return false
	
	return current_weapon.can_break == obstacle_type

func _show_weapon_unlock_notification(weapon: WeaponData) -> void:
	print("\n🔥 ARMA ABSORBIDA: ", weapon.weapon_name)
	print("  ", weapon.description)

# ============================================
# SISTEMA DE RECARGA
# ============================================

func start_reload() -> void:
	if is_reloading or current_ammo >= max_ammo:
		return
	
	is_reloading = true
	reload_timer = reload_duration

func _finish_reload() -> void:
	is_reloading = false
	current_ammo = max_ammo

func can_reload() -> bool:
	return not is_reloading and current_ammo < max_ammo

func get_ammo_info() -> Dictionary:
	return {
		"current": current_ammo,
		"max": max_ammo,
		"is_reloading": is_reloading,
		"reload_progress": 1.0 - (reload_timer / reload_duration) if is_reloading else 1.0
	}

func cancel_reload() -> void:
	if not is_reloading:
		return
	
	is_reloading = false
	reload_timer = 0.0

# ============================================
# GUARDADO
# ============================================

func serialize() -> Dictionary:
	return {
		"unlocked_weapons": unlocked_weapons.keys(),
		"current_weapon": current_weapon.weapon_id if current_weapon else ""
	}

func deserialize(data: Dictionary) -> void:
	if data.has("unlocked_weapons"):
		for weapon_id in data["unlocked_weapons"]:
			var weapon = WeaponDB.get_weapon(weapon_id)
			if weapon:
				unlock_weapon(weapon, false)
	
	if data.has("current_weapon") and not data["current_weapon"].is_empty():
		var weapon = WeaponDB.get_weapon(data["current_weapon"])
		if weapon:
			equip_weapon(weapon)
