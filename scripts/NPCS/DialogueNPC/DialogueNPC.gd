extends NPCBase
class_name DialogueNPC

@export_group("Dialogue")
@export_multiline var dialogue_lines: Array[String] = [
	"¡Hola aventurero!",
	"¿Sabías que los fragmentos de alma son muy valiosos?",
	"¡Ten cuidado en tu viaje!"
]

var current_line: int = 0
var current_dialogue_ui: DialogueUI = null

func _on_ready() -> void:
	npc_type = "dialogue"
	interaction_prompt = "Presiona E para hablar"
	# 🔧 NO TOCAR current_line aquí
	print("💬 DialogueNPC configurado: ", npc_name, " - Líneas: ", dialogue_lines.size())

func on_interact() -> void:
	print("💬 Buscando DialogueUI...")
	var dialogue_ui = _find_dialogue_ui()
	
	if not dialogue_ui:
		push_error("❌ DialogueUI no encontrado en la escena")
		stop_interaction()
		return
	
	current_dialogue_ui = dialogue_ui
	
	# 🔧 RESETEAR ANTES DE MOSTRAR
	current_line = 0
	
	print("✅ DialogueUI encontrado, mostrando diálogo")
	print("💬 Primera línea debería ser: ", dialogue_lines[0])
	
	dialogue_ui.show_dialogue(self)

func _find_dialogue_ui():
	return _search_node(get_tree().root, "DialogueUI")

func _search_node(node: Node, node_name: String):
	if node.name == node_name:
		return node
	
	for child in node.get_children():
		var result = _search_node(child, node_name)
		if result:
			return result
	
	return null

func get_current_line() -> String:
	if dialogue_lines.is_empty():
		return ""
	
	if current_line >= dialogue_lines.size():
		current_line = 0
	
	return dialogue_lines[current_line]

func advance_dialogue() -> bool:
	current_line += 1
	print("💬 Avanzando diálogo - Nuevo índice: ", current_line)
	return current_line < dialogue_lines.size()

func on_interaction_forced_close() -> void:
	print("💬 Forzando cierre de diálogo (jugador se alejó)")
	
	if current_dialogue_ui and current_dialogue_ui.visible:
		current_dialogue_ui._force_close()
	
	current_dialogue_ui = null
	current_line = 0
