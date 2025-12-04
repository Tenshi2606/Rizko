extends Vendor
class_name VendorWithDialogue

@export_group("Initial Dialogue")
@export_multiline var first_time_dialogue: Array[String] = [
	"¡Hola viajero!",
	"Soy el mercader de esta zona.",
	"Echa un vistazo a mis productos."
]

@export var dialogue_shown: bool = false
@export var show_dialogue_every_time: bool = false

var dialogue_ui: DialogueUI = null

func _on_ready() -> void:
	super._on_ready()
	
	if not dialogue_shown:
		interaction_prompt = "Presiona E para hablar"
	
	print("🏪💬 VendorWithDialogue configurado: ", shop_name)

func on_interact() -> void:
	if not dialogue_shown or show_dialogue_every_time:
		_show_initial_dialogue()
	else:
		_open_shop_directly()

func _show_initial_dialogue() -> void:
	print("💬 Mostrando diálogo inicial del vendedor")
	
	dialogue_ui = _find_dialogue_ui()
	
	if not dialogue_ui:
		push_error("❌ DialogueUI no encontrado")
		_open_shop_directly()
		return
	
	# Crear NPC temporal
	var temp_dialogue_npc = DialogueNPC.new()
	temp_dialogue_npc.npc_name = npc_name
	temp_dialogue_npc.dialogue_lines = first_time_dialogue
	temp_dialogue_npc.current_line = 0  # 🔧 ASEGURAR QUE EMPIECE EN 0
	
	print("💬 Líneas de diálogo: ", first_time_dialogue.size())
	print("💬 Primera línea: ", first_time_dialogue[0])
	
	# Mostrar diálogo
	dialogue_ui.show_dialogue(temp_dialogue_npc)
	
	dialogue_shown = true
	interaction_prompt = "Presiona E para comprar"
	
	# Esperar a que termine
	await dialogue_ui.dialogue_finished
	
	# Limpiar
	temp_dialogue_npc.queue_free()
	
	print("💬 Diálogo terminado, abriendo tienda...")
	_open_shop_directly()

func _open_shop_directly() -> void:
	super.on_interact()

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

func on_interaction_forced_close() -> void:
	if dialogue_ui and dialogue_ui.visible:
		dialogue_ui._force_close()
	
	super.on_interaction_forced_close()
