extends EnemyBase
class_name FlyingEnemy

@export_group("Movimiento")
@export var movement_speed: float = 100.0
@export var charge_speed: float = 250.0
@export var patrol_speed: float = 50.0

@export_group("Detección")
@export var detection_range: float = 300.0
@export var attack_range: float = 80.0

@export_group("Patrulla")
@export var patrol_enabled: bool = true
@export var patrol_distance: float = 150.0
@export var float_amplitude: float = 20.0  # Altura del movimiento ondulante
@export var float_frequency: float = 2.0   # Velocidad del movimiento ondulante

@export_group("Daño")
@export var contact_damage: int = 1  # Daño al tocar
@export var charge_damage: int = 2   # Daño al embestir
@export var damage_cooldown: float = 0.5  # 🆕 Cooldown entre daños
@export var continuous_damage: bool = true  # 🆕 Daño continuo

var _last_damage_time: float = -999.0  # 🆕 Último tiempo de daño

@export_group("Embestida")
@export var charge_cooldown: float = 1.5
@export var charge_duration: float = 1.0
@export var charge_preparation_time: float = 0.5

@export_group("Anti-Enganche")
@export var min_player_distance: float = 40.0  # Distancia mínima del player
@export var separation_force_multiplier: float = 8.0  # Fuerza de separación
@export var wall_bounce_multiplier: float = 0.6  # Retroceso al chocar con pared
@export var player_push_force: float = 300.0  # Fuerza al empujar al player

enum State { PATROL, IDLE, CHASE, PREPARE_CHARGE, CHARGING, COOLDOWN }

var current_state: State = State.PATROL
var player: Player = null
var patrol_start_pos: Vector2
var patrol_direction: int = 1
var charge_direction: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var float_time: float = 0.0

# Componentes
@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: Area2D = $Hitbox

func _enemy_ready() -> void:
	patrol_start_pos = global_position
	
	# Configurar áreas si no existen
	_setup_detection_area()
	_setup_hitbox()
	
	# Configurar colisión inicial (solo terreno)
	collision_mask = 0b0001
	
	print("🦇 FlyingEnemy listo: ", name)
	print("  Min Distance: ", min_player_distance)
	print("  Separation Force: ", separation_force_multiplier)

func _setup_detection_area() -> void:
	if not has_node("DetectionArea"):
		detection_area = Area2D.new()
		detection_area.name = "DetectionArea"
		add_child(detection_area)
		
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = detection_range
		collision.shape = shape
		detection_area.add_child(collision)
		
		detection_area.collision_layer = 0
	detection_area.collision_mask = 0b0100  # 🆕 Layer 3 (Player)
	
	detection_area.body_entered.connect(_on_detection_area_entered)
	detection_area.body_exited.connect(_on_detection_area_exited)

func _setup_hitbox() -> void:
	if not has_node("Hitbox"):
		hitbox = Area2D.new()
		hitbox.name = "Hitbox"
		add_child(hitbox)
		
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 16.0
		collision.shape = shape
		hitbox.add_child(collision)
	else:
		# Si ya existe, obtenerlo
		hitbox = get_node("Hitbox") as Area2D
	
	# SIEMPRE configurar las capas (aunque ya exista)
	if hitbox:
		hitbox.collision_layer = 0
		hitbox.collision_mask = 0b0100  # Layer 3 (Player)
		
		# Conectar señal si no está conectada
		if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
			hitbox.body_entered.connect(_on_hitbox_body_entered)
		
		print("🦇 Hitbox configurado:")
		print("  - Collision Layer: ", hitbox.collision_layer)
		print("  - Collision Mask: ", hitbox.collision_mask)
		print("  - Monitoring: ", hitbox.monitoring)

func _enemy_physics_process(delta: float) -> void:
	# No procesar si está stunned (EnemyBase maneja esto)
	if is_stunned:
		velocity = velocity.lerp(Vector2.ZERO, delta * 5.0)
		move_and_slide()
		return
	
	float_time += delta
	
	# 🆕 SEPARACIÓN DEL PLAYER (solo cuando NO está embistiendo)
	if current_state != State.CHARGING:
		_apply_separation_force(delta)
	
	# Procesar estado actual
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.IDLE:
			_process_idle(delta)
		State.CHASE:
			_process_chase(delta)
		State.PREPARE_CHARGE:
			_process_prepare_charge(delta)
		State.CHARGING:
			_process_charging(delta)
		State.COOLDOWN:
			_process_cooldown(delta)
	
	# 🆕 DETECTAR COLISIÓN CON PARED
	var was_on_wall = is_on_wall()
	
	move_and_slide()
	
	# 🆕 RETROCEDER SI CHOCA CON PARED DURANTE EMBESTIDA
	if was_on_wall and current_state == State.CHARGING:
		_on_wall_hit()
	
	_update_sprite_direction()
	
	# 🆕 DAÑO CONTINUO (como Fungus)
	if continuous_damage and hitbox:
		_check_continuous_damage()

# ============================================
# 🆕 SISTEMA ANTI-ENGANCHE
# ============================================

func _apply_separation_force(_delta: float) -> void:
	if not player:
		return
	
	var distance = global_position.distance_to(player.global_position)
	
	# Si está muy cerca, alejarse
	if distance < min_player_distance:
		var separation_direction = (global_position - player.global_position).normalized()
		var separation_strength = (min_player_distance - distance) * separation_force_multiplier
		
		velocity += separation_direction * separation_strength
		
		# Debug
		if distance < min_player_distance * 0.5:
			print("🦇 ", name, " separándose del player (dist: ", "%.1f" % distance, ")")

func _on_wall_hit() -> void:
	print("🦇 ", name, " chocó con pared, retrocediendo")
	
	# Retroceder en dirección opuesta
	velocity = -charge_direction * (charge_speed * wall_bounce_multiplier)
	
	# Cambiar a cooldown inmediatamente
	_change_state(State.COOLDOWN)

# ============================================
# ESTADOS
# ============================================

func _process_patrol(_delta: float) -> void:
	if not patrol_enabled:
		_change_state(State.IDLE)
		return
	
	# Movimiento horizontal de patrulla
	var target_x = patrol_start_pos.x + (patrol_distance * patrol_direction)
	var direction_to_target = sign(target_x - global_position.x)
	
	if abs(global_position.x - target_x) < 5.0:
		patrol_direction *= -1
	
	velocity.x = direction_to_target * patrol_speed
	
	# Movimiento vertical ondulante
	velocity.y = sin(float_time * float_frequency) * float_amplitude
	
	# Detectar jugador
	if player and _is_player_in_range():
		_change_state(State.CHASE)

func _process_idle(_delta: float) -> void:
	velocity.x = 0
	
	# Flotar en el lugar
	velocity.y = sin(float_time * float_frequency) * (float_amplitude * 0.5)
	
	if player and _is_player_in_range():
		_change_state(State.CHASE)

func _process_chase(_delta: float) -> void:
	if not player or not _is_player_in_range():
		_change_state(State.PATROL if patrol_enabled else State.IDLE)
		return
	
	# Seguir al jugador
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * movement_speed
	
	# Si está cerca, preparar embestida
	if global_position.distance_to(player.global_position) < attack_range:
		_change_state(State.PREPARE_CHARGE)

func _process_prepare_charge(delta: float) -> void:
	state_timer -= delta
	
	# Detenerse y preparar
	velocity = velocity.lerp(Vector2.ZERO, delta * 5.0)
	
	# Efecto visual (parpadeo)
	if sprite:
		sprite.modulate = Color.WHITE if int(state_timer * 10) % 2 == 0 else Color(1, 0.5, 0.5)
	
	if state_timer <= 0:
		if player:
			charge_direction = (player.global_position - global_position).normalized()
		_change_state(State.CHARGING)

func _process_charging(delta: float) -> void:
	state_timer -= delta
	
	# Embestida en línea recta
	velocity = charge_direction * charge_speed
	
	if state_timer <= 0:
		_change_state(State.COOLDOWN)

func _process_cooldown(delta: float) -> void:
	state_timer -= delta
	
	# Frenar gradualmente
	velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
	
	if state_timer <= 0:
		if player and _is_player_in_range():
			_change_state(State.CHASE)
		else:
			_change_state(State.PATROL if patrol_enabled else State.IDLE)

# ============================================
# CAMBIO DE ESTADO
# ============================================

func _change_state(new_state: State) -> void:
	print("🦇 ", name, ": ", State.keys()[current_state], " → ", State.keys()[new_state])
	
	# Limpiar efectos del estado anterior
	if current_state == State.PREPARE_CHARGE and sprite:
		sprite.modulate = Color.WHITE
	
	current_state = new_state
	
	# 🆕 AJUSTAR COLISIÓN SEGÚN ESTADO
	# Solo colisionar con terreno, el player se maneja con Hitbox
	collision_mask = 0b0001
	
	# Configurar timers
	match new_state:
		State.PREPARE_CHARGE:
			state_timer = charge_preparation_time
		State.CHARGING:
			state_timer = charge_duration
		State.COOLDOWN:
			state_timer = charge_cooldown

# ============================================
# DETECCIÓN Y COMBATE
# ============================================

func _on_detection_area_entered(body: Node2D) -> void:
	if body is Player:
		player = body
		print("🦇 ", name, " detectó al jugador")

func _on_detection_area_exited(body: Node2D) -> void:
	if body is Player and body == player:
		player = null
		print("🦇 ", name, " perdió al jugador")

func _is_player_in_range() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= detection_range

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is Player:
		# 🆕 Daño variable según estado
		var damage = charge_damage if current_state == State.CHARGING else contact_damage
		_deal_damage_to_player(body as Player, damage)
		
		# 🆕 EMPUJAR AL PLAYER
		_push_player_away(body as Player)

func _deal_damage_to_player(target: Player, damage: int = 1) -> void:
	# 🆕 Verificar cooldown
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_damage_time < damage_cooldown:
		return
	_last_damage_time = now
	
	var health_component = target.get_node_or_null("HealthComponent")
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(damage)
		print("🦇 ", name, " golpeó al jugador por ", damage, " de daño")
		
		# Retroceder después del golpe solo si está embistiendo
		if current_state == State.CHARGING:
			_change_state(State.COOLDOWN)

# 🆕 DAÑO CONTINUO (como Fungus)
func _check_continuous_damage() -> void:
	if not hitbox:
		return
	
	var overlapping_bodies = hitbox.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group("Player"):
			var damage = charge_damage if current_state == State.CHARGING else contact_damage
			_deal_damage_to_player(body as Player, damage)
			return

func _push_player_away(target: Player) -> void:
	var push_direction = (target.global_position - global_position).normalized()
	
	# Intentar usar el método de knockback del player
	if target.has_method("apply_knockback"):
		target.apply_knockback(push_direction * player_push_force)
	else:
		# Fallback: aplicar velocidad directamente
		target.velocity += push_direction * player_push_force
	
	print("🦇 ", name, " empujó al jugador")

# ============================================
# OVERRIDE DE ENEMYBASE
# ============================================

func _on_die() -> void:
	print("🦇 ", name, " murió en combate")
	
	# Aquí puedes agregar:
	# - Soltar items
	# - Efectos de partículas
	# - Sonidos
	# - Animación de muerte

# ============================================
# VISUAL
# ============================================

func _update_sprite_direction() -> void:
	if not sprite:
		return
	
	if velocity.x != 0:
		sprite.flip_h = velocity.x < 0

# ============================================
# DEBUG
# ============================================

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	# Dibujar rango de detección (amarillo)
	draw_circle(Vector2.ZERO, detection_range, Color(1, 1, 0, 0.1))
	draw_arc(Vector2.ZERO, detection_range, 0, TAU, 32, Color.YELLOW, 2.0)
	
	# Dibujar rango de ataque (rojo)
	draw_circle(Vector2.ZERO, attack_range, Color(1, 0, 0, 0.1))
	draw_arc(Vector2.ZERO, attack_range, 0, TAU, 32, Color.RED, 2.0)
	
	# 🆕 Dibujar distancia mínima del player (magenta)
	draw_circle(Vector2.ZERO, min_player_distance, Color(1, 0, 1, 0.1))
	draw_arc(Vector2.ZERO, min_player_distance, 0, TAU, 32, Color.MAGENTA, 2.0)
	
	# Dibujar patrulla (cyan)
	if patrol_enabled:
		var left_point = patrol_start_pos - global_position + Vector2(-patrol_distance, 0)
		var right_point = patrol_start_pos - global_position + Vector2(patrol_distance, 0)
		draw_line(left_point, right_point, Color.CYAN, 2.0)
		draw_circle(left_point, 5, Color.CYAN)
		draw_circle(right_point, 5, Color.CYAN)
