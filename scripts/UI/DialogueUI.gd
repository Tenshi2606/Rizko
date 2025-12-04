extends Control
class_name DialogueUI

signal dialogue_finished
signal dialogue_advanced

var current_npc: DialogueNPC = null
var is_showing: bool = false

@onready var panel: Panel = $Panel
@onready var speaker_label: Label = $Panel/VBoxContainer/SpeakerLabel
@onready var dialogue_label: Label = $Panel/VBoxContainer/DialogueLabel
@onready var continue_prompt: Label = $Panel/VBoxContainer/ContinuePrompt

func _ready() -> void:
	visible = false
	is_showing = false
	print("💬 DialogueUI inicializado")
	
	if not panel:
		push_error("❌ Panel no encontrado")
	if not speaker_label:
		push_error("❌ SpeakerLabel no encontrado")
	if not dialogue_label:
		push_error("❌ DialogueLabel no encontrado")
	if not continue_prompt:
		push_error("❌ ContinuePrompt no encontrado")

func _input(event: InputEvent) -> void:
	if not is_showing or not visible:
		return
	
	if event.is_action_pressed("ui_accept"):
		print("💬 Presionaste E")
		_advance_dialogue()
		get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("ui_cancel"):
		_force_close()
		get_viewport().set_input_as_handled()

func show_dialogue(npc: DialogueNPC) -> void:
	if not npc:
		push_error("❌ NPC es null")
		return
	
	if npc.dialogue_lines.is_empty():
		push_warning("⚠️ ", npc.npc_name, " no tiene líneas de diálogo")
		return
	
	current_npc = npc
	is_showing = true
	visible = true
	
	# 🔧 ASEGURAR QUE EMPIECE EN 0
	current_npc.current_line = 0
	
	print("💬 Mostrando diálogo de: ", npc.npc_name)
	print("💬 Total líneas: ", npc.dialogue_lines.size())
	
	# 🔧 MOSTRAR LA PRIMERA LÍNEA INMEDIATAMENTE
	_update_display()

func _update_display() -> void:
	if not current_npc:
		print("⚠️ current_npc es null")
		return
	
	# 🔧 VERIFICAR ÍNDICE VÁLIDO
	if current_npc.current_line >= current_npc.dialogue_lines.size():
		push_error("❌ Índice fuera de rango: ", current_npc.current_line)
		return
	
	# Actualizar nombre
	if speaker_label:
		speaker_label.text = current_npc.npc_name
	
	# Obtener línea actual
	var line = current_npc.dialogue_lines[current_npc.current_line]
	
	# Actualizar texto
	if dialogue_label:
		dialogue_label.text = line
	
	# Actualizar prompt
	if continue_prompt:
		# Si es la última línea
		if current_npc.current_line >= current_npc.dialogue_lines.size() - 1:
			continue_prompt.text = "▼ Presiona E para cerrar"
		else:
			continue_prompt.text = "▼ Presiona E para continuar"
	
	print("💬 Mostrando línea ", current_npc.current_line, "/", current_npc.dialogue_lines.size() - 1, ": ", line)

func _advance_dialogue() -> void:
	if not current_npc:
		return
	
	print("💬 Avanzando desde línea: ", current_npc.current_line)
	
	# 🔧 PRIMERO VERIFICAR SI ES LA ÚLTIMA LÍNEA
	if current_npc.current_line >= current_npc.dialogue_lines.size() - 1:
		# Era la última línea, cerrar
		print("💬 Era la última línea, cerrando...")
		_close_dialogue()
	else:
		# Hay más líneas, avanzar
		current_npc.current_line += 1
		print("💬 Avanzando a línea: ", current_npc.current_line)
		_update_display()
		dialogue_advanced.emit()

func _close_dialogue() -> void:
	print("💬 Cerrando diálogo")
	visible = false
	is_showing = false
	
	if current_npc:
		current_npc.current_line = 0
		current_npc.stop_interaction()
		current_npc = null
	
	dialogue_finished.emit()

func _force_close() -> void:
	print("💬 Diálogo forzado a cerrar (ESC)")
	_close_dialogue()
