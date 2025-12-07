# res://scripts/player/components/ComboSystem.gd
extends Node
class_name ComboSystem

signal combo_hit(hit_index: int)
signal combo_finished
signal combo_reset

var player: Player
var attack_component: AttackComponent
var animation_controller: AnimationController

# Estado del combo
var combo_index: int = 0
var combo_window_timer: float = 0.0
const COMBO_WINDOW_DURATION: float = 1.0  # 🔧 Reducido de 2.0s a 1.0s
var active_combo: ComboData = null

# Sistema de input buffer
var is_animation_playing: bool = false
var input_buffer_active: bool = false
var buffered_attack_type: String = ""
var can_queue_next: bool = false

# Timing
const BUFFER_WINDOW: float = 0.3  # 🔧 Reducido de 0.4s a 0.3s
const QUEUE_WINDOW_START: float = 0.4  # 🔧 Aumentado de 0.3s a 0.4s

# 🆕 CONTROL DE SALIDA
var time_since_animation_end: float = 0.0
const ATTACK_EXIT_GRACE: float = 0.2  # Tiempo mínimo antes de salir

# 🆕 CONFIGURACIÓN DE COMBOS (RECURSOS)
@export var default_combo: ComboData
@export var weapon_combos: Dictionary = {}
@export var air_combo: ComboData
@export var pogo_combo: ComboData
@export var launcher_combo: ComboData

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("ComboSystem debe ser hijo de un Player")
		return
	
	# Obtener componentes
	attack_component = player.get_node_or_null("AttackComponent") as AttackComponent
	animation_controller = player.get_node_or_null("AnimationController") as AnimationController
	
	await get_tree().process_frame
	
	# Conectar a AnimationController
	if animation_controller and animation_controller.animation_player:
		if not animation_controller.animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_controller.animation_player.animation_finished.connect(_on_animation_finished)
			print("  ✅ ComboSystem conectado a animation_finished")
	else:
		push_error("❌ No se pudo conectar a animation_finished")
	
	print("✅ ComboSystem inicializado (DMC Style)")

func _process(delta: float) -> void:
	# Actualizar ventana de combo
	if combo_window_timer > 0:
		combo_window_timer -= delta
		
		if combo_window_timer <= 0 and combo_index > 0:
			print("⏱️ Ventana de combo expirada")
			reset_combo()
	
	# 🆕 Actualizar tiempo desde fin de animación
	if not is_animation_playing:
		time_since_animation_end += delta

func try_attack() -> bool:
	return _try_attack_internal("ground", false)

func try_air_attack() -> bool:
	return _try_attack_internal("air", true)

func try_pogo_attack() -> bool:
	return _try_attack_internal("pogo", false)

func try_launcher_attack() -> bool:
	return _try_attack_internal("launcher", false)

func _try_attack_internal(attack_type: String, is_air: bool = false) -> bool:
	print("\n🎮 try_attack llamado - Tipo:", attack_type)
	print("  Estado: animación_activa=", is_animation_playing, " buffer=", input_buffer_active)
	
	# CASO 1: Ya hay animación activa
	if is_animation_playing:
		# Si puede encolar, guardar en buffer
		if can_queue_next and not input_buffer_active:
			input_buffer_active = true
			buffered_attack_type = attack_type
			print("  ✅ Input bufferado para siguiente golpe")
			return true
		else:
			print("  ❌ Spam ignorado (animación activa, buffer lleno)")
			return false
	
	# CASO 2: No hay animación, ejecutar inmediatamente
	return _execute_attack(attack_type, is_air)

func _execute_attack(attack_type: String, is_air: bool) -> bool:
	print("⚔️ Ejecutando ataque: ", attack_type)
	
	# Obtener combo activo
	var current_combo = _get_active_combo_for_context(is_air)
	
	if not current_combo:
		print("  ⚠️ No hay combo disponible")
		return false
	
	# Incrementar índice
	combo_index += 1
	var max_hits = current_combo.get_attack_count()
	
	# Ciclar si llegó al final
	if combo_index > max_hits:
		if current_combo.loop_combo:
			combo_index = 1
		else:
			reset_combo()
			return false
	
	# Obtener datos del ataque
	var attack_data = current_combo.get_attack(combo_index - 1)
	if not attack_data:
		print("  ⚠️ No se encontró AttackData")
		return false
	
	var anim_name = attack_data.animation_name
	
	print("  🎯 Combo Hit ", combo_index, "/", max_hits)
	print("  🎬 Animación: ", anim_name)
	
	# Reproducir animación
	if animation_controller:
		animation_controller.play(anim_name, true)
	
	# Marcar animación como activa
	is_animation_playing = true
	can_queue_next = false
	time_since_animation_end = 0.0  # 🆕 Reset
	
	# Iniciar ventana de combo
	combo_window_timer = current_combo.combo_window
	
	# Emitir señal
	combo_hit.emit(combo_index)
	
	# Programar cuándo se puede encolar siguiente
	_schedule_queue_window(attack_data.duration)
	
	return true

func _schedule_queue_window(attack_duration: float) -> void:
	# Calcular cuándo se puede encolar (40% de la animación)
	var queue_start_time = attack_duration * QUEUE_WINDOW_START
	
	await get_tree().create_timer(queue_start_time).timeout
	
	if is_instance_valid(self) and is_animation_playing:
		can_queue_next = true
		print("  🟢 Ventana de encolado activada")

# 🆕 CALLBACK MEJORADO: ANIMACIÓN TERMINADA
func _on_animation_finished(anim_name: String) -> void:
	print("\n✅ Animación terminada: ", anim_name)
	
	# Solo procesar ataques
	if not (anim_name.contains("attack") or anim_name.contains("scythe")):
		return
	
	# Marcar animación como terminada
	is_animation_playing = false
	can_queue_next = false
	time_since_animation_end = 0.0  # 🆕 Resetear contador
	
	print("  Estado: buffer=", input_buffer_active)
	
	# 🆕 LIMPIAR LISTA DE GOLPEADOS SIEMPRE
	if attack_component:
		attack_component.enemies_hit_this_attack.clear()
		print("  🔄 Lista de enemigos golpeados limpiada")
	
	# 🆕 SI NO HAY INPUT BUFFERADO, INDICAR QUE PUEDE SALIR
	if not input_buffer_active:
		print("  ℹ️ Sin input bufferado - AttackState puede salir")
		# NO resetear combo aquí, dejar que expire naturalmente
		return
	
	# PROCESAR INPUT BUFFEADO
	print("  🔄 Ejecutando ataque buffeado: ", buffered_attack_type)
	
	# Limpiar buffer
	input_buffer_active = false
	var attack_to_execute = buffered_attack_type
	buffered_attack_type = ""
	
	# Ejecutar siguiente ataque
	_execute_attack(attack_to_execute, false)

# 🆕 NUEVA FUNCIÓN: ¿Puede salir del AttackState?
func can_exit_attack_state() -> bool:
	"""
	Determina si es seguro salir del AttackState.
	Retorna true solo cuando:
	- No hay animación activa
	- No hay input bufferado
	- Ha pasado un grace period mínimo
	"""
	
	# Si está atacando activamente, NO salir
	if is_animation_playing:
		return false
	
	# Si hay input bufferado, NO salir (va a ejecutar siguiente golpe)
	if input_buffer_active:
		return false
	
	# Si apenas terminó la animación, dar un pequeño margen
	if time_since_animation_end < ATTACK_EXIT_GRACE:
		return false
	
	# ✅ OK para salir
	return true

func _get_active_combo() -> ComboData:
	var weapon = player.get_current_weapon()
	
	if weapon and weapon.weapon_id in weapon_combos:
		var combo = weapon_combos[weapon.weapon_id]
		if combo and combo.can_use_with_weapon(weapon):
			return combo
	
	return default_combo

func _get_active_combo_for_context(is_air: bool) -> ComboData:
	if is_air and air_combo:
		return air_combo
	return _get_active_combo()

func reset_combo() -> void:
	if combo_index > 0:
		print("🔄 Combo reseteado")
		combo_reset.emit()
	
	combo_index = 0
	combo_window_timer = 0.0
	is_animation_playing = false
	input_buffer_active = false
	buffered_attack_type = ""
	can_queue_next = false
	time_since_animation_end = 0.0  # 🆕 Reset
	
	# Limpiar enemigos golpeados
	if attack_component:
		attack_component.enemies_hit_this_attack.clear()

func is_in_combo() -> bool:
	return combo_index > 0 and combo_window_timer > 0

func is_currently_attacking() -> bool:
	return is_animation_playing or input_buffer_active
