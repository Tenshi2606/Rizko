extends StaticBody2D
class_name BreakableWall

## ============================================
## MURO ROMPIBLE
## ============================================
## Se rompe solo con Guadaña Espectral
## Requiere 3-4 golpes
## Persiste al romperse

@export_group("Identificación")
@export var wall_id: String = ""

@export_group("Resistencia")
@export var max_hits: int = 3
@export var required_weapon: String = "scythe"  # Solo guadaña

@export_group("Efectos")
@export var shake_intensity: float = 5.0
@export var shake_duration: float = 0.1

# Referencias
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

# Estado
var current_hits: int = 0
var is_broken: bool = false
var shake_timer: float = 0.0
var original_position: Vector2

# 🆕 Cooldown para evitar múltiples golpes
var hit_cooldown: float = 0.0
var hit_cooldown_duration: float = 0.3

# Efectos
var crack_overlay: Sprite2D = null
var dust_particles: CPUParticles2D = null

# 🆕 Referencia al player
var player_hitbox: Area2D = null

func _ready() -> void:
	# Generar ID único si no tiene
	if wall_id == "":
		var scene_name = get_tree().current_scene.name
		wall_id = scene_name + "_Wall_" + str(int(global_position.x)) + "_" + str(int(global_position.y))
	
	add_to_group("breakable_walls")
	
	original_position = sprite.position if sprite else position
	
	_create_crack_overlay()
	_create_dust_particles()
	
	# Verificar si ya está roto
	_check_if_broken()
	
	# 🆕 Conectar al hitbox del player
	_connect_to_player_hitbox()
	
	print("🧱 Muro rompible configurado: ", wall_id)

# 🆕 CONECTAR AL HITBOX DEL PLAYER
func _connect_to_player_hitbox() -> void:
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("Player") as Player
	if not player:
		print("  ⚠️ Player no encontrado")
		return
	
	player_hitbox = player.get_node_or_null("AttackHitbox") as Area2D
	if not player_hitbox:
		print("  ⚠️ AttackHitbox no encontrado en Player")
		return
	
	# Conectar a body_entered del hitbox
	if not player_hitbox.body_entered.is_connected(_on_player_attack_hit):
		player_hitbox.body_entered.connect(_on_player_attack_hit)
		print("  ✅ Conectado al AttackHitbox del player")

func _create_crack_overlay() -> void:
	crack_overlay = Sprite2D.new()
	crack_overlay.name = "CrackOverlay"
	crack_overlay.modulate = Color(0.2, 0.2, 0.2, 0.0)  # Negro transparente
	crack_overlay.z_index = 1
	
	if sprite:
		sprite.add_child(crack_overlay)
		# TODO: Asignar textura de grietas si tienes
		# crack_overlay.texture = load("res://assets/sprites/effects/cracks.png")

func _create_dust_particles() -> void:
	dust_particles = CPUParticles2D.new()
	dust_particles.name = "DustParticles"
	dust_particles.amount = 15
	dust_particles.lifetime = 1.0
	dust_particles.one_shot = true
	dust_particles.explosiveness = 1.0
	dust_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust_particles.emission_rect_extents = Vector2(16, 16)
	dust_particles.direction = Vector2(0, -1)
	dust_particles.spread = 45.0
	dust_particles.gravity = Vector2(0, 200)
	dust_particles.initial_velocity_min = 50.0
	dust_particles.initial_velocity_max = 120.0
	dust_particles.scale_amount_min = 1.0
	dust_particles.scale_amount_max = 2.5
	
	# Gradiente de color (polvo gris)
	var dust_gradient = Gradient.new()
	dust_gradient.add_point(0.0, Color(0.7, 0.7, 0.6, 1.0))
	dust_gradient.add_point(0.5, Color(0.5, 0.5, 0.4, 0.6))
	dust_gradient.add_point(1.0, Color(0.3, 0.3, 0.2, 0.0))
	dust_particles.color_ramp = dust_gradient
	
	dust_particles.emitting = false
	add_child(dust_particles)

func _check_if_broken() -> void:
	if SceneManager.is_wall_broken(wall_id):
		_break_wall_instant()

func _process(delta: float) -> void:
	# Sacudida
	if shake_timer > 0:
		shake_timer -= delta
		_apply_shake()
	else:
		if sprite:
			sprite.position = original_position
	
	# Cooldown de golpe
	if hit_cooldown > 0:
		hit_cooldown -= delta

# 🆕 CALLBACK CUANDO EL HITBOX DEL PLAYER GOLPEA UN BODY
func _on_player_attack_hit(body: Node2D) -> void:
	# Verificar que el body golpeado sea este muro
	if body != self:
		return
	
	if is_broken:
		return
	
	# Verificar cooldown
	if hit_cooldown > 0:
		return
	
	# Activar cooldown
	hit_cooldown = hit_cooldown_duration
	
	# Obtener el player
	var player = get_tree().get_first_node_in_group("Player") as Player
	if player:
		_on_hit_by_player(player)

func _on_hit_by_player(player: Player) -> void:
	var weapon_system = player.get_node_or_null("WeaponSystem") as WeaponSystem
	if not weapon_system:
		return
	
	var current_weapon = weapon_system.get_current_weapon()
	if not current_weapon:
		return
	
	var weapon_id = current_weapon.weapon_id
	
	print("🧱 Muro golpeado con: ", weapon_id)
	
	# Verificar si es la guadaña
	if weapon_id == required_weapon:
		_take_damage()
	else:
		# Otras armas solo sacuden el muro
		_shake_wall()
		print("  ⚠️ Solo la Guadaña Espectral puede romper este muro")

func _take_damage() -> void:
	current_hits += 1
	
	print("  💥 Golpe ", current_hits, "/", max_hits)
	
	# Efectos visuales
	_shake_wall()
	_play_dust_effect()
	_update_cracks()
	
	# Verificar si se rompe
	if current_hits >= max_hits:
		_break_wall()

func _shake_wall() -> void:
	shake_timer = shake_duration

func _apply_shake() -> void:
	if not sprite:
		return
	
	var shake_offset = Vector2(
		randf_range(-shake_intensity, shake_intensity),
		randf_range(-shake_intensity, shake_intensity)
	)
	sprite.position = original_position + shake_offset

func _play_dust_effect() -> void:
	if dust_particles:
		dust_particles.amount = 8  # Poco polvo al golpear
		dust_particles.restart()

func _update_cracks() -> void:
	if not crack_overlay:
		return
	
	# Aumentar opacidad de las grietas según daño
	var crack_alpha = float(current_hits) / float(max_hits)
	crack_overlay.modulate.a = crack_alpha * 0.8
	
	print("  🔨 Grietas: ", int(crack_alpha * 100), "%")

func _break_wall() -> void:
	print("💥 ¡Muro destruido!")
	
	is_broken = true
	
	# Registrar en SceneManager
	SceneManager.register_wall_broken(wall_id)
	
	# Efectos visuales finales
	_play_break_effect()
	
	# Desactivar colisión
	if collision:
		collision.set_deferred("disabled", true)
	
	# Hacer invisible el sprite
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
		await tween.finished
		sprite.visible = false
	
	# 🆕 Desconectar del hitbox
	if player_hitbox and player_hitbox.body_entered.is_connected(_on_player_attack_hit):
		player_hitbox.body_entered.disconnect(_on_player_attack_hit)

func _break_wall_instant() -> void:
	print("🧱 Muro ya estaba roto: ", wall_id)
	
	is_broken = true
	current_hits = max_hits
	
	# Desactivar todo inmediatamente
	if collision:
		collision.disabled = true
	
	if sprite:
		sprite.visible = false
	
	if crack_overlay:
		crack_overlay.visible = false

func _play_break_effect() -> void:
	if dust_particles:
		dust_particles.amount = 25  # Mucho polvo al romperse
		dust_particles.initial_velocity_min = 100.0
		dust_particles.initial_velocity_max = 200.0
		dust_particles.restart()
	
	# TODO: Sonido de ruptura
	print("  💨 Efecto de polvo activado")
