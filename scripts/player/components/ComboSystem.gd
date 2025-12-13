# res://scripts/player/components/ComboSystem.gd
extends Node
class_name ComboSystem

## ============================================
## COMBO SYSTEM - CON UP SLASH Y LAUNCHER
## ============================================

signal combo_hit(hit_index: int)
signal combo_finished
signal combo_reset

var player: Player
var attack_component: AttackComponent
var animation_controller: AnimationController

var combo_index: int = 0
var combo_window_timer: float = 0.0
const COMBO_WINDOW_DURATION: float = 1.2
var active_combo: ComboData = null

var is_animation_playing: bool = false
var input_buffer_active: bool = false
var buffered_attack_type: String = ""
var can_queue_next: bool = false

const BUFFER_WINDOW: float = 0.4
const QUEUE_WINDOW_START: float = 0.3

var time_since_animation_end: float = 0.0
const ATTACK_EXIT_GRACE: float = 0.15

# 🆕 PRIORIDAD ACTUALIZADA
enum AttackPriority { 
	POGO = 4,      # Máxima prioridad
	LAUNCHER = 3,  # 🆕 Segunda prioridad
	UP_SLASH = 2,  # 🆕 Tercera prioridad
	AIR = 1, 
	GROUND = 0 
}

# 🆕 CONFIGURACIÓN DE COMBOS
@export var default_combo: ComboData
@export var weapon_combos: Dictionary = {}
@export var air_combo: ComboData
@export var pogo_combo: ComboData
@export var launcher_combo: ComboData
@export var up_slash_combo: ComboData  # 🆕 NUEVO

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("ComboSystem debe ser hijo de un Player")
		return
	
	attack_component = player.get_node_or_null("AttackComponent") as AttackComponent
	animation_controller = player.get_node_or_null("AnimationController") as AnimationController
	
	await get_tree().process_frame
	
	if animation_controller and animation_controller.animation_player:
		if not animation_controller.animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_controller.animation_player.animation_finished.connect(_on_animation_finished)
	
	print("✅ ComboSystem inicializado")
	_print_combo_config()

func _print_combo_config() -> void:
	print("  📦 Combos configurados:")
	if default_combo:
		print("    ✅ Default: ", default_combo.combo_name)
	if air_combo:
		print("    ✅ Air: ", air_combo.combo_name)
	if pogo_combo:
		print("    ✅ Pogo: ", pogo_combo.combo_name)
	if launcher_combo:
		print("    ✅ Launcher: ", launcher_combo.combo_name)
	if up_slash_combo:
		print("    ✅ Up Slash: ", up_slash_combo.combo_name, " 🆕")

func _process(delta: float) -> void:
	if combo_window_timer > 0:
		combo_window_timer -= delta
		
		if combo_window_timer <= 0 and combo_index > 0:
			print("⏱️ Ventana expirada")
			reset_combo()
	
	if not is_animation_playing:
		time_since_animation_end += delta

# ============================================
# 🎯 API PÚBLICA
# ============================================

func try_attack() -> bool:
	return _try_attack_internal("ground", false)

func try_air_attack() -> bool:
	return _try_attack_internal("air", true)

func try_pogo_attack() -> bool:
	print("🦘 POGO INSTANT")
	
	# 🔥 VALIDAR ARMA REQUERIDA (SOLO GUADAÑA)
	if not _validate_weapon_for_attack("pogo"):
		print("  ❌ POGO requiere Guadaña Espectral")
		return false
	
	if is_animation_playing:
		print("  ⚠️ Cancelando para pogo")
		is_animation_playing = false
		input_buffer_active = false
		buffered_attack_type = ""
		can_queue_next = false
	
	_instant_cleanup()
	
	return _execute_attack("pogo", false)

# 🆕 LAUNCHER (↓+X en tierra)
func try_launcher_attack() -> bool:
	print("🚀 LAUNCHER")
	
	# 🔥 VALIDAR ARMA REQUERIDA (SOLO GUADAÑA)
	if not _validate_weapon_for_attack("launcher"):
		print("  ❌ LAUNCHER requiere Guadaña Espectral")
		return false
	
	return _try_attack_internal("launcher", false)

# 🆕 UP SLASH (↑+X)
func try_up_slash_attack() -> bool:
	print("⬆️ UP SLASH")
	return _try_attack_internal("up_slash", false)

# 🆕 VALIDAR ARMA REQUERIDA PARA ATAQUE
func _validate_weapon_for_attack(attack_type: String) -> bool:
	var weapon = player.get_current_weapon()
	
	if not weapon:
		return false
	
	# 🔥 POGO Y LAUNCHER SOLO CON GUADAÑA
	if attack_type in ["pogo", "launcher"]:
		if weapon.weapon_id != "scythe":
			print("    ⚠️ Ataque especial requiere Guadaña (arma actual: ", weapon.weapon_name, ")")
			return false
	
	return true

# ============================================
# 🎯 LÓGICA INTERNA
# ============================================

func _try_attack_internal(attack_type: String, is_air: bool = false) -> bool:
	print("\n🎮 try_attack - Tipo:", attack_type)
	
	var new_priority = _get_attack_priority(attack_type)
	var current_priority = _get_attack_priority(buffered_attack_type) if input_buffer_active else -1
	
	if is_animation_playing:
		if new_priority > current_priority:
			print("  🔥 REEMPLAZANDO BUFFER")
			input_buffer_active = true
			buffered_attack_type = attack_type
			can_queue_next = true
			return true
		
		if can_queue_next and not input_buffer_active:
			input_buffer_active = true
			buffered_attack_type = attack_type
			print("  ✅ Bufferado")
			return true
		else:
			print("  ❌ Spam")
			return false
	
	return _execute_attack(attack_type, is_air)

func _get_attack_priority(attack_type: String) -> int:
	match attack_type:
		"pogo":
			return AttackPriority.POGO
		"launcher":
			return AttackPriority.LAUNCHER  # 🆕
		"up_slash":
			return AttackPriority.UP_SLASH  # 🆕
		"air":
			return AttackPriority.AIR
		_:
			return AttackPriority.GROUND

func _execute_attack(attack_type: String, is_air: bool) -> bool:
	print("⚔️ Ejecutando: ", attack_type)
	
	var current_combo = _get_combo_for_type(attack_type, is_air)
	
	if not current_combo:
		print("  ⚠️ No hay combo")
		return false
	
	print("  📦 Combo: ", current_combo.combo_name)
	
	# 🆕 POGO, AIR, UP_SLASH, LAUNCHER no incrementan combo
	if attack_type in ["pogo", "air", "up_slash", "launcher"]:
		combo_index = 1
	else:
		combo_index += 1
		var max_hits = current_combo.get_attack_count()
		
		if combo_index > max_hits:
			if current_combo.loop_combo:
				combo_index = 1
			else:
				reset_combo()
				return false
	
	var attack_data = current_combo.get_attack(combo_index - 1)
	if not attack_data:
		print("  ⚠️ No AttackData")
		return false
	
	var anim_name = attack_data.animation_name
	
	print("  🎯 Hit ", combo_index, "/", current_combo.get_attack_count())
	print("  🎬 Anim: ", anim_name)
	
	_instant_cleanup()
	
	if animation_controller:
		animation_controller.play(anim_name, true)
	
	is_animation_playing = true
	can_queue_next = false
	time_since_animation_end = 0.0
	
	combo_window_timer = current_combo.combo_window
	
	combo_hit.emit(combo_index)
	
	if attack_type != "pogo":
		_schedule_queue_window(attack_data.duration)
	
	return true

func _instant_cleanup() -> void:
	if attack_component:
		attack_component.enemies_hit_this_attack.clear()
		print("  🧹 Limpieza instantánea")

func _get_combo_for_type(attack_type: String, is_air: bool) -> ComboData:
	match attack_type:
		"air":
			return air_combo if air_combo else default_combo
		"pogo":
			return pogo_combo
		"launcher":
			return launcher_combo  # 🆕
		"up_slash":
			return up_slash_combo  # 🆕
		"ground":
			return _get_active_combo()
		_:
			return _get_active_combo()

func _schedule_queue_window(attack_duration: float) -> void:
	var queue_start_time = attack_duration * QUEUE_WINDOW_START
	
	await get_tree().create_timer(queue_start_time).timeout
	
	if is_instance_valid(self) and is_animation_playing:
		can_queue_next = true
		print("  🟢 Queue activo")

func _on_animation_finished(anim_name: String) -> void:
	print("\n✅ Anim terminada: ", anim_name)
	
	if not (anim_name.contains("attack") or anim_name.contains("scythe") or anim_name.contains("pogo")):
		return
	
	is_animation_playing = false
	can_queue_next = false
	time_since_animation_end = 0.0
	
	_instant_cleanup()
	
	print("  Estado: buffer=", input_buffer_active)
	
	if not input_buffer_active:
		print("  ℹ️ Sin buffer")
		return
	
	print("  🔄 Ejecutando buffer: ", buffered_attack_type)
	
	input_buffer_active = false
	var attack_to_execute = buffered_attack_type
	buffered_attack_type = ""
	
	_execute_attack(attack_to_execute, false)

func can_exit_attack_state() -> bool:
	if is_animation_playing:
		return false
	
	if input_buffer_active:
		return false
	
	if time_since_animation_end < ATTACK_EXIT_GRACE:
		return false
	
	return true

func _get_active_combo() -> ComboData:
	var weapon = player.get_current_weapon()
	
	if weapon and weapon.weapon_id in weapon_combos:
		var combo = weapon_combos[weapon.weapon_id]
		if combo and combo.can_use_with_weapon(weapon):
			return combo
	
	return default_combo

func reset_combo() -> void:
	if combo_index > 0:
		print("🔄 Reset")
		combo_reset.emit()
	
	combo_index = 0
	combo_window_timer = 0.0
	is_animation_playing = false
	input_buffer_active = false
	buffered_attack_type = ""
	can_queue_next = false
	time_since_animation_end = 0.0
	
	_instant_cleanup()

func is_in_combo() -> bool:
	return combo_index > 0 and combo_window_timer > 0

func is_currently_attacking() -> bool:
	return is_animation_playing or input_buffer_active
