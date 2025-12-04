extends Node
class_name HealingComponent

signal healing_started(fragment: SoulFragment)
signal healing_progressed(hits_done: int, hits_required: int)
signal healing_completed(healed_amount: int)
signal healing_cancelled

var player: Player
var is_healing: bool = false
var current_fragment: SoulFragment = null
var hits_done: int = 0
var hits_required: int = 0
var heal_amount: int = 0

# Fragmento equipado actualmente
var equipped_fragment: SoulFragment = null

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("HealingComponent debe ser hijo de un Player")
		return
	
	print("💊 HealingComponent inicializado")
	
	# Equipar primer fragmento disponible (temporal)
	_auto_equip_fragment()

# Auto-equipar el primer fragmento del inventario
func _auto_equip_fragment() -> void:
	var inventory = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inventory:
		return
	
	var items = inventory.get_all_items()
	for item_data in items:
		var item = item_data["item"]
		if item is SoulFragment:
			equipped_fragment = item
			print("💎 Fragmento equipado: ", item.name)
			return

# Intentar empezar curación
func try_start_healing() -> bool:
	if is_healing:
		print("⚠️ Ya estás curándote")
		return false
	
	if player.health >= player.max_health:
		print("❤️ Vida completa, no necesitas curarte")
		return false
	
	if not equipped_fragment:
		print("⚠️ No tienes fragmento equipado")
		_auto_equip_fragment()
		if not equipped_fragment:
			return false
	
	# Verificar que tiene el fragmento en inventario
	var inventory = player.get_node_or_null("InventoryComponent") as InventoryComponent
	if not inventory:
		return false
	
	if not inventory.has_item(equipped_fragment.id):
		print("⚠️ No tienes fragmentos de ese tipo")
		equipped_fragment = null
		_auto_equip_fragment()
		return false
	
	# Consumir el fragmento
	if not inventory.remove_item(equipped_fragment.id, 1):
		return false
	
	# Iniciar curación
	is_healing = true
	current_fragment = equipped_fragment
	hits_done = 0
	hits_required = current_fragment.hits_required
	heal_amount = current_fragment.heal_amount
	
	print("💊 Curación iniciada - Golpea ", hits_required, " veces para curarte ", heal_amount, " HP")
	healing_started.emit(current_fragment)
	
	# Cambiar a estado Heal
	var state_machine = player.get_node_or_null("StateMachine")
	if state_machine:
		state_machine.change_to("Heal")
	
	return true

# Registrar un golpe exitoso
func register_hit() -> void:
	if not is_healing:
		return
	
	hits_done += 1
	print("⚔️ Golpe ", hits_done, "/", hits_required)
	healing_progressed.emit(hits_done, hits_required)
	
	# Verificar si completó la curación
	if hits_done >= hits_required:
		_complete_healing()

# Completar curación
func _complete_healing() -> void:
	if not is_healing:
		return
	
	# Curar al jugador
	var health_component = player.get_node_or_null("HealthComponent") as HealthComponent
	if health_component:
		health_component.heal(heal_amount)
	else:
		# Fallback: curar directamente
		player.health = min(player.max_health, player.health + heal_amount)
		var health_bar = player.get_node_or_null("Vida/CanvasLayer/HealthBar") as ProgressBar
		if health_bar:
			health_bar.value = player.health
	
	print("✅ ¡Curación completada! +", heal_amount, " HP")
	healing_completed.emit(heal_amount)
	
	_end_healing()

# Cancelar curación (al recibir daño)
func cancel_healing() -> void:
	if not is_healing:
		return
	
	print("❌ Curación cancelada")
	healing_cancelled.emit()
	_end_healing()

# Finalizar proceso de curación
func _end_healing() -> void:
	is_healing = false
	current_fragment = null
	hits_done = 0
	hits_required = 0
	heal_amount = 0

# Método público para saber si está curándose
func is_currently_healing() -> bool:
	return is_healing
