extends EnemyBase
class_name FungusIA

# Movimiento
@export_group("Movimiento")
@export var velocidad: float = 50.0
@export var gravity: float = 1000.0
@export var max_fall_speed: float = 2000.0

# Raycasts
@export_group("Detección")
@export var ground_check_x: float = 15.0
@export var ground_check_y: float = 30.0
@export var wall_check_x: float = 12.0
@export var flip_cooldown: float = 0.2
@export var debug_raycasts: bool = false

var flip_cooldown_timer: float = 0.0
var dir: int = -1

# Nodos
@onready var ground_check: RayCast2D = get_node_or_null("GroundCheck") as RayCast2D
@onready var wall_check: RayCast2D = get_node_or_null("WallCheck") as RayCast2D
@onready var hitbox: Area2D = get_node_or_null("Hitbox") as Area2D

# Daño al jugador
@export_group("Ataque")
@export var damage: int = 1
@export var player_knockback: Vector2 = Vector2(100, -80)
@export var damage_cooldown: float = 0.5
@export var continuous_damage: bool = true
var _last_damage_time: float = -999.0

func _enemy_ready() -> void:
	if sprite:
		sprite.play("run")
	velocity.x = dir * velocidad
	
	if ground_check:
		ground_check.enabled = true
		print("✅ GroundCheck activado")
	else:
		push_warning("❌ GroundCheck NO encontrado")
	
	if wall_check:
		wall_check.enabled = true
		print("✅ WallCheck activado")
	else:
		push_warning("❌ WallCheck NO encontrado")
	
	if hitbox:
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
		print("✅ Hitbox conectado")
	else:
		push_warning("❌ Hitbox NO encontrado")
	
	print("🍄 Fungus inicializado - Dir: ", dir, " | Velocidad: ", velocidad)

func _enemy_physics_process(delta: float) -> void:
	# Gravedad
	velocity.y += gravity * delta
	if velocity.y > max_fall_speed:
		velocity.y = max_fall_speed
	
	# Si está stunned, solo moverse
	if is_stunned:
		move_and_slide()
		return
	
	# Comportamiento de patrulla
	_patrol_behavior(delta)
	
	move_and_slide()
	
	# Flip sprite según dirección
	# AJUSTA ESTO: Si tu sprite está al revés, cambia > por 
	if sprite:
		sprite.flip_h = dir > 0  # Si mira al lado contrario, cambia a: dir < 0
	
	# Daño continuo
	if continuous_damage and hitbox:
		_check_continuous_damage()

func _patrol_behavior(delta: float) -> void:
	# Cooldown de flip
	if flip_cooldown_timer > 0.0:
		flip_cooldown_timer -= delta
	
	# Orientar raycasts según dirección
	if ground_check:
		ground_check.target_position = Vector2(dir * ground_check_x, ground_check_y)
	if wall_check:
		wall_check.target_position = Vector2(dir * wall_check_x, 0)
	
	# Comprobar suelo adelante y pared adelante
	var ground_ahead: bool = ground_check != null and ground_check.is_colliding()
	var wall_ahead: bool = wall_check != null and wall_check.is_colliding()
	
	# 🐛 DEBUG (comentado para evitar spam)
	# if debug_raycasts:
	# 	print("Dir: ", dir, " | Suelo: ", ground_ahead, " | Pared: ", wall_ahead, " | Cooldown: ", flip_cooldown_timer)
	
	# Girar si no hay suelo o hay pared (sin sistema de distancia)
	if (not ground_ahead or wall_ahead) and flip_cooldown_timer <= 0.0:
		dir *= -1
		flip_cooldown_timer = flip_cooldown
		
		# 🐛 DEBUG (comentado para evitar spam)
		# if debug_raycasts:
		# 	print("🔄 Girando a dir: ", dir)
	
	# Aplicar velocidad constante
	velocity.x = dir * velocidad

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body == null or not body.is_in_group("Player"):
		return
	
	_try_damage_player(body)

func _try_damage_player(body: Node2D) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_damage_time < damage_cooldown:
		return
	_last_damage_time = now
	
	# Buscar el HealthComponent
	var health_component = body.get_node_or_null("HealthComponent")
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(damage, player_knockback, global_position)
	elif body.has_method("take_damage"):
		body.take_damage(damage, player_knockback, global_position)

func _check_continuous_damage() -> void:
	if not hitbox:
		return
	
	var overlapping_bodies = hitbox.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("Player"):
			_try_damage_player(body)
			return

func _on_die() -> void:
	pass
