extends Node
class_name InventoryComponent

signal item_added(item: Item, quantity: int)
signal item_removed(item: Item, quantity: int)
signal item_used(item: Item)
signal inventory_changed
signal selected_fragment_changed(fragment: SoulFragment)
signal heal_cooldown_started(cooldown: float)
signal heal_cooldown_ended

@export var max_slots: int = 20
@export var heal_cooldown_duration: float = 10.0  # 🆕 10 segundos de cooldown

var items: Dictionary = {}
var player: Player

# Sistema de selección de fragmentos
var selected_fragment_index: int = 0
var available_fragments: Array[String] = []

# 🆕 SISTEMA DE COOLDOWN DE CURACIÓN
var heal_cooldown_timer: float = 0.0
var is_heal_on_cooldown: bool = false

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("InventoryComponent debe ser hijo de un Player")
		return
	
	# 🎯 CONECTAR A EVENTBUS
	EventBus.item_collected.connect(_on_item_collected)
	EventBus.currency_collected.connect(_on_currency_collected)
	
	print("🎒 Inventario inicializado - Slots: ", max_slots)

# 🎯 LISTENER DE EVENTBUS - ITEMS
func _on_item_collected(item: Item, collector: Node) -> void:
	# Solo procesar si el collector es este player
	if collector != player:
		return
	
	# Verificar si puede agregar
	if not _can_add_item(item):
		print("⚠️ Inventario lleno para ", item.name)
		return
	
	# Agregar item
	add_item(item, 1)

# 🎯 LISTENER DE EVENTBUS - MONEDA
func _on_currency_collected(amount: int, collector: Node) -> void:
	# Solo procesar si el collector es este player
	if collector != player:
		return
	
	var wallet = player.get_node_or_null("Wallet") as Wallet
	if wallet:
		wallet.add_asteriones(amount)

# 🆕 VERIFICAR SI PUEDE AGREGAR ITEM
func _can_add_item(item: Item) -> bool:
	if items.has(item.id):
		var current_quantity = items[item.id]["quantity"]
		return current_quantity < item.max_stack
	else:
		return get_item_count() < max_slots

func _process(delta: float) -> void:
	# 🆕 ACTUALIZAR COOLDOWN DE CURACIÓN
	if is_heal_on_cooldown:
		heal_cooldown_timer -= delta
		
		if heal_cooldown_timer <= 0:
			is_heal_on_cooldown = false
			heal_cooldown_ended.emit()
			print("✅ Cooldown de curación terminado")

func add_item(item: Item, quantity: int = 1) -> bool:
	if not item or quantity <= 0:
		return false
	
	# 🆕 DETECTAR Y MANEJAR MONEDA AUTOMÁTICAMENTE
	if item is Currency:
		return _add_currency_to_wallet(item as Currency, quantity)
	
	# Items normales (código existente)
	if items.has(item.id):
		var current_quantity = items[item.id]["quantity"]
		var new_quantity = current_quantity + quantity
		
		if new_quantity > item.max_stack:
			var overflow = new_quantity - item.max_stack
			items[item.id]["quantity"] = item.max_stack
			print("⚠️ Stack lleno para ", item.name, " | Overflow: ", overflow)
			item_added.emit(item, quantity - overflow)
			inventory_changed.emit()
			return overflow == 0
		else:
			items[item.id]["quantity"] = new_quantity
	else:
		if get_item_count() >= max_slots:
			print("❌ Inventario lleno!")
			return false
		
		items[item.id] = {
			"item": item,
			"quantity": min(quantity, item.max_stack)
		}
	
	print("✅ Añadido: ", quantity, "x ", item.name)
	item_added.emit(item, quantity)
	inventory_changed.emit()
	
	# Actualizar lista de fragmentos
	if item is SoulFragment:
		_update_available_fragments()
	
	return true

# 🆕 MANEJAR MONEDA - VA DIRECTAMENTE A WALLET (SIMPLIFICADO)
func _add_currency_to_wallet(currency: Currency, _quantity: int) -> bool:
	var wallet = player.get_node_or_null("Wallet") as Wallet
	if not wallet:
		push_warning("⚠️ Player no tiene Wallet component")
		return false
	
	# ⭐ SOLO ASTERIONES (currency.amount ya tiene la cantidad)
	wallet.add_asteriones(currency.amount)
	return true

func remove_item(item_id: String, quantity: int = 1) -> bool:
	if not items.has(item_id):
		return false
	
	var current_quantity = items[item_id]["quantity"]
	var item = items[item_id]["item"]
	
	if quantity >= current_quantity:
		items.erase(item_id)
		print("🗑️ Removido completamente: ", item.name)
	else:
		items[item_id]["quantity"] -= quantity
		print("➖ Reducido: ", item.name, " | Quedan: ", items[item_id]["quantity"])
	
	item_removed.emit(item, quantity)
	inventory_changed.emit()
	
	# Actualizar lista de fragmentos
	if item is SoulFragment:
		_update_available_fragments()
	
	return true

func use_item(item_id: String) -> bool:
	if not items.has(item_id):
		print("❌ Item no encontrado: ", item_id)
		return false
	
	var item = items[item_id]["item"]
	
	if not item.can_use:
		print("❌ Este item no se puede usar")
		return false
	
	var success = item.use(player)
	
	if success:
		print("✅ Usado: ", item.name)
		item_used.emit(item)
		remove_item(item_id, 1)
		return true
	
	return false

# Usar el fragmento actualmente seleccionado
func use_selected_fragment() -> bool:
	if available_fragments.is_empty():
		print("❌ No tienes fragmentos")
		return false
	
	# 🆕 VERIFICAR COOLDOWN
	if is_heal_on_cooldown:
		var time_left = ceil(heal_cooldown_timer)
		print("⏳ Curación en cooldown: ", time_left, " segundos")
		return false
	
	var fragment_id = available_fragments[selected_fragment_index]
	return use_fragment(fragment_id)

# Cambiar al siguiente fragmento
func cycle_fragment_selection(direction: int = 1) -> void:
	if available_fragments.is_empty():
		print("❌ No hay fragmentos para seleccionar")
		return
	
	selected_fragment_index = (selected_fragment_index + direction) % available_fragments.size()
	
	if selected_fragment_index < 0:
		selected_fragment_index = available_fragments.size() - 1
	
	var selected_id = available_fragments[selected_fragment_index]
	if items.has(selected_id):
		var fragment = items[selected_id]["item"] as SoulFragment
		var quantity = items[selected_id]["quantity"]
		print("🔄 Fragmento seleccionado: ", fragment.name, " x", quantity)
		selected_fragment_changed.emit(fragment)

# Obtener fragmento seleccionado actual
func get_selected_fragment() -> SoulFragment:
	if available_fragments.is_empty():
		return null
	
	var fragment_id = available_fragments[selected_fragment_index]
	if items.has(fragment_id):
		return items[fragment_id]["item"] as SoulFragment
	
	return null

func use_fragment(fragment_id: String) -> bool:
	if not has_item(fragment_id, 1):
		print("❌ No tienes este fragmento")
		return false
	
	# 🆕 VERIFICAR COOLDOWN ANTES DE USAR
	if is_heal_on_cooldown:
		var time_left = ceil(heal_cooldown_timer)
		print("⏳ Curación en cooldown: ", time_left, " segundos")
		return false
	
	var fragment = items[fragment_id]["item"]
	
	if not fragment is SoulFragment:
		print("❌ Este item no es un fragmento de alma")
		return false
	
	player.active_healing_fragment = fragment
	remove_item(fragment_id, 1)
	
	# 🆕 INICIAR COOLDOWN
	is_heal_on_cooldown = true
	heal_cooldown_timer = heal_cooldown_duration
	heal_cooldown_started.emit(heal_cooldown_duration)
	
	print("💎 Fragmento activado: ", fragment.name)
	print("⏳ Cooldown de curación: ", heal_cooldown_duration, " segundos")
	
	var state_machine = player.get_node_or_null("StateMachine")
	if state_machine:
		state_machine.change_to("Heal")
	
	return true

# Actualizar lista de fragmentos disponibles
func _update_available_fragments() -> void:
	available_fragments.clear()
	
	for item_id in items.keys():
		var item = items[item_id]["item"]
		if item is SoulFragment and items[item_id]["quantity"] > 0:
			available_fragments.append(item_id)
	
	# Ajustar índice si se salió de rango
	if selected_fragment_index >= available_fragments.size():
		selected_fragment_index = max(0, available_fragments.size() - 1)
	
	# Emitir señal si hay fragmento seleccionado
	if not available_fragments.is_empty():
		var fragment = get_selected_fragment()
		if fragment:
			selected_fragment_changed.emit(fragment)

func get_first_fragment() -> String:
	return available_fragments[0] if not available_fragments.is_empty() else ""

func get_item_quantity(item_id: String) -> int:
	if items.has(item_id):
		return items[item_id]["quantity"]
	return 0

func has_item(item_id: String, quantity: int = 1) -> bool:
	return get_item_quantity(item_id) >= quantity

func get_all_items() -> Array:
	var result = []
	for item_data in items.values():
		result.append(item_data)
	return result

func get_item_count() -> int:
	return items.size()

func clear() -> void:
	items.clear()
	available_fragments.clear()
	selected_fragment_index = 0
	is_heal_on_cooldown = false
	heal_cooldown_timer = 0.0
	inventory_changed.emit()
	print("🗑️ Inventario limpiado")

func print_inventory() -> void:
	print("=== INVENTARIO ===")
	if items.is_empty():
		print("  (vacío)")
	else:
		for item_data in items.values():
			var item = item_data["item"]
			var qty = item_data["quantity"]
			var selected = ""
			if item is SoulFragment and not available_fragments.is_empty() and item.id == available_fragments[selected_fragment_index]:
				selected = " ← SELECCIONADO"
			print("  ", item.name, " x", qty, selected)
	
	# 🆕 MOSTRAR COOLDOWN DE CURACIÓN
	if is_heal_on_cooldown:
		print("  ⏳ Cooldown de curación: ", ceil(heal_cooldown_timer), "s")
	
	print("==================")

# 🆕 CONSULTAS PÚBLICAS PARA COOLDOWN
func can_use_healing() -> bool:
	return not is_heal_on_cooldown

func get_heal_cooldown_remaining() -> float:
	return heal_cooldown_timer if is_heal_on_cooldown else 0.0

func serialize() -> Dictionary:
	var data = {
		"items": {},
		"selected_fragment_index": selected_fragment_index,
		"is_heal_on_cooldown": is_heal_on_cooldown,
		"heal_cooldown_timer": heal_cooldown_timer
	}
	
	# Serializar items
	for item_id in items.keys():
		var item_data = items[item_id]
		data["items"][item_id] = {
			"quantity": item_data["quantity"]
		}
	
	return data

func deserialize(data: Dictionary) -> void:
	if not data:
		return
	
	clear()
	
	# Restaurar items
	if data.has("items"):
		for item_id in data["items"].keys():
			var item = ItemDB.create_item(item_id)
			if item:
				var quantity = data["items"][item_id]["quantity"]
				add_item(item, quantity)
	
	# Restaurar estado
	if data.has("selected_fragment_index"):
		selected_fragment_index = data["selected_fragment_index"]
	
	if data.has("is_heal_on_cooldown"):
		is_heal_on_cooldown = data["is_heal_on_cooldown"]
	
	if data.has("heal_cooldown_timer"):
		heal_cooldown_timer = data["heal_cooldown_timer"]
	
	_update_available_fragments()
	
	print("📦 Inventario restaurado")
