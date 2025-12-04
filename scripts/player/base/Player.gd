# res://scripts/player/Player.gd
## Clase principal del jugador
##
## Maneja todos los stats, componentes y comportamientos del jugador.
## Usa un sistema de State Machine para gestionar estados (idle, run, jump, attack, etc.)
## y componentes modulares para funcionalidades específicas.
##
## @tutorial: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html
extends CharacterBody2D
class_name Player

# ============================================
# 📊 STATS DE MOVIMIENTO
# ============================================

@export_group("Movimiento")
@export var speed: float = 220.0
@export var acceleration: float = 1400.0
@export var friction: float = 1200.0

@export_group("Gravedad")
@export var gravity_rising: float = 1600.0
@export var gravity_falling: float = 1200.0
@export var max_fall_speed: float = 600.0
@export var max_rise_speed: float = 800.0

@export_group("Salto")
@export var jump_initial_speed: float = 560.0
@export var max_jump_hold_time: float = 0.18
@export var jump_hold_accel: float = 1400.0
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.1

# ============================================
# ⚔️ STATS DE COMBATE (UNIFICADOS)
# ============================================

@export_group("Combate Base")
## Daño base del jugador (modificado por armas)
## Ejemplo: base=10, arma+5 = 15 de daño total
@export var base_attack_damage: int = 10

## Probabilidad de crítico base (0.05 = 5%)
## Se suma con el bonus del arma equipada
## Ejemplo: base=0.05 + arma=0.10 = 15% de crítico
@export var base_crit_chance: float = 0.05

## Multiplicador de daño crítico base (2.0 = x2 daño)
## Se multiplica con el bonus del arma
@export var base_crit_multiplier: float = 2.0

## Vida robada en crítico base
## Solo se activa en golpes críticos
@export var base_lifesteal: int = 0

# 🔧 Stats actuales (calculados por arma equipada)
var attack_damage: int = 10
var crit_chance: float = 0.05
var crit_multiplier: float = 2.0
var lifesteal_on_crit: int = 0

@export_group("Ataque - Configuración")
## Duración de la animación de ataque
@export var attack_duration: float = 0.3
## Offset del hitbox de ataque
@export var attack_hitbox_offset: float = 20.0
## Fuerza de knockback al atacar
@export var attack_knockback_force: Vector2 = Vector2(400, -200)
## Fuerza de rebote al golpear enemigos desde arriba (pogo)
@export var pogo_bounce_force: float = -400.0

@export_group("Combate - Habilidades")
## Combo máximo disponible (desbloqueado por habilidades)
@export var max_combo: int = 1
## Saltos máximos (1 = salto simple, 2 = doble salto)
@export var max_jumps: int = 1
## ¿Puede hacer wall jump?
@export var can_wall_jump: bool = false

# ============================================
# ❤️ STATS DE VIDA
# ============================================

@export_group("Vida")
@export var max_health: int = 5
@export var invul_time: float = 0.8
@export var damage_knockback: Vector2 = Vector2(200, -200)

var health: int = 0
var invulnerable: bool = false

# ============================================
# VARIABLES DE ESTADO
# ============================================

var is_jumping: bool = false
var jump_time: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var jumps_remaining: int = 1

enum AttackDirection { FORWARD, UP, DOWN }
var current_attack_direction: AttackDirection = AttackDirection.FORWARD
var hit_enemy_with_down_attack: bool = false

var previous_state_name: String = "idle"

var active_healing_fragment: SoulFragment = null
var is_in_healing_mode: bool = false

# Sistema de combate aéreo (DMC Style)
var is_aerial_frozen: bool = false
var aerial_freeze_timer: float = 0.0
var stored_velocity: Vector2 = Vector2.ZERO

# ============================================
# COMPONENTES DEL PLAYER
# ============================================
# Todos los componentes son modulares y se comunican vía EventBus
# cuando es posible para mantener bajo acoplamiento.

## Sprite principal del jugador (AnimatedSprite2D)
## Maneja todas las animaciones visuales
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Hitbox de ataque (Area2D)
## Detecta colisiones con enemigos durante ataques
## Manejado por AttackComponent
@onready var attack_hitbox: Area2D = $AttackHitbox

## Sistema de inventario
## Escucha eventos de EventBus para recoger items
## Emite eventos cuando cambia el inventario
@onready var inventory: InventoryComponent = $InventoryComponent

## Sistema de habilidades desbloqueables
## Gestiona dash, doble salto, wall jump, etc.
@onready var ability_system: AbilitySystem = $AbilitySystem

## Sistema de armas
## Gestiona armas equipadas, munición, recarga
## Emite eventos cuando cambia el arma
@onready var weapon_system: WeaponSystem = $WeaponSystem

# Referencias a componentes adicionales (obtenidas dinámicamente)
var health_component: HealthComponent
var movement_component: MovementComponent
var animation_controller: AnimationController
var attack_component: AttackComponent

func _ready() -> void:
	add_to_group("Player")
	
	# Obtener referencias a componentes
	health_component = get_node_or_null("HealthComponent") as HealthComponent
	movement_component = get_node_or_null("MovementComponent") as MovementComponent
	animation_controller = get_node_or_null("AnimationController") as AnimationController
	attack_component = get_node_or_null("AttackComponent") as AttackComponent
	
	# Registrarse en GameManager (deferred para evitar errores)
	call_deferred("_register_in_game_manager")
	
	print("🎮 Player inicializado")
	_print_component_status()

func _register_in_game_manager() -> void:
	if GameManager:
		GameManager.register_player(self)
	else:
		push_error("❌ GameManager no encontrado")

func _input(event: InputEvent) -> void:
	# Salto
	if event.is_action_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	
	# Cambiar armas
	if event.is_action_pressed("next_weapon"):
		if weapon_system:
			weapon_system.cycle_weapon(1)
	
	if event.is_action_pressed("prev_weapon"):
		if weapon_system:
			weapon_system.cycle_weapon(-1)
	
	# Recarga manual (tecla R)
	if event.is_action_pressed("reload"):
		if weapon_system and weapon_system.can_reload():
			weapon_system.start_reload()
	
	# Dash (C)
	if event.is_action_pressed("dash"):
		if is_in_healing_mode:
			return
		
		if ability_system and ability_system.has_ability("dash"):
			ability_system.use_ability("dash")
		else:
			print("❌ No tienes la habilidad Dash")
	
	# Curación (Q)
	if event.is_action_pressed("use_heal"):
		var state_machine = get_node_or_null("StateMachine")
		if state_machine and state_machine.current_state is DashState:
			print("⚠️ No puedes activar curación durante Dash")
			return
		
		if inventory:
			inventory.use_selected_fragment()
	
	# Cambiar fragmentos
	if event.is_action_pressed("next_fragment"):
		if inventory:
			inventory.cycle_fragment_selection(1)
	
	if event.is_action_pressed("prev_fragment"):
		if inventory:
			inventory.cycle_fragment_selection(-1)

func _physics_process(delta: float) -> void:
	_update_coyote_time(delta)
	_update_jump_buffer(delta)
	
	if is_aerial_frozen:
		_process_aerial_freeze(delta)
		return
	
	apply_gravity(delta)
	_update_healing_glow()

func _update_coyote_time(delta: float) -> void:
	if is_on_floor():
		coyote_timer = coyote_time
	elif coyote_timer > 0:
		coyote_timer -= delta

func _update_jump_buffer(delta: float) -> void:
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

func apply_gravity(delta: float) -> void:
	if velocity.y < 0:
		velocity.y += gravity_rising * delta
		velocity.y = max(velocity.y, -max_rise_speed)
	else:
		velocity.y += gravity_falling * delta
		velocity.y = min(velocity.y, max_fall_speed)

func _update_healing_glow() -> void:
	if is_in_healing_mode and sprite:
		var pulse = (sin(Time.get_ticks_msec() * 0.005) + 1.0) * 0.5
		var glow_intensity = 0.5 + pulse * 0.3
		sprite.modulate = Color(glow_intensity, 1.0, glow_intensity)
	elif sprite and sprite.modulate != Color(1, 1, 1) and not invulnerable:
		sprite.modulate = Color(1, 1, 1)

func can_jump() -> bool:
	return is_on_floor() or coyote_timer > 0

func get_movement_input() -> float:
	return Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")

func get_current_weapon() -> WeaponData:
	if weapon_system:
		return weapon_system.get_current_weapon()
	return null

func has_ranged_weapon() -> bool:
	var weapon = get_current_weapon()
	if weapon:
		return weapon.weapon_type == WeaponData.WeaponType.RANGED
	return false

# ============================================
# SISTEMA DE COMBATE AÉREO
# ============================================

func _process_aerial_freeze(delta: float) -> void:
	aerial_freeze_timer -= delta
	velocity.y = 0
	velocity.x = 0
	move_and_slide()
	
	if aerial_freeze_timer <= 0:
		_end_aerial_freeze()

func start_aerial_freeze(duration: float = 0.5) -> void:
	if is_on_floor():
		return
	
	is_aerial_frozen = true
	aerial_freeze_timer = duration
	stored_velocity = velocity
	
	if sprite:
		sprite.modulate = Color(0.7, 0.9, 1.0)
	
	print("❄️ Aerial freeze activado (", duration, "s)")

func _end_aerial_freeze() -> void:
	is_aerial_frozen = false
	velocity.y = 100
	
	if sprite:
		sprite.modulate = Color(1, 1, 1)
	
	print("✅ Aerial freeze terminado")

func can_aerial_freeze() -> bool:
	return not is_on_floor() and not is_aerial_frozen

# ============================================
# MÉTODOS HELPER - COMPONENTES
# ============================================

## Obtener componente de salud
## @return HealthComponent o null si no existe
func get_health_component() -> HealthComponent:
	return health_component

## Obtener componente de movimiento
## @return MovementComponent o null si no existe
func get_movement_component() -> MovementComponent:
	return movement_component

## Obtener componente de animación
## @return AnimationController o null si no existe
func get_animation_controller() -> AnimationController:
	return animation_controller

## Obtener componente de ataque
## @return AttackComponent o null si no existe
func get_attack_component() -> AttackComponent:
	return attack_component

# ============================================
# MÉTODOS HELPER - ESTADO DEL PLAYER
# ============================================

## Verificar si el player está vivo
## @return true si health > 0
func is_alive() -> bool:
	return health > 0

## Verificar si puede atacar
## @return true si no está curándose ni es invulnerable
func can_attack() -> bool:
	return not is_in_healing_mode and not invulnerable

## Obtener dirección de movimiento actual
## @return -1 si mira izquierda, 1 si mira derecha
func get_facing_direction() -> int:
	return -1 if sprite.flip_h else 1

## Verificar si está en el aire
## @return true si no está en el suelo
func is_in_air() -> bool:
	return not is_on_floor()

## Verificar si está cayendo
## @return true si velocity.y > 0
func is_falling() -> bool:
	return velocity.y > 0

## Verificar si está subiendo
## @return true si velocity.y < 0
func is_rising() -> bool:
	return velocity.y < 0

# ============================================
# MÉTODOS HELPER - DEBUG
# ============================================

## Imprimir estado de componentes (debug)
func _print_component_status() -> void:
	print("  📦 Componentes:")
	print("    ✅ Sprite: ", sprite != null)
	print("    ✅ AttackHitbox: ", attack_hitbox != null)
	print("    ✅ Inventory: ", inventory != null)
	print("    ✅ AbilitySystem: ", ability_system != null)
	print("    ✅ WeaponSystem: ", weapon_system != null)
	print("    ", "✅" if health_component else "⚠️", " HealthComponent: ", health_component != null)
	print("    ", "✅" if movement_component else "⚠️", " MovementComponent: ", movement_component != null)
	print("    ", "✅" if animation_controller else "⚠️", " AnimationController: ", animation_controller != null)
	print("    ", "✅" if attack_component else "⚠️", " AttackComponent: ", attack_component != null)

## Imprimir stats actuales (debug)
func print_stats() -> void:
	print("=== 🎮 PLAYER STATS ===")
	print("  ❤️ Vida: ", health, "/", max_health)
	print("  ⚔️ Daño: ", attack_damage)
	print("  🎯 Crítico: ", crit_chance * 100, "%")
	print("  💥 Mult. Crítico: x", crit_multiplier)
	print("  🩸 Lifesteal: ", lifesteal_on_crit)
	print("  🏃 Velocidad: ", speed)
	print("  🦘 Saltos: ", jumps_remaining, "/", max_jumps)
	print("======================")
