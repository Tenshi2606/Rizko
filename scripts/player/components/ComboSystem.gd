# res://scripts/player/components/ComboSystem.gd
extends Node
class_name ComboSystem

signal combo_hit(hit_index: int)
signal combo_finished
signal combo_reset

var player: Player
var attack_component: AttackComponent
var animation_controller: AnimationController

var combo_index: int = 0
var combo_window_timer: float = 0.0
const COMBO_WINDOW_DURATION: float = 1.0
var active_combo: ComboData = null

var is_animation_playing: bool = false
var input_buffer_active: bool = false
var buffered_attack_type: String = ""
var can_queue_next: bool = false

const BUFFER_WINDOW: float = 0.3
const QUEUE_WINDOW_START: float = 0.4

var time_since_animation_end: float = 0.0
const ATTACK_EXIT_GRACE: float = 0.2

# 🆕 POGO INSTANT - Sin esperar animación
var allow_instant_pogo: bool = true

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
	
	attack_component = player.get_node_or_null("AttackComponent") as AttackComponent
	animation_controller = player.get_node_or_null("AnimationController") as AnimationController
	
	await get_tree().process_frame
	
	if animation_controller and animation_controller.animation_player:
		if not animation_controller.animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_controller.animation_player.animation_finished.connect(_on_animation_finished)
			print("  ✅ ComboSystem conectado a animation_finished")
	else:
		push_error("❌ No se pudo conectar a animation_finished")
	
	print("✅ ComboSystem inicializado")
	_print_combo_config()

func _print_combo_config() -> void:
	print("  📦 Combos configurados:")
	if default_combo:
		print("    ✅ Default Combo: ", default_combo.combo_name)
	else:
		print("    ❌ Default Combo: NO configurado")
	
	if air_combo:
		print("    ✅ Air Combo: ", air_combo.combo_name)
	else:
		print("    ❌ Air Combo: NO configurado")
	
	if pogo_combo:
		print("    ✅ Pogo Combo: ", pogo_combo.combo_name)
	else:
		print("    ❌ Pogo Combo: NO configurado")
	
	if launcher_combo:
		print("    ✅ Launcher Combo: ", launcher_combo.combo_name)
	else:
		print("    ❌ Launcher Combo: NO configurado")

func _process(delta: float) -> void:
	if combo_window_timer > 0:
		combo_window_timer -= delta
		
		if combo_window_timer <= 0 and combo_index > 0:
			print("⏱️ Ventana de combo expirada")
			reset_combo()
	
	if not is_animation_playing:
		time_since_animation_end += delta

func try_attack() -> bool:
	return _try_attack_internal("ground", false)

func try_air_attack() -> bool:
	return _try_attack_internal("air", true)

# 🆕 POGO INSTANT - No esperar animación
func try_pogo_attack() -> bool:
	if not allow_instant_pogo:
		return _try_attack_internal("pogo", false)
	
	# EJECUTAR INMEDIATAMENTE SIN BUFFER
	print("🦘 POGO INSTANT - Ejecución directa")
	
	# Cancelar animación actual si existe
	if is_animation_playing:
		print("  ⚠️ Cancelando animación previa para pogo")
		is_animation_playing = false
		input_buffer_active = false
	
	return _execute_attack("pogo", false)

func try_launcher_attack() -> bool:
	return _try_attack_internal("launcher", false)

func _try_attack_internal(attack_type: String, is_air: bool = false) -> bool:
	print("\n🎮 try_attack llamado - Tipo:", attack_type)
	print("  Estado: animación_activa=", is_animation_playing, " buffer=", input_buffer_active)
	
	# Ya hay animación activa
	if is_animation_playing:
		if can_queue_next and not input_buffer_active:
			input_buffer_active = true
			buffered_attack_type = attack_type
			print("  ✅ Input bufferado")
			return true
		else:
			print("  ❌ Spam ignorado")
			return false
	
	# No hay animación, ejecutar
	return _execute_attack(attack_type, is_air)

func _execute_attack(attack_type: String, is_air: bool) -> bool:
	print("⚔️ Ejecutando ataque: ", attack_type)
	
	# 🆕 OBTENER COMBO SEGÚN TIPO
	var current_combo = _get_combo_for_type(attack_type, is_air)
	
	if not current_combo:
		print("  ⚠️ No hay combo disponible para tipo: ", attack_type)
		return false
	
	print("  📦 Combo seleccionado: ", current_combo.combo_name)
	
	# 🆕 POGO NO INCREMENTA COMBO - Siempre es hit 1
	if attack_type == "pogo":
		combo_index = 1
	else:
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
	
	print("  🎯 Combo Hit ", combo_index, "/", current_combo.get_attack_count())
	print("  🎬 Animación: ", anim_name)
	
	# Reproducir animación
	if animation_controller:
		animation_controller.play(anim_name, true)
	
	is_animation_playing = true
	can_queue_next = false
	time_since_animation_end = 0.0
	
	combo_window_timer = current_combo.combo_window
	
	combo_hit.emit(combo_index)
	
	# 🆕 POGO NO TIENE QUEUE WINDOW - Salir inmediatamente después
	if attack_type != "pogo":
		_schedule_queue_window(attack_data.duration)
	
	return true

# 🆕 OBTENER COMBO SEGÚN TIPO DE ATAQUE
func _get_combo_for_type(attack_type: String, is_air: bool) -> ComboData:
	match attack_type:
		"air":
			if air_combo:
				return air_combo
			else:
				print("    ⚠️ Air combo NO configurado, usando default")
				return default_combo
		
		"pogo":
			if pogo_combo:
				return pogo_combo
			else:
				print("    ⚠️ Pogo combo NO configurado")
				return null
		
		"launcher":
			if launcher_combo:
				return launcher_combo
			else:
				print("    ⚠️ Launcher combo NO configurado")
				return null
		
		"ground":
			# Para ground, usar combo específico del arma si existe
			return _get_active_combo()
		
		_:
			return _get_active_combo()

func _schedule_queue_window(attack_duration: float) -> void:
	var queue_start_time = attack_duration * QUEUE_WINDOW_START
	
	await get_tree().create_timer(queue_start_time).timeout
	
	if is_instance_valid(self) and is_animation_playing:
		can_queue_next = true
		print("  🟢 Ventana de encolado activada")

func _on_animation_finished(anim_name: String) -> void:
	print("\n✅ Animación terminada: ", anim_name)
	
	if not (anim_name.contains("attack") or anim_name.contains("scythe") or anim_name.contains("pogo")):
		return
	
	is_animation_playing = false
	can_queue_next = false
	time_since_animation_end = 0.0
	
	print("  Estado: buffer=", input_buffer_active)
	
	if attack_component:
		attack_component.enemies_hit_this_attack.clear()
		print("  🔄 Lista de golpes limpiada")
	
	if not input_buffer_active:
		print("  ℹ️ Sin input bufferado - AttackState puede salir")
		return
	
	print("  🔄 Ejecutando ataque bufferado: ", buffered_attack_type)
	
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
		print("🔄 Combo reseteado")
		combo_reset.emit()
	
	combo_index = 0
	combo_window_timer = 0.0
	is_animation_playing = false
	input_buffer_active = false
	buffered_attack_type = ""
	can_queue_next = false
	time_since_animation_end = 0.0
	
	if attack_component:
		attack_component.enemies_hit_this_attack.clear()

func is_in_combo() -> bool:
	return combo_index > 0 and combo_window_timer > 0

func is_currently_attacking() -> bool:
	return is_animation_playing or input_buffer_active
